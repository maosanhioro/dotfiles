-- キーマップ
vim.g.mapleader = " "
vim.g.maplocalleader = " "

local map = vim.keymap.set

map("n", "<leader>w", "<cmd>w<cr>", { desc = "Save" })
map("n", "<leader>q", "<cmd>q<cr>", { desc = "Quit" })
map("n", "<leader>h", "<cmd>nohlsearch<cr>", { desc = "No highlight" })

map("n", "<leader>ff", "<cmd>Telescope find_files<cr>", { desc = "Find files" })
map("n", "<leader>fg", "<cmd>Telescope live_grep<cr>", { desc = "Live grep" })
map("n", "<leader>fb", "<cmd>Telescope buffers<cr>", { desc = "Buffers" })
map("n", "<leader>fh", "<cmd>Telescope help_tags<cr>", { desc = "Help tags" })

map("n", "-", "<cmd>Oil<cr>", { desc = "File explorer (oil)" })
map("n", "<leader>qs", "<cmd>lua require('persistence').load()<cr>", { desc = "Session restore" })
map("n", "<leader>ql", "<cmd>lua require('persistence').load({ last = true })<cr>", { desc = "Session restore (last)" })
map("n", "<leader>qd", "<cmd>lua require('persistence').stop()<cr>", { desc = "Session stop" })

map("n", "<leader>e", vim.diagnostic.open_float, { desc = "Line diagnostics" })
map("n", "[d", vim.diagnostic.goto_prev, { desc = "Prev diagnostic" })
map("n", "]d", vim.diagnostic.goto_next, { desc = "Next diagnostic" })

local ok_trouble, trouble = pcall(require, "trouble")
if ok_trouble then
  map("n", "<leader>xx", function() trouble.toggle() end, { desc = "Trouble" })
  map("n", "<leader>xw", function() trouble.toggle("workspace_diagnostics") end, { desc = "Trouble workspace diagnostics" })
  map("n", "<leader>xd", function() trouble.toggle("document_diagnostics") end, { desc = "Trouble document diagnostics" })
  map("n", "<leader>xl", function() trouble.toggle("loclist") end, { desc = "Trouble loclist" })
  map("n", "<leader>xq", function() trouble.toggle("quickfix") end, { desc = "Trouble quickfix" })
  map("n", "gR", function() trouble.toggle("lsp_references") end, { desc = "Trouble references" })
end

-- 旧 vimrc のマッピング
map("n", "<Esc><Esc>", "<cmd>nohlsearch<cr>", { desc = "No highlight" })
map("i", "jj", "<Esc>", { silent = true })
map("i", "kk", "<Esc>", { silent = true })
map("n", "j", "gj")
map("n", "k", "gk")
map("n", "<down>", "gj")
map("n", "<up>", "gk")
