vim.g.mapleader = " "

local keymap = vim.keymap

keymap.set("i", "jk", "<ESC>", { desc = "Exit insert mode with jk" })

-- Move by screen row on wrapped lines, but keep counts (5j, 12k) moving by real
-- lines so they still match the relative line numbers.
keymap.set({ "n", "x" }, "j", "v:count == 0 ? 'gj' : 'j'", { expr = true, desc = "Down (screen row)" })
keymap.set({ "n", "x" }, "k", "v:count == 0 ? 'gk' : 'k'", { expr = true, desc = "Up (screen row)" })

-- window management
keymap.set("n", "<leader>sv", "<C-w>v", { desc = "Vertical Split" })
keymap.set("n", "<leader>sh", "<C-w>s", { desc = "Horizontal Split" })
keymap.set("n", "<leader>se", "<C-w>=", { desc = "Equal Split" })
keymap.set("n", "<leader>sv", "<C-w>v", { desc = "Vertical Split" })
keymap.set("n", "<leader>sx", "<C-w>c", { desc = "Close Split" })

keymap.set("n", "<leader>tt", "<cmd>tabnew<CR>", { desc = "New tab" })
keymap.set("n", "<leader>tx", "<cmd>tabclose<CR>", { desc = "Close Tab" })
keymap.set("n", "<leader>tn", "<cmd>tabn<CR>", { desc = "Next Tab" })
keymap.set("n", "<leader>tp", "<cmd>tabp<CR>", { desc = "Prev Tab" })
