local vault = vim.fn.expand("~") .. "/Documents/Obsidian Vault"

return {
    "obsidian-nvim/obsidian.nvim",
    version = "*",
    -- Only load inside the vault, not for every markdown file.
    event = {
        "BufReadPre " .. vault .. "/*.md",
        "BufNewFile " .. vault .. "/*.md",
    },
    dependencies = { "nvim-lua/plenary.nvim" },
    opts = {
        workspaces = {
            { name = "vault", path = vault },
        },
        -- render-markdown.nvim does the in-buffer rendering; obsidian's own UI
        -- would draw over the same text.
        ui = { enable = false },
        -- Use the new `:Obsidian <subcommand>` form; the old :ObsidianFoo commands are deprecated.
        legacy_commands = false,
    },
}
