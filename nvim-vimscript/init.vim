set showtabline=2
set hidden    " Required to keep multiple buffers open
set encoding=utf-8
set fileencoding=utf-8
set ruler      " Show cursor position at all times
set mouse=a
set splitbelow  " Horizontal splits will automatically be below
set splitright  " Vertical splits will automatically be to the right
set autoindent
set background=dark " Tell vim you're using a dark background
set clipboard=unnamedplus " Copy paste between vim and everything else
set relativenumber " Show relative line numbers
set number
set tabstop=2 " Insert 2 spaces for a tab
set expandtab " Converts tabs to spaces
set smarttab " Makes tabing smarter. Will realize you havve 2 instead of 4
set smartindent
set autoindent
set cursorline " Highlight the line where the cursor is at
set clipboard=unnamedplus
set spell
set title
set ignorecase
set smartcase
set cmdheight=2
set updatetime=500
set shiftwidth=2
set scrolloff=8
set sidescrolloff=8
set timeoutlen=500
set termguicolors
set wildmenu

let mapleader = "\<space>"

# Navigate buffers
tnoremap <A-h> <C-\><C-n><C-w>h
tnoremap <A-j> <C-\><C-n><C-w>j
tnoremap <A-k> <C-\><C-n><C-w>k
tnoremap <A-l> <C-\><C-n><C-w>l
nnoremap <A-h> <C-w>h
nnoremap <A-j> <C-w>j
nnoremap <A-k> <C-w>k
nnoremap <A-l> <C-w>l

# Turn off highlights after search
nnoremap <leader>h :nohls<cr>

# To to normal mode by quickly pressing kj or jk 
inoremap jk <esc>
inoremap kj <esc>
inoremap jj <esc>
" inoremap kk <esc>

# Go to first or last character from insert mode
inoremap <A-h> <esc>^i
inoremap <A-l> <esc>g_a
inoremap <A-k> <esc>ka
inoremap <A-j> <esc>ja
inoremap <A-o> <esc>o

# Keep selection when identing / outdenting in visual mode
vnoremap < <gv
vnoremap > >gv

" Navigate buffers using Shift + h/l 
nnoremap  <S-l> :bn<CR>
nnoremap  <S-h> :bp<CR>
" nnoremap  <S-n> :tabnew<CR> 

" Window resize using Ctrl + h/j/k/l
tnoremap <Esc> <C-\><C-n>

"auto close {
function! s:CloseBracket()
    let line = getline('.')
    if line =~# '^\s*\(struct\|class\|enum\) '
        return "{\<Enter>};\<Esc>O"
    elseif searchpair('(', '', ')', 'bmn', '', line('.'))
        " Probably inside a function call. Close it off.
        return "{\<Enter>});\<Esc>O"
    else
        return "{\<Enter>}\<Esc>O"
    endif
endfunction
inoremap <expr> {<Enter> <SID>CloseBracket()
inoremap <expr> [<Enter> <SID>CloseBracket()
inoremap <expr> (<Enter> <SID>CloseBracket()
