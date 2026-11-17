-- Open PDFs in Sioyek next to nvim instead of loading them as binary buffers.
-- On Hyprland (dwindle) the new window is preselected to the right of the
-- focused one, so it lands as a side-by-side split with the terminal.

local M = {}

function M.open(path)
    path = vim.fn.fnamemodify(path, ":p")
    if vim.fn.filereadable(path) == 0 then
        vim.notify("pdf: not found: " .. path, vim.log.levels.WARN)
        return
    end
    if vim.env.HYPRLAND_INSTANCE_SIGNATURE then
        vim.system({ "hyprctl", "dispatch", "layoutmsg", "preselect r" }):wait()
    end
    -- --new-window: like zathura --fork, each PDF gets its own window instead of
    -- replacing the file in an already-open sioyek window on another workspace.
    vim.system({ "sioyek", "--new-window", path }, { detach = true })
end

-- Resolve the PDF the cursor is on: relative to the current file, then the cwd,
-- then anywhere below the cwd (Obsidian-style bare attachment names).
local function pdf_under_cursor()
    local name = vim.fn.expand("<cfile>")
    if not name:match("%.pdf$") then
        return nil
    end
    for _, dir in ipairs({ vim.fn.expand("%:p:h"), vim.fn.getcwd() }) do
        local p = vim.fs.joinpath(dir, name)
        if vim.fn.filereadable(p) == 1 then
            return p
        end
    end
    return vim.fs.find(vim.fs.basename(name), { path = vim.fn.getcwd(), limit = 1 })[1]
end

function M.find()
    require("telescope.builtin").find_files({
        prompt_title = "PDFs",
        find_command = { "rg", "--files", "--no-ignore", "-g", "*.pdf" },
    })
end

-- <leader>zz: PDF under the cursor, else the PDF next to this file (foo.tex -> foo.pdf), else pick one.
function M.open_here()
    local p = pdf_under_cursor()
    if not p then
        local sibling = vim.fn.expand("%:p:r") .. ".pdf"
        p = vim.fn.filereadable(sibling) == 1 and sibling or nil
    end
    if p then
        M.open(p)
    else
        M.find()
    end
end

-- :e foo.pdf, telescope, nvim-tree, etc. all route PDFs to Sioyek.
vim.api.nvim_create_autocmd("BufReadCmd", {
    pattern = "*.pdf",
    callback = function(ev)
        M.open(ev.match)
        vim.schedule(function()
            if not vim.api.nvim_buf_is_valid(ev.buf) then
                return
            end
            local alt = vim.fn.bufnr("#")
            for _, win in ipairs(vim.fn.win_findbuf(ev.buf)) do
                vim.api.nvim_win_call(win, function()
                    if alt > 0 and alt ~= ev.buf and vim.api.nvim_buf_is_valid(alt) then
                        vim.cmd.buffer(alt)
                    else
                        vim.cmd.enew()
                    end
                end)
            end
            vim.api.nvim_buf_delete(ev.buf, { force = true })
        end)
    end,
})

vim.keymap.set("n", "<leader>zz", M.open_here, { desc = "Open PDF in Sioyek (cursor / sibling / pick)" })
vim.keymap.set("n", "<leader>zf", M.find, { desc = "Find PDF and open in Sioyek" })

return M
