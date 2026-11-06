return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "latex" } },
  },
  {
    "MeanderingProgrammer/render-markdown.nvim",
    opts = {
      latex = { converter = "latex2text" },
    },
  },
}
