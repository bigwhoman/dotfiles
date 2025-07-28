-- In your lsp.lua file, replace Mason with direct configuration
return {
  -- LSP Configuration (no Mason)
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      local lspconfig = require("lspconfig")

      -- Configure clangd from Nix
      lspconfig.clangd.setup({
        cmd = { "clangd", "--background-index", "--clang-tidy" },  -- Use system clangd
        -- rest of your config...
      })

      -- Key bindings remain the same
      -- ...
    end,
  },

  -- For null-ls, use system-provided formatters/linters
  
}
