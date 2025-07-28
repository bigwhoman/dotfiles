return {
  "rcarriga/nvim-dap-ui",
  dependencies = {
    'mfussenegger/nvim-dap',
    'nvim-neotest/nvim-nio', -- Assuming this is also a dependency you want to include
  },      
  config = function()
    local dap = require("dap")
    local dapui = require("dapui")

    dapui.setup()

    -- Auto-open/close UI
    dap.listeners.after.event_initialized["dapui_config"] = function()
      dapui.open()
    end
    dap.listeners.before.event_terminated["dapui_config"] = function()
      dapui.close()
    end
    dap.listeners.before.event_exited["dapui_config"] = function()
      dapui.close()
    end

    -- Virtual text setup
    require("nvim-dap-virtual-text").setup()

    -- UI keymaps
    vim.keymap.set('n', '<leader>du', dapui.toggle)
  end
}
-- return {
--   'rcarriga/nvim-dap-ui',
--   
--   opts = {},
--
--   config = function()
--     local dap, dapui = require 'dap', require 'dapui'
--     dap.listeners.before.attach.dapui_config = function()
--       dapui.open()
--     end
--     dap.listeners.before.launch.dapui_config = function()
--       dapui.open()
--     end
--     dap.listeners.before.event_terminated.dapui_config = function()
--       dapui.close()
--     end
--     dap.listeners.before.event_exited.dapui_config = function()
--       dapui.close()
--     end
--   end,
-- }
-- dapui.setup({
--         icons = { expanded = "▾", collapsed = "▸" },
--         mappings = {
--           expand = { "<CR>", "<2-LeftMouse>" },
--           open = "o",
--           remove = "d",
--           edit = "e",
--           repl = "r",
--           toggle = "t",
--         },
--         layouts = {
--           {
--             elements = {
--               { id = "scopes", size = 0.25 },
--               { id = "breakpoints", size = 0.25 },
--               { id = "stacks", size = 0.25 },
--               { id = "watches", size = 0.25 },
--             },
--             size = 40,
--             position = "left",
--           },
--           {
--             elements = {
--               { id = "repl", size = 0.5 },
--               { id = "console", size = 0.5 },
--             },
--             size = 10,
--             position = "bottom",
--           },
--         },
--         controls = {
--           enabled = true,
--           element = "repl",
--           icons = {
--             pause = "⏸",
--             play = "▶",
--             step_into = "⏎",
--             step_over = "⏭",
--             step_out = "⏮",
--             step_back = "b",
--             run_last = "▶▶",
--             terminate = "⏹",
--           },
--         },
--         floating = {
--           max_height = nil,
--           max_width = nil,
--           border = "single",
--           mappings = {
--             close = { "q", "<Esc>" },
--           },
--         },
--         windows = { indent = 1 },
--         render = {
--           max_type_length = nil,
--           max_value_lines = 100,
--         }
--       })
--
--       -- Setup virtual text
--       -- require("nvim-dap-virtual-text").setup({
--       --   enabled = true,
--       --   enabled_commands = true,
--       --   highlight_changed_variables = true,
--       --   highlight_new_as_changed = false,
--       --   show_stop_reason = true,
--       --   commented = false,
--       --   only_first_definition = true,
--       --   all_references = false,
--       --   filter_references_pattern = '<module',
--       --   virt_text_pos = 'eol',
--       --   all_frames = false,
--       --   virt_lines = false,
--       --   virt_text_win_col = nil
--       -- })
--
--       dap.listeners.before.attach.dapui_config = function()
--         dapui.open()
--       end
--       dap.listeners.before.launch.dapui_config = function()
--         dapui.open()
--       end
--       dap.listeners.before.event_terminated.dapui_config = function()
--         dapui.close()
--       end
--       dap.listeners.before.event_exited.dapui_config = function()
--         dapui.close()
--       end 
