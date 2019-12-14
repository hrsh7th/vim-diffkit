if has('vim_starting')
  set encoding=utf-8
endif
scriptencoding utf-8

if &compatible
  " vint: -ProhibitSetNoCompatible
  set nocompatible
endif

if !isdirectory(expand('~/.vim/plugged/vim-plug'))
  silent !curl -fLo ~/.vim/plugged/vim-plug/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
end
execute printf('source %s', expand('~/.vim/plugged/vim-plug/plug.vim'))

call plug#begin('~/.vim/plugged')
Plug 'gruvbox-community/gruvbox'
Plug expand('<sfile>:p:h:h') . '/vim-diffkit'
call plug#end()

colorscheme gruvbox

let g:mapleader = ' '

