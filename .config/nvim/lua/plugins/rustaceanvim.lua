return {
  'mrcjkb/rustaceanvim',
  version = '^6', -- Recommended
  lazy = false, -- This plugin is already lazy
  config = function()
    -- Diagnostic configuration
    vim.diagnostic.config({
      virtual_text = true,
      float = {
        source = 'always',
        border = 'rounded',
      },
    })
  end,
}
