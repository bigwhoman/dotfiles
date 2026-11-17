-- Runs `papis add --batch <args>` in the background, then reloads papis.nvim's db.
-- on_fail, if given, runs instead of the error message when nothing was added.
local function papis_add(args, label, on_fail)
    vim.notify("papis: adding " .. label)
    local cmd = vim.list_extend({ "papis", "add", "--batch" }, args)
    vim.system(cmd, { text = true }, vim.schedule_wrap(function(res)
        -- papis exits 0 even when its importers found nothing.
        if res.code ~= 0 or (res.stderr or ""):find("No document is created", 1, true) then
            if on_fail then
                on_fail()
            else
                vim.notify("papis add failed:\n" .. (res.stderr or ""), vim.log.levels.ERROR)
            end
            return
        end
        vim.cmd("Papis reload data")
        vim.notify("papis: added " .. label)
    end))
end

local function html_unescape(s)
    s = s:gsub("&#[xX](%x+);", function(h)
        return vim.fn.nr2char(tonumber(h, 16))
    end)
    s = s:gsub("&#(%d+);", function(d)
        return vim.fn.nr2char(tonumber(d))
    end)
    local named = { amp = "&", lt = "<", gt = ">", quot = '"', apos = "'", nbsp = " " }
    s = s:gsub("&(%a+);", function(n)
        return named[n]
    end)
    return vim.trim((s:gsub("%s+", " ")))
end

-- Reads a web page's metadata from its HTML: citation_* / Dublin Core / OpenGraph meta tags,
-- falling back to <title> and the domain, so there is always a title and an author.
local function webpage_metadata(url, html)
    local meta, all = {}, {}
    for tag in html:gmatch("<[mM][eE][tT][aA]%s[^>]->") do
        local key = tag:match("[nN][aA][mM][eE]%s*=%s*[\"']([^\"']+)")
            or tag:match("[pP][rR][oO][pP][eE][rR][tT][yY]%s*=%s*[\"']([^\"']+)")
            or tag:match("[iI][tT][eE][mM][pP][rR][oO][pP]%s*=%s*[\"']([^\"']+)")
        local content = tag:match('[cC][oO][nN][tT][eE][nN][tT]%s*=%s*"([^"]*)"')
            or tag:match("[cC][oO][nN][tT][eE][nN][tT]%s*=%s*'([^']*)'")
        if key and content and content ~= "" then
            key = key:lower()
            content = html_unescape(content)
            meta[key] = meta[key] or content
            all[key] = all[key] or {}
            table.insert(all[key], content)
        end
    end
    local function first(...)
        for _, k in ipairs({ ... }) do
            if meta[k] then
                return meta[k]
            end
        end
    end

    local host = url:match("^https?://([^/:]+)"):gsub("^www%.", "")
    local site = first("og:site_name", "application-name")
        or host:gsub("%.[^.]+$", ""):gsub("^%l", string.upper)
    local title = first("citation_title", "dc.title", "og:title", "twitter:title")
    if not title then
        title = html_unescape(html:match("<[tT][iI][tT][lL][eE][^>]*>(.-)</[tT][iI][tT][lL][eE]>") or "")
        -- "Page | Site" / "Page - Site": the tail is the site's own spelling of its name.
        local page, tail = title:match("^(.-)%s+[|–—-]%s+([^|–—-]+)$")
        if page and page ~= "" then
            title = page
            site = first("og:site_name", "application-name") or vim.trim(tail)
        end
    end
    if title == "" then
        title = url
    end
    local date = first("citation_publication_date", "citation_date", "dc.date", "article:published_time",
        "datepublished", "published_at", "date", "pubdate")

    -- Person authors become "Family, Given"; with none, the site is the (organisation) author,
    -- braced so bibtex keeps it as one name, like the hand-added Broadcom/IBM entries.
    local people = {}
    for _, k in ipairs({ "citation_author", "dc.creator", "author", "authors", "article:author" }) do
        if all[k] then
            -- Skip profile URLs and bylines like "Confluent Staff".
            people = vim.tbl_filter(function(name)
                return not name:match("^https?://") and not name:lower():find(site:lower(), 1, true)
            end, all[k])
            if #people > 0 then
                break
            end
        end
    end
    local author
    if #people > 0 then
        author = table.concat(vim.tbl_map(function(name)
            if name:find(",") then
                return name
            end
            local given, family = name:match("^(.-)%s*(%S+)$")
            return given ~= "" and (family .. ", " .. given) or family
        end, people), " and ")
    else
        author = "{" .. site .. "}"
    end

    return {
        title = title,
        author = author,
        family = (author:match("^{(.-)}$") or author:match("^([^,]+)")),
        year = date and date:match("(%d%d%d%d)"),
        site = site,
    }
end

