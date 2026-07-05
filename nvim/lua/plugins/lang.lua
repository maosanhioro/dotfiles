return {
  -- html/css は LazyVim の Extras に無いため個別に有効化
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        html = {},
        cssls = {},
      },
    },
  },

  -- python は isort + black（Extras の black に isort を追加）
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        python = { "isort", "black" },
      },
    },
  },
}
