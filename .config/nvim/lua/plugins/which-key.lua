return {
    "folke/which-key.nvim",
    event = "VeryLazy",
    init = function()
        vim.o.timeout = true
        vim.o.timeoutlen = 500
    end,
    opts = {
        -- Name the <leader> prefixes so the popup shows "papis" instead of "+N keymaps".
        spec = {
            { "<leader>p", group = "papis" },
        },
    },
    keys = {
        {
            "<leader>?",
            function()
                require("which-key").show({ global = false })
            end,
            desc = "Buffer-local keymaps",
        },
    },
}
