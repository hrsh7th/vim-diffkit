"
" diffkit#import
"
function! diffkit#import() abort
  if exists('*listener_add')
    return diffkit#vim#import()
  endif
  if has('nvim')
    return diffkit#nvim#import()
  endif
  return diffkit#compat#import()
endfunction

"
" diffkit#compute
"
function! diffkit#compute(old, new) abort
  let [l:start_line, l:start_char] = s:first_difference(a:old, a:new)
  let [l:end_line, l:end_char] = s:last_difference(a:old[l:start_line :], a:new[l:start_line :], l:start_char)

  let l:text = s:extract_text(a:new, l:start_line, l:start_char, l:end_line, l:end_char)
  let l:length = s:length(a:old, l:start_line, l:start_char, l:end_line, l:end_char)

  let l:adj_end_line = len(a:old) + l:end_line
  let l:adj_end_char = l:end_line == 0 ? 0 : strchars(a:old[l:end_line]) + l:end_char + 1

  return {
        \   'range': {
        \     'start': { 'line': l:start_line, 'character': l:start_char },
        \     'end': { 'line': l:adj_end_line, 'character': l:adj_end_char }
        \   },
        \   'text': l:text,
        \   'rangeLength': l:length,
        \ }
endfunction

"
" first_difference
"
function! s:first_difference(old, new) abort
  let l:line_count = min([len(a:old), len(a:new)])
  if l:line_count == 0 | return [0, 0] | endif
  let l:i = 0
  while l:i < l:line_count
    if a:old[l:i] !=# a:new[l:i] | break | endif
    let l:i += 1
  endwhile
  if l:i >= l:line_count
    return [l:line_count - 1, strchars(a:old[l:line_count - 1])]
  endif
  let l:old_line = a:old[l:i]
  let l:new_line = a:new[l:i]
  let l:length = min([strchars(l:old_line), strchars(l:new_line)])
  let l:j = 0
  while l:j < l:length
    if strgetchar(l:old_line, l:j) != strgetchar(l:new_line, l:j) | break | endif
    let l:j += 1
  endwhile
  return [l:i, l:j]
endfunction

"
" last_difference
"
function! s:last_difference(old, new, start_char) abort
  let l:line_count = min([len(a:old), len(a:new)])
  if l:line_count == 0 | return [0, 0] | endif
  let l:i = -1
  while l:i >= -1 * l:line_count
    if a:old[l:i] !=# a:new[l:i] | break | endif
    let l:i -= 1
  endwhile
  if l:i <= -1 * l:line_count
    let l:i = -1 * l:line_count
    let l:old_line = strcharpart(a:old[l:i], a:start_char)
    let l:new_line = strcharpart(a:new[l:i], a:start_char)
  else
    let l:old_line = a:old[l:i]
    let l:new_line = a:new[l:i]
  endif
  let l:old_line_length = strchars(l:old_line)
  let l:new_line_length = strchars(l:new_line)
  let l:length = min([l:old_line_length, l:new_line_length])
  let l:j = -1
  while l:j >= -1 * l:length
    if  strgetchar(l:old_line, l:old_line_length + l:j) !=
        \ strgetchar(l:new_line, l:new_line_length + l:j)
      break
    endif
    let l:j -= 1
  endwhile
  return [l:i, l:j]
endfunction

"
" extract_text
"
function! s:extract_text(lines, start_line, start_char, end_line, end_char) abort
  if a:start_line == len(a:lines) + a:end_line
    if a:end_line == 0 | return '' | endif
    let l:line = a:lines[a:start_line]
    let l:length = strchars(l:line) + a:end_char - a:start_char + 1
    return strcharpart(l:line, a:start_char, l:length)
  endif
  let l:result = strcharpart(a:lines[a:start_line], a:start_char) . "\n"
  for l:line in a:lines[a:start_line + 1:a:end_line - 1]
    let l:result .= l:line . "\n"
  endfor
  if a:end_line != 0
    let l:line = a:lines[a:end_line]
    let l:length = strchars(l:line) + a:end_char + 1
    let l:result .= strcharpart(l:line, 0, l:length)
  endif
  return l:result
endfunction

"
" length
"
function! s:length(lines, start_line, start_char, end_line, end_char) abort
  let l:adj_end_line = len(a:lines) + a:end_line
  if l:adj_end_line >= len(a:lines)
    let l:adj_end_char = a:end_char - 1
  else
    let l:adj_end_char = strchars(a:lines[l:adj_end_line]) + a:end_char
  endif
  if a:start_line == l:adj_end_line
    return l:adj_end_char - a:start_char + 1
  endif
  let l:result = strchars(a:lines[a:start_line]) - a:start_char + 1
  let l:line = a:start_line + 1
  while l:line < l:adj_end_line
    let l:result += strchars(a:lines[l:line]) + 1
    let l:line += 1
  endwhile
  let l:result += l:adj_end_char + 1
  return l:result
endfunction