-- Adds a web page that papis' own importers couldn't handle (no author, no scholarly metadata).
local function add_webpage(url)
    vim.notify("papis: reading " .. url)
    local cmd = { "curl", "-sL", "--max-time", "20", "-A", "Mozilla/5.0 (X11; Linux x86_64)", url }
    vim.system(cmd, { text = true }, vim.schedule_wrap(function(res)
        if res.code ~= 0 or not res.stdout or res.stdout == "" then
            vim.notify("papis: couldn't fetch " .. url, vim.log.levels.ERROR)
            return
        end
        local m = webpage_metadata(url, res.stdout)
        local args = {
            "--set", "title", m.title,
            "--set", "author", m.author,
            "--set", "type", "online",
            "--set", "url", url,
            "--set", "urldate", os.date("%Y-%m-%d"),
        }
        if m.site ~= m.family then
            vim.list_extend(args, { "--set", "howpublished", m.site })
        end
        if m.year then
            vim.list_extend(args, { "--set", "year", m.year })
        else
            -- Without a year the key would be just the author, shared by every page of that site;
            -- add the first real title word instead (e.g. BroadcomStreams).
            local word = ""
            for w in m.title:gmatch("%a+") do
                if #w >= 4 and not m.family:lower():find(w:lower(), 1, true) then
                    word = w:sub(1, 1):upper() .. w:sub(2):lower()
                    break
                end
            end
            vim.list_extend(args, { "--set", "ref", m.family:gsub("%W", "") .. word })
        end
        papis_add(args, m.title)
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
    if w.abstract then
        vim.list_extend(args, { "--set", "abstract", w.abstract })
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

local function query_words(prompt)
    return vim.split(prompt:lower(), "%s+", { trimempty = true })
end

-- Telescope sorter for the papis pickers, replacing fuzzy matching with whole-word matching.
-- Each typed word must appear unbroken (case ignored, so "hel" doesn't match h…e…l); separate
-- words may appear anywhere, in any order. Earlier matches rank higher.
local function words_sorter()
    return require("telescope.sorters").Sorter:new({
        discard = true,
        scoring_function = function(_, prompt, line)
            local words = query_words(prompt)
            if #words == 0 then
                return 1
            end
            line = line:lower()
            local score = 0
            for _, w in ipairs(words) do
                local pos = line:find(w, 1, true)
                if not pos then
                    return -1
                end
                score = score + pos / (#line + 1)
            end
            return score / #words
        end,
        highlighter = function(_, prompt, display)
            local positions = {}
            display = display:lower()
            for _, w in ipairs(query_words(prompt)) do
                local s = display:find(w, 1, true)
                while s do
                    for i = s, s + #w - 1 do
                        table.insert(positions, i)
                    end
                    s = display:find(w, s + #w, true)
                end
            end
            return positions
        end,
    })
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
        .. "&fields=title,year,authors,venue,externalIds,openAccessPdf,url,abstract,tldr"
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
                abstract = nil_if_null(p.abstract),
                tldr = nil_if_null(p.tldr) and nil_if_null(p.tldr.text),
            })
        end
        if #works == 0 then
            vim.notify("papis: no results for " .. query, vim.log.levels.WARN)
            return
        end

        local pickers = require("telescope.pickers")
        local finders = require("telescope.finders")
        local previewers = require("telescope.previewers")
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
            sorter = words_sorter(),
            previewer = previewers.new_buffer_previewer({
                define_preview = function(self, entry)
                    local w = entry.value
                    local lines = {
                        "# " .. w.title,
                        "",
                        "- Authors: " .. table.concat(w.authors, ", "),
                        "- Year:    " .. w.year,
                        "- Venue:   " .. w.venue,
                        "- DOI:     " .. (w.doi or "none"),
                        "- arXiv:   " .. (w.arxiv or "none"),
                        "- PDF:     " .. (w.pdf or "none"),
                    }
                    if w.tldr then
                        vim.list_extend(lines, { "", "## TL;DR", "", w.tldr })
                    end
                    -- Abstracts can hold newlines, which nvim_buf_set_lines rejects within one item.
                    vim.list_extend(lines, { "", "## Abstract", "" })
                    vim.list_extend(lines, vim.split(w.abstract or "(none on Semantic Scholar)", "\n"))
                    vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
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
            ["search"] = {
                provider = "telescope",
                -- o / <c-o> in the <leader>pp picker: open the paper's PDF in Sioyek on the side.
                picker_keymaps = {
                    ["o"] = { "open_file", mode = "n", desc = "(Papis) Open PDF on the side" },
                    ["<c-o>"] = { "open_file", mode = "i", desc = "(Papis) Open PDF on the side" },
                },
            },
            ["completion"] = { provider = "cmp" },
        })

        -- <leader>pp: whole-word matching instead of fuzzy (see words_sorter).
        local papis_telescope = require("papis.search.telescope")
        local papis_ask = papis_telescope.exports.papis_ask
        papis_telescope.exports.papis_ask = function(opts)
            papis_ask(vim.tbl_extend("keep", opts or {}, { sorter = words_sorter() }))
        end

        -- Route attached PDFs through core.pdf so they open in Sioyek to the right of nvim.
        local papis_utils = require("papis.utils")
        local open_external = papis_utils.do_open_file_external
        papis_utils.do_open_file_external = function(self, path)
            if path:match("%.pdf$") then
                require("core.pdf").open(path)
            else
                open_external(self, path)
            end
        end

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
                    -- papis' downloaders handle arXiv/ACM/DOI/etc. pages; anything else is
                    -- read as a plain web page.
                    papis_add({ input }, input, function()
                        add_webpage(input)
                    end)
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
