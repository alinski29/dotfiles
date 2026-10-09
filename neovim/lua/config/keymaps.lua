-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
local keymap = vim.api.nvim_set_keymap
local opts = { noremap = true, silent = true }

-- Modes
--    normal = "n"
--    insert = "i"
--    visual = "v"
--    visual block = "x"
--    term = "t"
--    command = "c"

vim.g.mapleader = " "

keymap("n", "<leader>vr", ":source ~/.config/nvim/init.lua<CR>", opts)
keymap("n", "<leader>h", ":nohls<CR>", opts) -- turn off highlighting after search

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
-- keymap("n", "<C-x>", ":bd<CR>", opts)
keymap("n", "<C-x>", ":lua Snacks.bufdelete()<CR>", opts)

-- Navigate windows
keymap("n", "<A-h>", ":wincmd h<CR>", opts)
keymap("n", "<A-l>", ":wincmd l<CR>", opts)
keymap("n", "<A-j>", ":wincmd j<CR>", opts)
keymap("n", "<A-k>", ":wincmd k<CR>", opts)

-- Window splitting
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

keymap("n", "<c-e>", ":lua Snacks.explorer.open()<CR>", opts) -- alternatives: <leader>e / <leader>E, <leader>fe
keymap("n", "<c-o>", ":lua Snacks.picker.files()<CR>", opts) -- alternatives: <leader>space, <leader>ff
keymap("n", "<c-f>", ":lua Snacks.picker.grep()<CR>", opts) -- alternatives: <leader>/ / leader<sg> (grep in cw) / leader sG (greep in cw)
keymap("n", "<leader>fw", ":lua Snacks.picker.grep_word()<CR>", opts) --
-- Document symbols: LSP first, treesitter fallback when no LSP symbols
local function symbols_picker()
  local buf = vim.api.nvim_get_current_buf()
  local capable = vim.lsp.get_clients({ bufnr = buf, method = "textDocument/documentSymbol" })
  if #capable == 0 then
    Snacks.picker.treesitter()
    return
  end
  -- LSP attached: check it actually returns symbols before opening
  local params = vim.lsp.util.make_text_document_params(buf)
  vim.lsp.buf_request_all(buf, "textDocument/documentSymbol", params, function(results)
    for _, r in pairs(results) do
      if r.result and #r.result > 0 then
        Snacks.picker.lsp_symbols()
        return
      end
    end
    Snacks.picker.treesitter()
  end)
end

vim.keymap.set("n", "<c-.>", symbols_picker, { desc = "Document symbols (LSP, treesitter fallback)" })
vim.keymap.set("n", "<leader>.", symbols_picker, { desc = "Document symbols (LSP, treesitter fallback)" })
-- Fuzy search alternatives:
-- <leader>sw → current word / visual selection
-- <leader>sg → grep in root dir
-- <leader>sG → grep in cw

-- vim.keymap.set("n", "<space>f", function() vim.lsp.buf.format { async = true } end, opts)
keymap("n", "<space>f", "<cmd>lua vim.lsp.buf.format()<CR>", opts)

-- Mole: copy all session annotations to clipboard (works from any window)
vim.keymap.set("n", "<leader>my", function()
  local ok, mole = pcall(require, "mole.session")
  if not (ok and mole.state.active and mole.state.file_path) then
    vim.notify("No active mole session", vim.log.levels.WARN)
    return
  end
  local lines = vim.fn.readfile(mole.state.file_path)
  local content = table.concat(lines, "\n")
  vim.fn.setreg("+", content)
  vim.notify("Copied " .. #lines .. " lines to clipboard", vim.log.levels.INFO)
end, { desc = "Mole: copy annotations to clipboard" })
