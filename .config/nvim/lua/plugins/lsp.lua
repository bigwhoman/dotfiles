return {
  -- LSP: nvim-lspconfig only supplies default server configs (its lsp/*.lua);
  -- servers are configured and started with Neovim's built-in vim.lsp API.
  -- (require("lspconfig").X.setup() is deprecated since Neovim 0.11.)
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = { "hrsh7th/cmp-nvim-lsp" },
    config = function()
      -- Tell every server that nvim-cmp can handle snippets and extra completion info.
      vim.lsp.config("*", {
        capabilities = require("cmp_nvim_lsp").default_capabilities(),
      })

      -- System clangd (/usr/bin/clangd)
      vim.lsp.config("clangd", {
        cmd = { "clangd", "--background-index", "--clang-tidy" },
      })
      vim.lsp.enable("clangd")
    end,
  },

  -- DAP Configuration (use system-provided debuggers)
  {
    "mfussenegger/nvim-dap",
    dependencies = {
      "rcarriga/nvim-dap-ui",
      "nvim-neotest/nvim-nio", -- required by nvim-dap-ui
    },
    config = function()
      local dap = require("dap")

      -- lldb-dap ships with the system lldb package; codelldb isn't installed.
      dap.adapters.lldb = {
        type = "executable",
        command = "lldb-dap",
        name = "lldb",
      }

      -- Rest of DAP config...
    end,
  },
}
