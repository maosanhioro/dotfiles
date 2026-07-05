-- LazyVim デフォルトとの差分のみ記述する
-- デフォルト一覧: https://www.lazyvim.org/configuration/general

-- 日本語環境
-- 注意: ambiwidth=double は設定しない。LazyVim の UI は Nerd Font グリフ
-- （曖昧幅扱い）を fillchars や sign に使うため E835/E239 で全面的に衝突する。
-- 曖昧幅文字のズレは端末側の設定を narrow（半角）に揃えて解決すること
vim.opt.fileencodings = { "ucs-boms", "utf-8", "euc-jp", "cp932" }

-- 旧設定からの引き継ぎ
vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.visualbell = true
vim.opt.scrolloff = 8
vim.opt.sidescrolloff = 8
vim.opt.wrap = false
