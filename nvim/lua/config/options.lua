-- 基本オプション
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.cursorline = true
vim.opt.mouse = "a"
vim.opt.clipboard = "unnamedplus"
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.updatetime = 200
vim.opt.timeoutlen = 400
vim.opt.signcolumn = "yes"
vim.opt.splitright = true
vim.opt.splitbelow = true
vim.opt.termguicolors = true
vim.opt.scrolloff = 8
vim.opt.sidescrolloff = 8
vim.opt.wrap = false
vim.opt.expandtab = true
vim.opt.shiftwidth = 2
vim.opt.tabstop = 2
vim.opt.softtabstop = 2
vim.opt.completeopt = { "menu", "menuone", "noselect" }
vim.opt.undofile = true

-- 旧 vimrc の互換設定
vim.opt.ambiwidth = "double"
vim.opt.fileencodings = { "ucs-boms", "utf-8", "euc-jp", "cp932" }
vim.opt.fileformats = { "unix", "dos", "mac" }
vim.opt.backup = false
vim.opt.swapfile = false
vim.opt.autoread = true
vim.opt.hidden = true
vim.opt.showcmd = true
vim.opt.wildmenu = true
vim.opt.showmatch = true
vim.opt.visualbell = true
