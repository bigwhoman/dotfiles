-- vim.g.clipboard = {
-- 	name = "wl-clipboard",
-- 	copy = {
-- 		["+"] = "wl-copy",
-- 		["*"] = "wl-copy",
-- 	},
-- 	paste = {
-- 		["+"] = "wl-paste",
-- 		["*"] = "wl-paste",
-- 	},
-- 	cache_enabled = 1,
-- }
vim.opt.clipboard:append("unnamedplus")
vim.opt.tabstop = 2
vim.opt.shiftwidth = 2
vim.opt.softtabstop = 2
vim.opt.expandtab = true
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.splitbelow = true
vim.opt.splitright = true
vim.opt.wrap = false
vim.opt.scrolloff = 999
vim.opt.virtualedit = "block"
vim.opt.inccommand = "split"
vim.opt.ignorecase = true
vim.opt.termguicolors = true
vim.opt.signcolumn = "yes"

-- auto-session: 'localoptions' makes filetype/highlighting come back when a session is restored.
vim.o.sessionoptions = "blank,buffers,curdir,folds,help,tabpages,winsize,winpos,terminal,localoptions"

-- No plugin here uses the remote-plugin hosts; turning them off clears the
-- :checkhealth provider warnings and skips probing for them at startup.
vim.g.loaded_node_provider = 0
vim.g.loaded_perl_provider = 0
vim.g.loaded_python3_provider = 0
vim.g.loaded_ruby_provider = 0

-- Code stays unwrapped (wrap = false above); notes and prose wrap at word
-- boundaries, with wrapped rows indented to match their line.
vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("wrap_prose", { clear = true }),
    pattern = { "markdown", "text", "gitcommit" },
    callback = function()
        vim.opt_local.wrap = true
        vim.opt_local.linebreak = true
        vim.opt_local.breakindent = true
    end,
})
