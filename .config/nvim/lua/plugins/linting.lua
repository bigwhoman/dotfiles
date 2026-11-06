return {
	"mfussenegger/nvim-lint",
	event = { "BufReadPre", "BufNewFile" },
	config = function()
		local lint = require("lint")
		lint.linters_by_ft = {
			c = { "cpplint" },
		}
		local lint_augroup = vim.api.nvim_create_augroup("lint", { clear = true })
		vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "InsertLeave" }, {
			group = lint_augroup,
			callback = function()
				-- Only run linters that are installed. cpplint isn't, and calling it
				-- raised "ENOENT" on every C buffer; clangd's --clang-tidy covers C.
				local names = vim.tbl_filter(function(name)
					local linter = lint.linters[name]
					if type(linter) == "function" then
						linter = linter()
					end
					local cmd = linter and linter.cmd
					if type(cmd) == "function" then
						cmd = cmd()
					end
					return type(cmd) == "string" and vim.fn.executable(cmd) == 1
				end, lint.linters_by_ft[vim.bo.filetype] or {})
				if #names > 0 then
					lint.try_lint(names)
				end
			end,
		})
		vim.keymap.set("n", "<leader>l", function()
			lint.try_lint()
		end, { desc = "Trigger linter for current file" })
	end,
}
