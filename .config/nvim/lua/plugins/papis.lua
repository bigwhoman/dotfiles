-- Runs `papis add --batch <args>` in the background, then reloads papis.nvim's db.
local function papis_add(args, label)
    vim.notify("papis: adding " .. label)
    local cmd = vim.list_extend({ "papis", "add", "--batch" }, args)
    vim.system(cmd, { text = true }, vim.schedule_wrap(function(res)
        if res.code ~= 0 then
            vim.notify("papis add failed:\n" .. (res.stderr or ""), vim.log.levels.ERROR)
            return
        end
        vim.cmd("Papis reload data")
        vim.notify("papis: added " .. label)
    end))
end

local nil_if_null = function(v)
    if v == vim.NIL then
        return nil
    end
    return v
end

-- Semantic Scholar key lives outside the dotfiles repo.
local s2_key_file = vim.fn.expand("~/.config/semanticscholar/key")

-- GET a Semantic Scholar URL, retrying 429s with exponential backoff (1s, 2s, 4s).
local function s2_get(url, key, on_done, attempt)
    attempt = attempt or 0
    local cmd = { "curl", "-sL", "-w", "\n%{http_code}", "-H", "x-api-key: " .. key, url }
    vim.system(cmd, { text = true }, vim.schedule_wrap(function(res)
        local body, status = (res.stdout or ""):match("^(.*)\n(%d+)$")
        if status == "429" and attempt < 3 then
            vim.defer_fn(function()
                s2_get(url, key, on_done, attempt + 1)
            end, 1000 * 2 ^ attempt)
            return
        end
        local ok, data = pcall(vim.json.decode, body or "")
        if res.code ~= 0 or status ~= "200" or not ok then
            vim.notify("papis: Semantic Scholar request failed (HTTP " .. (status or "?") .. ")", vim.log.levels.ERROR)
            return
        end
        on_done(data)
    end))
end

-- Adds a Semantic Scholar paper: DOI or arXiv importer when it has one, otherwise the search
-- metadata itself. An open-access PDF, if any, is downloaded and attached.
local function add_s2_paper(w)
    local args
    if w.doi then
        args = { "--from", "doi", w.doi }
    elseif w.arxiv then
        args = { "--from", "arxiv", w.arxiv }
    else
        local authors = vim.tbl_map(function(name)
            local given, family = name:match("^(.-)%s*(%S+)$")
            return given ~= "" and (family .. ", " .. given) or family
        end, w.authors)
        args = { "--set", "title", w.title, "--set", "author", table.concat(authors, " and ") }
        if w.year ~= "????" then
            vim.list_extend(args, { "--set", "year", w.year })
        end
        if w.venue ~= "" then
            vim.list_extend(args, { "--set", "venue", w.venue })
        end
        if w.url then
            vim.list_extend(args, { "--set", "url", w.url })
        end
    end
    if not w.pdf or w.arxiv and not w.doi then
        papis_add(args, w.title)
        return
    end
    local pdf = vim.fn.tempname() .. ".pdf"
    vim.system({ "curl", "-sfL", "-o", pdf, w.pdf }, {}, vim.schedule_wrap(function(res)
        if res.code == 0 then
            table.insert(args, pdf)
        else
            vim.notify("papis: couldn't download the PDF, adding metadata only", vim.log.levels.WARN)
        end
        papis_add(args, w.title)
    end))
end

