
"
" CheckBinPath checks whether the given binary exists or not and returns the
" path of the binary, respecting the go_bin_path and go_search_bin_path_first
" settings. It returns an empty string if the binary doesn't exist.
 function! CheckBinPath(binpath) abort
   " remove whitespaces if user applied something like 'goimports   '
   let binpath = substitute(a:binpath, '^\s*\(.\{-}\)\s*$', '\1', '')

   " save original path
   let old_path = $PATH

   " if it's in PATH just return it
   if executable(binpath)
     if exists('*exepath')
       let binpath = exepath(binpath)
     endif
     let $PATH = old_path
     return binpath
   endif

  " just get the basename
   let basename = fnamemodify(binpath, ":t")
     if !executable(basename)
       echom 'Could not find ' . basename
       " restore back!
       let $PATH = old_path
       return
     endif

     let $PATH = old_path
     return go_bin_path . '/' . basename
endfunction

function! s:system(cmd, ...) abort
  " Preserve original shell, shellredir and shellcmdflag values
  let l:shell = &shell
  let l:shellredir = &shellredir
  let l:shellcmdflag = &shellcmdflag

  set shell=/bin/sh shellredir=>%s\ 2>&1 shellcmdflag=-c
  try
    return call('system', [a:cmd] + a:000)
  finally
    " Restore original values
    let &shell = l:shell
    let &shellredir = l:shellredir
    let &shellcmdflag = l:shellcmdflag
  endtry
endfunction

" Shelljoin returns a shell-safe string representation of arglist. The
" {special} argument of shellescape() may optionally be passed.
function! s:shelljoin(arglist, ...) abort
  try
    let ssl_save = &shellslash
    set noshellslash
    if a:0
      return join(map(copy(a:arglist), 'shellescape(v:val, ' .  a:1 . ')'), ' ')
    endif
    return join(map(copy(a:arglist), 'shellescape(v:val)'), ' ')
  finally
    let &shellslash = ssl_save
  endtry
endfunction


function! s:exec(cmd, ...) abort
  let l:bin = a:cmd[0]
  let l:cmd = s:shelljoin([l:bin] + a:cmd[1:])
  let l:out = call('s:system', [l:cmd] + a:000)
  return [l:out, v:shell_error]
endfunction

function! ExecInDir(cmd, ...) abort
  if !isdirectory(expand("%:p:h"))
    return ['', 1]
  endif

  let cd = exists('*haslocaldir') && haslocaldir() ? 'lcd ' : 'cd '
  let dir = getcwd()
  try
    execute cd . fnameescape(expand("%:p:h"))
    let [l:out, l:err] = call('s:exec', [a:cmd] + a:000)
  finally
    execute cd . fnameescape(l:dir)
  endtry
  return [l:out, l:err]
endfunction

function! Exec(cmd, ...) abort
  if len(a:cmd) == 0
    echom "exec() called with empty a:cmd")
    return ['', 1]
  endif

  let l:bin = a:cmd[0]
  " Lookup the full path, respecting settings such as
  " 'go_bin_path'. On errors, CheckBinPath will show a warning for us.
  let l:bin = CheckBinPath(l:bin)
  if empty(l:bin)
    return ['', 1]
  endif

  " Finally execute the command using the full, resolved path. Do not pass the
  " unmodified command as the correct program might not exist in $PATH.
  return call('s:exec', [[l:bin] + a:cmd[1:]] + a:000)
endfunction

