-- LazyVim 標準キーへの追加分のみ記述する
-- 標準一覧: https://www.lazyvim.org/keymaps
-- （j/k→gj/gk、<Esc>でハイライト解除などは LazyVim が標準装備）

local map = vim.keymap.set

-- 旧 vimrc からの引き継ぎ
map("i", "jj", "<Esc>", { silent = true })
map("i", "kk", "<Esc>", { silent = true })
map("n", "<leader>w", "<cmd>w<cr>", { desc = "Save" })