-- Online title search via Semantic Scholar (covers DOI-less CS papers OpenAlex misses).
local function search_online(query)
    local ok_key, lines = pcall(vim.fn.readfile, s2_key_file)
    local key = ok_key and vim.trim(lines[1] or "") or ""
    if key == "" then
        vim.notify("papis: put your Semantic Scholar API key in " .. s2_key_file, vim.log.levels.ERROR)
        return
    end
    local url = "https://api.semanticscholar.org/graph/v1/paper/search?limit=30"
        .. "&fields=title,year,authors,venue,externalIds,openAccessPdf,url"
        .. "&query=" .. vim.uri_encode(query)
    vim.notify("papis: searching Semantic Scholar for " .. query)
    s2_get(url, key, function(data)
        local works = {}
        for _, p in ipairs(data.data or {}) do
            local ids = nil_if_null(p.externalIds) or {}
            local oa = nil_if_null(p.openAccessPdf)
            table.insert(works, {
                -- S2 titles occasionally contain newlines, which break telescope rows.
                title = (nil_if_null(p.title) or "?"):gsub("%s+", " "),
                year = p.year ~= vim.NIL and tostring(p.year) or "????",
                authors = vim.tbl_map(function(a)
                    return a.name
                end, p.authors or {}),
                venue = nil_if_null(p.venue) or "",
                doi = nil_if_null(ids.DOI),
                arxiv = nil_if_null(ids.ArXiv),
                pdf = oa and nil_if_null(oa.url) ~= "" and nil_if_null(oa.url) or nil,
                url = nil_if_null(p.url),
            })
        end
        if #works == 0 then
            vim.notify("papis: no results for " .. query, vim.log.levels.WARN)
            return
        end

        local pickers = require("telescope.pickers")
        local finders = require("telescope.finders")
        local previewers = require("telescope.previewers")
        local conf = require("telescope.config").values
        local actions = require("telescope.actions")
        local action_state = require("telescope.actions.state")

        pickers.new({}, {
            prompt_title = "Semantic Scholar: " .. query .. "  (<CR> add to papis)",
            finder = finders.new_table({
                results = works,
                entry_maker = function(w)
                    local first = w.authors[1] and w.authors[1]:match("(%S+)$") or "?"
                    return {
                        value = w,
                        display = string.format("%s  %s  (%s)%s", w.year, w.title, first, w.pdf and "  [pdf]" or ""),
                        ordinal = w.title .. " " .. table.concat(w.authors, " ") .. " " .. w.year,
                    }
                end,
            }),
            sorter = conf.generic_sorter({}),
            previewer = previewers.new_buffer_previewer({
                define_preview = function(self, entry)
                    local w = entry.value
                    vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, {
                        "# " .. w.title,
                        "",
                        "- Authors: " .. table.concat(w.authors, ", "),
                        "- Year:    " .. w.year,
                        "- Venue:   " .. w.venue,
                        "- DOI:     " .. (w.doi or "none"),
                        "- arXiv:   " .. (w.arxiv or "none"),
                        "- PDF:     " .. (w.pdf or "none"),
                    })
                    -- Highlight without setting filetype: that would fire every markdown FileType
                    -- autocmd (papis.nvim, render-markdown, ...) on each preview.
                    pcall(vim.treesitter.start, self.state.bufnr, "markdown")
                    vim.wo[self.state.winid].wrap = true
                end,
            }),
            attach_mappings = function(prompt_bufnr)
                actions.select_default:replace(function()
                    local w = action_state.get_selected_entry().value
                    actions.close(prompt_bufnr)
                    add_s2_paper(w)
                end)
                return true
            end,
        }):find()
    end)
end

return {
    "jghauser/papis.nvim",
    -- Only load where citations get written; `:Papis` also loads it on demand.
    ft = { "markdown", "tex", "yaml", "typst" },
    cmd = "Papis",
    dependencies = {
        "kkharji/sqlite.lua",
        "MunifTanjim/nui.nvim",
        "nvim-telescope/telescope.nvim",
        "hrsh7th/nvim-cmp",
    },
    -- yq-go and the libsqlite3 path (vim.g.sqlite_clib_path) come from home-manager.
    config = function()
        require("papis").setup({
            init_filetypes = { "markdown", "tex", "yaml", "typst" },
            -- <leader>pp search, <leader>pf open file, <leader>pe edit, <leader>pn note, <leader>pi info
            enable_keymaps = true,
            ["search"] = { provider = "telescope" },
            ["completion"] = { provider = "cmp" },
        })

        -- papis.nvim has no "add", so shell out to the papis CLI.
        vim.keymap.set("n", "<leader>pa", function()
            vim.ui.input({ prompt = "papis add (PDF path, DOI or URL): ", completion = "file" }, function(input)
                if not input or input == "" then
                    return
                end
                local path = vim.fn.expand(input)
                if vim.uv.fs_stat(path) then
                    papis_add({ path }, input)
                elseif input:match("^https?://") then
                    papis_add({ "--from", "url", input }, input)
                else
                    papis_add({ "--from", "doi", input }, input)
                end
            end)
        end, { desc = "Papis add (PDF/DOI/URL)" })

        vim.keymap.set("n", "<leader>ps", function()
            vim.ui.input({ prompt = "Search papers online (title): " }, function(input)
                if input and input ~= "" then
                    search_online(input)
                end
            end)
        end, { desc = "Papis search Semantic Scholar and add" })

        -- In a library info.yaml, <leader>po opens the paper online (url field, else the DOI).
        vim.api.nvim_create_autocmd("BufEnter", {
            pattern = vim.fn.expand("~/refs") .. "/*/info.yaml",
            callback = function(ev)
                vim.keymap.set("n", "<leader>po", function()
                    local url, doi
                    for _, line in ipairs(vim.api.nvim_buf_get_lines(ev.buf, 0, -1, false)) do
                        url = url or line:match("^url:%s*['\"]?([^'\"]+)")
                        doi = doi or line:match("^doi:%s*['\"]?([^'\"]+)")
                    end
                    local target = url or (doi and "https://doi.org/" .. doi)
                    if target then
                        vim.ui.open(target)
                    else
                        vim.notify("papis: no url or doi in this entry", vim.log.levels.WARN)
                    end
                end, { buffer = ev.buf, desc = "Papis open paper online" })
            end,
        })
    end,
}
