-- tmux ステータスバーが One Dark 配色のため、エディタも合わせる
return {
  { "navarasu/onedark.nvim", lazy = true, opts = { style = "dark" } },
  { "LazyVim/LazyVim", opts = { colorscheme = "onedark" } },
}
