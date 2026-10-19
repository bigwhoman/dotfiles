-- nvim-treesitter's `master` branch is frozen and does not support Neovim 0.12:
-- its query directives crash with "attempt to call method 'range'" (e.g. on
-- markdown code fences). This uses the `main` rewrite instead. Highlighting is
-- now done by Neovim itself; the plugin only installs parsers and queries.
-- Installing parsers needs `tree-sitter-cli` (pacman -S tree-sitter-cli) and gcc.

-- The old ensure_installed list, plus what auto_install had picked up over time.
local parsers = {
    "c", "lua", "vim", "vimdoc", "query", "bash", "python", "markdown", "markdown_inline",
    "csv", "diff", "dockerfile", "fish", "gitignore", "hyprlang", "ini", "javascript",
    "json", "make", "rust", "ssh_config", "toml", "tsv", "xml", "yaml",
}

return {
    {
        "nvim-treesitter/nvim-treesitter",
        branch = "main",
        lazy = false, -- the main branch does not support lazy-loading
        build = ":TSUpdate",
        config = function()
            require("nvim-treesitter").install(parsers)

            -- Replaces `highlight = { enable = true }`: start Neovim's treesitter
            -- highlighting for any filetype that has a parser installed.
            vim.api.nvim_create_autocmd("FileType", {
                group = vim.api.nvim_create_augroup("treesitter_start", { clear = true }),
                callback = function(args)
                    pcall(vim.treesitter.start, args.buf)
                end,
            })

            -- Replaces `incremental_selection`: Neovim 0.12 has it built in as
            -- `an` (expand to parent node) and `in` (shrink back) in visual mode.
            -- These keep the old keys; there is no equivalent of scope_incremental (<C-s>).
            vim.keymap.set("n", "<C-space>", "van", { remap = true, desc = "Start treesitter selection" })
            vim.keymap.set("x", "<C-space>", "an", { remap = true, desc = "Expand selection to parent node" })
            vim.keymap.set("x", "<bs>", "in", { remap = true, desc = "Shrink selection to child node" })
        end,
    },
    {
        "nvim-treesitter/nvim-treesitter-textobjects",
        branch = "main",
        config = function()
            require("nvim-treesitter-textobjects").setup({
                select = {
                    -- Automatically jump forward to textobj, similar to targets.vim
                    lookahead = true,
                    selection_modes = {
                        ["@parameter.outer"] = "v", -- charwise
                        ["@function.outer"] = "V", -- linewise
                        ["@class.outer"] = "<c-v>", -- blockwise
                    },
                    -- Extend textobjects to include surrounding whitespace, like `ap`.
                    include_surrounding_whitespace = true,
                },
            })

            local select = require("nvim-treesitter-textobjects.select")
            local function map(lhs, query, group, desc)
                vim.keymap.set({ "x", "o" }, lhs, function()
                    select.select_textobject(query, group)
                end, { desc = desc })
            end
            map("af", "@function.outer", "textobjects", "Select outer function")
            map("if", "@function.inner", "textobjects", "Select inner function")
            map("ac", "@class.outer", "textobjects", "Select outer class")
            map("ic", "@class.inner", "textobjects", "Select inner part of a class region")
            map("as", "@local.scope", "locals", "Select language scope")
        end,
    },
}
