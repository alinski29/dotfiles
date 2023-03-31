local keymap = vim.api.nvim_set_keymap
local opts = { noremap = true, silent = true }

-- Modes
--    normal = "n"
--    insert = "i"
--    visual = "v"
--    visual block = "x"
--    term = "t"
--    command = "c"

lvim.builtin.which_key.mappings['w'] = {}
lvim.builtin.which_key.mappings['q'] = {}
lvim.builtin.which_key.mappings['T'] = {}
lvim.builtin.which_key.mappings['s'] = {}
lvim.builtin.which_key.mappings['p'] = {}
lvim.builtin.which_key.mappings['e'] = {}
lvim.builtin.which_key.mappings['f'] = {}
lvim.builtin.which_key.mappings['c'] = {}
lvim.builtin.which_key.mappings['g'] = {}

vim.g.mapleader = " "

keymap("n", "<leader>h", ":nohls<CR>", opts) -- turn off highligting after search

keymap("i", "jk", "<esc>", opts)
keymap("i", "kj", "<esc>", opts)

-- Go to first or last character from insert mode
keymap("i", "<A-h>", "<esc>^i", opts)
keymap("i", "<A-l>", "<esc>g_a", opts)
keymap("i", "<A-k>", "<esc>ka", opts)
keymap("i", "<A-j>", "<esc>ja", opts)
keymap("i", "<A-o>", "<esc>o", opts)

-- Keep selection when identing / outdenting in visual mode
keymap("v", "<", "<gv", {})
keymap("v", ">", ">gv", {})

-- Navigate buffers
keymap("n", "<S-l>", ":bn<CR>", opts)
keymap("n", "<S-h>", ":bp<CR>", opts)
keymap("n", "<A-S-l>", ":BufferLineMoveNext<CR>", opts)
keymap("n", "<A-S-h>", ":BufferLineMovePrev<CR>", opts)
keymap("n", "<c-x>", ":bd<CR>", opts)
keymap("n", "<C-x>", ":BufferKill<CR>", opts)

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

keymap("n", "<c-e>", ":lua require'nvim-tree'.toggle(false, true)<CR>", opts)
keymap("n", "<c-o>", ":Telescope find_files<CR>", opts)
keymap('n', '<c-f>', ':Telescope grep_string<CR>', opts)
-- keymap("n", "<c-f>", ":Telescope current_buffer_fuzzy_find<CR>", opts)


-- K	hover information	
-- gd	go to definition	
-- gD	go to declaration	
-- gr	go to references	
-- gI	go to implementation	
-- gs	show signature help	
-- gl	show line diagnostics

-- rely on telescope for this
lvim.lsp.buffer_mappings.normal_mode["gr"] = nil
lvim.lsp.buffer_mappings.normal_mode["gi"] = nil

keymap("n", "gd", "<cmd>Telescope lsp_definitions<CR>", opts)
keymap("n", "gr", "<cmd>Telescope lsp_references<CR>", opts)
keymap("n", "gi", "<cmd>Telescope lsp_implementations()<CR>", opts)
keymap("n", "gt", "<cmd>lua vim.lsp.buf.type_definition()<CR>", opts)
keymap("n", "<space>ca", "<cmd>lua vim.lsp.buf.code_action()<CR>", opts)
keymap("n", "<space>,", "<cmd>lua vim.lsp.buf.rename()<CR>", opts)
keymap("n", "<space>.", "<cmd>Telescope lsp_document_symbols<CR>", opts)
keymap("n", "<space>wd", "<cmd>Telescope diagnostics<CR>", opts)

vim.keymap.set("n", "<space>f", function() vim.lsp.buf.format { async = true } end, opts)
-- keymap("n", "gi", "<cmd>lua vim.lsp.buf.implementation()<CR>", opts)
-- keymap('n', 'gr', '<cmd>lua vim.lsp.buf.references()<CR>', opts)
-- keymap("n", "K", "<cmd>lua vim.lsp.buf.hover()<CR>", opts)
-- keymap("n", "gs", "<cmd>lua vim.lsp.buf.signature_help()<CR>", opts)
-- keymap("n", "<leader>p", "<cmd>lua vim.lsp.buf.signature_help()<CR>", opts)
-- keymap("n", "<space>wa", "<cmd>lua vim.lsp.buf.add_workspace_folder()<CR>", opts)
-- keymap("n", "<space>wr", "<cmd>lua vim.lsp.buf.remove_workspace_folder()<CR>", opts)
-- keymap("n", "<space>wl", "<cmd>lua print(vim.inspect(vim.lsp.buf.list_workspace_folders()))<CR>", opts)
-- keymap("n", "<space>ca", "<cmd>Telescope code_actions()<CR>", opts)
-- keymap("n", "<space>e", "<cmd>lua vim.diagnostic.open_float()<CR>", opts)
-- keymap("n", "<space>q", "<cmd>lua vim.diagnostic.setloclist()<CR>", opts)
-- keymap("n", "[d", "<cmd>lua vim.diagnostic.goto_prev()<CR>", opts)
-- keymap("n", "]d", "<cmd>lua vim.diagnostic.goto_next()<CR>", opts)ke

lvim.builtin.gitsigns.opts.keymaps = {
    noremap = true,

    ["n ]c"] = { expr = true, "&diff ? ']c' : '<cmd>Gitsigns next_hunk<CR>'" },
    ["n [c"] = { expr = true, "&diff ? '[c' : '<cmd>Gitsigns prev_hunk<CR>'" },

    ["n <leader>hs"] = "<cmd>Gitsigns stage_hunk<CR>",
    ["v <leader>hs"] = ":Gitsigns stage_hunk<CR>",
    ["n <leader>hu"] = "<cmd>Gitsigns undo_stage_hunk<CR>",
    ["n <leader>hr"] = "<cmd>Gitsigns reset_hunk<CR>",
    ["v <leader>hr"] = ":Gitsigns reset_hunk<CR>",
    ["n <leader>hR"] = "<cmd>Gitsigns reset_buffer<CR>",
    ["n <leader>hp"] = "<cmd>Gitsigns preview_hunk<CR>",
    ["n <leader>hb"] = '<cmd>lua require"gitsigns".blame_line{full=true}<CR>',
    ["n <leader>hS"] = "<cmd>Gitsigns stage_buffer<CR>",
    ["n <leader>hU"] = "<cmd>Gitsigns reset_buffer_index<CR>",

    -- Text objects
    ["o ih"] = ":<C-U>Gitsigns select_hunk<CR>",
    ["x ih"] = ":<C-U>Gitsigns select_hunk<CR>",
}
