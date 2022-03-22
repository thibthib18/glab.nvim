if !executable('glab') | echom "[Glab.nvim] Cannot find `glab` command" | finish | endif
if !has('nvim-0.5') | echom "[Glab.nvim] Glab.nvim requires neovim 0.5+" | finish | endif

lua require"glab-nvim"
lua require'octo.colors'.setup()
