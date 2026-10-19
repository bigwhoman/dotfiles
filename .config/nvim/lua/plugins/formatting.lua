return {
    "stevearc/conform.nvim",
    event = {"BufReadPre", "BufNewFile"},
    config = function()
        local conform = require("conform")
        conform.setup({
            formatters_by_ft = {
                c = {"clang-format"},
                lua = {"stylua"},
                python = {"isort", "black"},
                json = {"prettier"},
                yaml = {"prettier"},
            },
            format_on_save = {
                lsp_format = "fallback",
                async = false,
                timeout_ms = 1000,
            },
            -- stylua/black/isort/prettier aren't installed; don't warn on every save.
            -- Files of those types just save unformatted until the tool is installed.
            notify_no_formatters = false,
        })
        
        vim.keymap.set({"n", "v"}, "<leader>mp", function()   
            conform.format({
                lsp_format = "fallback",
                async = false,
                timeout_ms = 1000,
            })
        end, {desc = "Format file or range(in visual mode)"}
        )
    end,
}
