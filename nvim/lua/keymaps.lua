local keymap = vim.api.nvim_set_keymap
local opts = { noremap = true, silent = true }

-- Modes
--    normal = "n"
--    insert = "i"
--    visual = "v"
--    visual block = "x"
--    term = "t"
--    command = "c"

keymap("n", "<leader>vr", ":source ~/.config/nvim/init.lua<CR>", opts)
keymap("n", "<leader>h", ":nohls", opts) -- turn off highligting after search

keymap("i", "jk", "<esc>", opts)
keymap("i", "kj", "<esc>", opts)

-- Keep selection when identing / outdenting in visual mode
keymap("v", "<", "<gv", {})
keymap("v", ">", ">gv", {})

-- Navigate buffers
keymap("n", "<S-l>", ":bn<CR>", opts)
keymap("n", "<S-h>", ":bp<CR>", opts)
keymap("n", "<A-S-l>", ":BufferLineMoveNext<CR>", opts)
keymap("n", "<A-S-h>", ":BufferLineMovePrev<CR>", opts)
keymap("n", "<c-x>", ":bd<CR>", opts)

-- Navigate windows
keymap("n", "<A-h>", ":wincmd h<CR>", opts)
keymap("n", "<A-l>", ":wincmd l<CR>", opts)
keymap("n", "<A-j>", ":wincmd j<CR>", opts)
keymap("n", "<A-k>", ":wincmd k<CR>", opts)

-- Window splitting (same keys work in Telescope and NvimTree)
keymap("n", "<c-v>", "<c-w>v", opts)
keymap("n", "<c-h>", "<c-w>s", opts)

-- Resize with arrows
keymap("n", "<C-Up>", ":resize -2<CR>", opts)
keymap("n", "<C-Down>", ":resize +2<CR>", opts)
keymap("n", "<C-Left>", ":vertical resize -2<CR>", opts)
keymap("n", "<C-Right>", ":vertical resize +2<CR>", opts)

-- Move text up and down in visual and visual block mode
keymap("v", "<A-j>", ":m .+1<CR>==", opts)
keymap("v", "<A-k>", ":m .-2<CR>==", opts)
keymap("v", "p", '"_dP', opts)
keymap("x", "J", ":move '>+1<CR>gv-gv", opts)
keymap("x", "K", ":move '<-2<CR>gv-gv", opts)
keymap("x", "<A-j>", ":move '>+1<CR>gv-gv", opts)
keymap("x", "<A-k>", ":move '<-2<CR>gv-gv", opts)

-- go back / go next cursor position
keymap("n", "<c-b>", "<c-o>", opts)
keymap("n", "<c-n>", "<c-i>", opts)

--keymap('n', '<c-e>', ':Telescope file_browser<CR>', opts)
keymap("n", "<c-e>", ":NvimTreeToggle<CR>", opts)
keymap("n", "<c-o>", ":Telescope find_files<CR>", opts)
--keymap('n', '<c-f>', ':Telescope grep_string<CR>', opts)
keymap("n", "<c-f>", ":Telescope current_buffer_fuzzy_find<CR>", opts)
