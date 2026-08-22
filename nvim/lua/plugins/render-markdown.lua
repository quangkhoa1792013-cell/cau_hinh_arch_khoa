return {
  "MeanderingProgrammer/render-markdown.nvim",
  dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-mini/mini.icons" },
  ft = { "markdown", "codecompanion" }, -- Tự kích hoạt khi mở file Markdown hoặc bảng Chat AI
  opts = {
    file_types = { "markdown", "codecompanion" },
  },
}
