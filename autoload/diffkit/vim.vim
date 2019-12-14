"
" diffkit#vim#import
"
function! diffkit#vim#import() abort
  return s:Diff
endfunction


let s:Diff = {}

"
" new
"
function! s:Diff.new() abort
  return extend(deepcopy(s:Diff), {
        \   'bufs': {}
        \ })
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
        \   'id': listener_add({ bufnr, start, end, added, changes -> self._on_change({
        \     'bufnr': bufnr,
        \     'startline': start,
        \     'endline': end,
        \     'added': added,
        \     'changes': changes
        \   }) }, a:bufnr),
        \   'lines': l:lines,
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
endfunction

"
" detach
"
function! s:Diff.detach(bufnr) abort
  if has_key(self.bufs, a:bufnr)
    call listener_remove(self.bufs[a:bufnr].id)
    unlet self.bufs[a:bufnr]
  endif
endfunction

"
" compute
"
function! s:Diff.compute(bufnr) abort
  if !has_key(self.bufs, a:bufnr)
    thro 'diffkit: vim: invalid bufnr.'
  endif

  call listener_flush(a:bufnr)

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
        \   l:old[l:buf.diff.old.start - 1 : l:buf.diff.old.end - 1],
        \   l:new[l:buf.diff.new.start - 1: l:buf.diff.new.end - 1]
        \ )
endfunction

"
" _on_change
"
" - params.bufnr
" - params.startline
" - params.endline
" - params.added
" - params.changes
"
function! s:Diff._on_change(params) abort
  if !has_key(self.bufs, a:params.bufnr)
    return
  endif

  let l:diff = self.bufs[a:params.bufnr].diff

  " old diff.
  let l:old = l:diff.old
  for l:change in a:params.changes
    echomsg string(l:change)
    let l:c = copy(l:change)
    let l:c.start = l:change.lnum
    let l:c.end = l:change.end - l:diff.fix

    let l:diff.fix += l:c.added

    " update start position.
    if l:c.start <= l:old.start
      let l:old.start = l:c.start
    endif

    " update end position.
    if l:old.end <= l:c.end
      let l:old.end = l:c.end
    endif
  endfor

  " new diff.
  let l:new = l:diff.new
  for l:change in a:params.changes
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
  endfor
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

