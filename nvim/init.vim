" Minimal, built-in-only defaults — no plugin manager.
" Symlinked into ~/.config/nvim/init.vim by scripts/installers/21-nvim-config.sh

set expandtab       " spaces, not tabs
set tabstop=2
set shiftwidth=2
set softtabstop=2
set smartindent
set autoindent

set list
set listchars=trail:·,tab:»\ ,nbsp:␣

" Trim trailing whitespace on save, preserving cursor position.
autocmd BufWritePre * :%s/\s\+$//e

set number
set ignorecase
set smartcase
