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
        \   'type': 'nvim',
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
" sync
"
function! s:Diff.sync(bufnr) abort
  if has_key(self.bufs, a:bufnr)
    let l:buf = self.bufs[a:bufnr]
    let l:buf.lines = getbufline(a:bufnr, '^', '$')
    let l:buf.diff = {
          \   'fix': 0,
          \   'old': {
          \     'start': len(l:buf.lines),
          \     'end': 0,
          \   },
          \   'new': {
          \     'start': len(l:buf.lines),
          \     'end': 0,
          \   }
          \ }
  endif
endfunction

"
" flush
"
function! s:Diff.flush(bufnr) abort
  " noop
endfunction

"
" get_lines
"
function! s:Diff.get_lines(bufnr) abort
  if !has_key(self.bufs, a:bufnr)
    return getbufline(a:bufnr, '^', '$')
  endif
  return self.bufs[a:bufnr].lines
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

  let l:diff = diffkit#compute(
        \   l:old[l:buf.diff.old.start - 1 : l:buf.diff.old.end - 1],
        \   l:new[l:buf.diff.new.start - 1 : l:buf.diff.new.end - 1]
        \ )
  let l:diff.range.start.line += l:buf.diff.old.start - 1
  let l:diff.range.end.line += l:buf.diff.old.start - 1

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

  return l:diff
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

  let a:params.changes = [{
        \   'lnum': a:params.firstline + 1,
        \   'end': a:params.lastline + 1,
        \   'added': a:params.new_lastline - a:params.lastline
        \ }]

  let l:diff = self.bufs[a:params.bufnr].diff

  " old diff.
  let l:old = l:diff.old
  for l:change in a:params.changes
    let l:old.start = min([l:old.start, l:change.lnum])
    let l:old.end = max([l:old.end, l:change.end - l:diff.fix])

    if l:change.end <= l:old.end + l:diff.fix || l:old.end == -1
      let l:diff.fix += l:change.added
    endif
  endfor

  " new diff.
  let l:new = l:diff.new
  for l:change in a:params.changes
    let l:newchange = {
          \   'start': l:change.lnum,
          \   'end': l:change.end + l:change.added,
          \   'added': l:change.added
          \ }
    if l:newchange.end <= l:new.end
      let l:new.end += l:newchange.added
    endif

    let l:new.start = min([l:new.start, l:change.lnum])
    let l:new.end = max([l:new.end, l:newchange.end])
  endfor
endfunction

