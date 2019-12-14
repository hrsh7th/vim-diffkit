let s:instances = {}

"
" diffkit#nvim#on_lines
"
function! diffkit#nvim#on_lines(params) abort
  if has_key(s:instances, a:params.id)
    let l:diff = s:instances[a:params.id]
    if has_key(l:diff.bufs, a:params.bufnr)
      call l:diff._on_change(a:params)
    endif
  endif
endfunction

"
" diffkit#nvim#import
"
function! diffkit#nvim#import() abort
  return s:Diff
endfunction


let s:Diff = {}

"
" new
"
function! s:Diff.new() abort
  let l:id = len(keys(s:instances))
  let s:instances[l:id] = extend(deepcopy(s:Diff), {
        \   'id': l:id,
        \   'bufs': {}
        \ })
  return s:instances[l:id]
endfunction

"
" attach
"
function! s:Diff.attach(bufnr) abort
  if has_key(self.bufs, a:bufnr)
    call self.detach(a:bufnr)
  endif

  let l:lines = getbufline(a:bufnr, '^', '$')
  let self.bufs[a:bufnr] = {
        \   'lines': getbufline(a:bufnr, '^', '$'),
        \   'diff': {
        \     'fix': 0,
        \     'old': {
        \       'start': len(l:lines),
        \       'end': 0
        \     },
        \     'new': {
        \       'start': len(l:lines),
        \       'end': 0
        \     }
        \   }
        \ }
  call luaeval('require("diffkit.diff").attach(_A[1], _A[2])', [self.id, a:bufnr])
endfunction

"
" detach
"
function! s:Diff.detach(bufnr) abort
  if has_key(self.bufs, a:bufnr)
    unlet self.bufs[a:bufnr]
    call luaeval('require("diffkit.diff").detach(_A[1], _A[2])', [self.id, a:bufnr])
  endif
endfunction

"
" compute
"
function! s:Diff.compute(bufnr) abort
  if !has_key(self.bufs, a:bufnr)
    thro 'diffkit: nvim: invalid bufnr.'
  endif

  let l:buf = self.bufs[a:bufnr]
  let l:old = l:buf.lines
  let l:new = getbufline(a:bufnr, '^', '$')
  let l:buf.lines = l:new
  let l:buf.diff = {
        \   'fix': 0,
        \   'old': {
        \     'start': len(l:buf.lines),
        \     'end': 0
        \   },
        \   'new': {
        \     'start': len(l:buf.lines),
        \     'end': 0
        \   }
        \ }

  return diffkit#compute(
        \   l:old[l:buf.diff.old.start : l:buf.diff.old.end],
        \   l:new[l:buf.diff.new.start : l:buf.diff.new.end]
        \ )
endfunction

"
" _on_change
"
" - params.id
" - params.bufnr
" - params.changedtick
" - params.firstline
" - params.lastline
" - params.new_lastline
" - params.old_byte_size
" - params.old_utf32_size
" - params.old_utf16_size
"
function! s:Diff._on_change(params) abort
  if !has_key(self.bufs, a:params.bufnr)
    return
  endif

  echomsg string(a:params)

  let l:change = {
        \   'lnum': a:params.firstline,
        \   'end': a:params.new_lastline,
        \   'added': a:params.new_lastline - a:params.lastline
        \ }

  echomsg string(l:change.added)

  let l:diff = self.bufs[a:params.bufnr].diff

  " old diff.
  let l:old = l:diff.old

  let l:c = copy(l:change)
  let l:c.end = l:change.end - l:diff.fix

  let l:diff.fix += l:c.added

  " update start position.
  if l:c.lnum <= l:old.start
    let l:old.start = l:c.lnum
  endif

  " update end position.
  if l:old.end <= l:c.end
    let l:old.end = l:c.end
  endif

  " new diff.
  let l:new = l:diff.new
  if l:change.end <= l:new.start
    let l:new.start += l:change.added
  endif
  if l:change.end <= l:new.end
    let l:new.end += l:change.added
  endif

  let l:new.start = min([l:new.start, l:change.lnum])
  if l:change.end + l:change.added > l:new.end
    let l:new.end = max([l:new.end, l:change.end])
  endif

  echomsg string(l:diff)
endfunction

if exists('s:diff')
  call s:diff.detach(bufnr('%'))
endif
let s:diff = s:Diff.new()
call s:diff.attach(bufnr('%'))

function! s:compute()
  echomsg string(s:diff.bufs[bufnr('%')].diff)
  echomsg string(s:diff.compute(bufnr('%')))
endfunction

command! DiffCompute call <SID>compute()

