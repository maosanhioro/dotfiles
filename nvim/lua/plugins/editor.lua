return {
  -- ディレクトリをバッファとして編集するファイラ（LazyVim に無い操作系なので維持）
  {
    "stevearc/oil.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    keys = { { "-", "<cmd>Oil<cr>", desc = "File explorer (oil)" } },
    opts = {
      default_file_explorer = true,
      view_options = { show_hidden = true },
    },
  },

  -- tmux ペインと nvim 分割を M-h/j/k/l で相互移動（tmux.conf 側の is_vim 判定と対）
  {
    "christoomey/vim-tmux-navigator",
    init = function()
      vim.g.tmux_navigator_no_mappings = 1
    end,
    cmd = { "TmuxNavigateLeft", "TmuxNavigateDown", "TmuxNavigateUp", "TmuxNavigateRight" },
    keys = {
      { "<M-h>", "<cmd>TmuxNavigateLeft<cr>", mode = { "n", "t" }, silent = true, desc = "Go to left pane" },
      { "<M-j>", "<cmd>TmuxNavigateDown<cr>", mode = { "n", "t" }, silent = true, desc = "Go to lower pane" },
      { "<M-k>", "<cmd>TmuxNavigateUp<cr>", mode = { "n", "t" }, silent = true, desc = "Go to upper pane" },
      { "<M-l>", "<cmd>TmuxNavigateRight<cr>", mode = { "n", "t" }, silent = true, desc = "Go to right pane" },
    },
  },
}
