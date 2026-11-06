return {
    "MeanderingProgrammer/render-markdown.nvim",
    ft = { "markdown" },
    dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-tree/nvim-web-devicons" },
    opts = {
        -- LaTeX rendering needs latex2text (python-pylatexenc), which isn't installed.
        latex = { enabled = false },
    },
}
