
if vim.g.vscode then
    -- VSCode extension
    -- Only include essential settings here
else
    require("core.options")
    require("config.lazy")
    require("core.keymaps")
end

