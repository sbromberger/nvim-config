" don't spam the user when Vim is started in Vi compatibility mode
let s:cpo_save = &cpo
set cpo&vim

scriptencoding utf-8


" -- debug
if !exists(':GoDebugStart')
  command! -nargs=* GoDebugStart call Start(0, <f-args>)
  command! -nargs=* GoDebugTest  call Start(1, <f-args>)
  command! -nargs=? GoDebugBreakpoint call Breakpoint(<f-args>)
  nmap <Leader>d  :GoDebugStart<CR>
  nmap <Leader>b  :GoDebugBreakpoint<CR>
endif

function! s:debug() abort
  return get(g:, 'go_debug', [])
endfunction

" Report if the user enabled a debug flag in g:go_debug.
function! s:hasDebug(flag)
  return index(s:debug(), a:flag) >= 0
 endfunction

function! s:debugCommands() abort
  " make sure g:go_debug_commands is set so that it can be added to easily.
  let g:go_debug_commands = get(g:, 'go_debug_commands', [])
  return g:go_debug_commands
endfunction

function! s:setDebugDiag(value) abort
   let g:go_debug_diag = a:value
 endfunction

if !exists('s:state')
  let s:state = {
      \ 'rpcid': 1,
      \ 'running': 0,
      \ 'currentThread': {},
      \ 'localVars': {},
      \ 'functionArgs': {},
      \ 'message': [],
      \ 'is_test': 0,
      \}

  if s:hasDebug('debugger-state')
     call s:setDebugDiag(s:state)
  endif
endif

if !exists('s:start_args')
  let s:start_args = []
endif

function! s:groutineID() abort
  return s:state['currentThread'].goroutineID
endfunction

function! s:complete(job, exit_status, data) abort
  let l:gotready = get(s:state, 'ready', 0)
  " copy messages to a:data _only_ when dlv exited non-zero and it was never
  " detected as ready (e.g. there was a compiler error).
  if a:exit_status > 0 && !l:gotready
      " copy messages to data so that vim-go's usual handling of errors from
      " async jobs will occur.
      call extend(a:data, s:state['message'])
  endif

  " return early instead of clearing any variables when the current job is not
  " a:job
  if has_key(s:state, 'job') && s:state['job'] != a:job
    return
  endif

  if has_key(s:state, 'job')
    call remove(s:state, 'job')
  endif

  if has_key(s:state, 'ready')
    call remove(s:state, 'ready')
  endif

  if has_key(s:state, 'ch')
    call remove(s:state, 'ch')
  endif

  call s:clearState()
endfunction

function! s:logger(prefix, ch, msg) abort
  let l:cur_win = bufwinnr('')
  let l:log_win = bufwinnr(bufnr('__GODEBUG_OUTPUT__'))
  if l:log_win == -1
    return
  endif
  exe l:log_win 'wincmd w'

  try
    setlocal modifiable
    if getline(1) == ''
      call setline('$', a:prefix . a:msg)
    else
      call append('$', a:prefix . a:msg)
    endif
    normal! G
    setlocal nomodifiable
  finally
    exe l:cur_win 'wincmd w'
  endtry
endfunction

function! s:call_jsonrpc(method, ...) abort
  if s:hasDebug('debugger-commands')
    echom 'sending to dlv ' . a:method
  endif

  let l:args = a:000
  let s:state['rpcid'] += 1
  let l:req_json = json_encode({
      \  'id': s:state['rpcid'],
      \  'method': a:method,
      \  'params': l:args,
      \})

  try
    let l:ch = s:state['ch']
    if has('nvim')
      call chansend(l:ch, l:req_json)
      while len(s:state.data) == 0
        sleep 50m
        if get(s:state, 'ready', 0) == 0
          return
        endif
      endwhile
      let resp_json = s:state.data[0]
      let s:state.data = s:state.data[1:]
    else
      call ch_sendraw(l:ch, req_json)
      let l:resp_raw = ch_readraw(l:ch)
      let resp_json = json_decode(l:resp_raw)
    endif

    if s:hasDebug('debugger-commands')
      let g:go_debug_commands = add(s:debugCommands(), {
            \ 'request':  l:req_json,
            \ 'response': l:resp_json,
      \ })
    endif

    if type(l:resp_json) == v:t_dict && has_key(l:resp_json, 'error') && !empty(l:resp_json.error)
      throw l:resp_json.error
    endif
    return l:resp_json
  catch
    if has_key(s:state, 'ch')
      throw substitute(v:exception, '^Vim', '', '')
    endif
  endtry
endfunction

" Update the location of the current breakpoint or line we're halted on based on
" response from dlv.
function! s:update_breakpoint(res) abort
  if type(a:res) ==# type(v:null)
    return
  endif

  let state = a:res.result.State
  if !has_key(state, 'currentThread')
    return
  endif

  let s:state['currentThread'] = state.currentThread
  let bufs = filter(map(range(1, winnr('$')), '[v:val,bufname(winbufnr(v:val))]'), 'v:val[1]=~"\.go$"')
  if len(bufs) == 0
    return
  endif

  exe bufs[0][0] 'wincmd w'
  let filename = state.currentThread.file
  let linenr = state.currentThread.line
  let oldfile = fnamemodify(expand('%'), ':p:gs!\\!/!')
  if oldfile != filename
    silent! exe 'edit' filename
  endif
  silent! exe 'norm!' linenr.'G'
  silent! normal! zvzz
  silent! sign unplace 9999
  silent! exe 'sign place 9999 line=' . linenr . ' name=godebugcurline file=' . filename
endfunction

" Populate the stacktrace window.
function! s:show_stacktrace(res) abort
  if !has_key(a:res, 'result')
    return
  endif

  let l:stack_win = bufwinnr(bufnr('__GODEBUG_STACKTRACE__'))
  if l:stack_win == -1
    return
  endif

  let l:cur_win = bufwinnr('')
  exe l:stack_win 'wincmd w'

  try
    setlocal modifiable
    silent %delete _
    for i in range(len(a:res.result.Locations))
      let loc = a:res.result.Locations[i]
      call setline(i+1, printf('%s - %s:%d', loc.function.name, fnamemodify(loc.file, ':p'), loc.line))
    endfor
  finally
    setlocal nomodifiable
    exe l:cur_win 'wincmd w'
  endtry
endfunction

" Populate the variable window.
function! s:show_variables() abort
  let l:var_win = bufwinnr(bufnr('__GODEBUG_VARIABLES__'))
  if l:var_win == -1
    return
  endif

  let l:cur_win = bufwinnr('')
  exe l:var_win 'wincmd w'

  try
    setlocal modifiable
    silent %delete _

    let v = []
    let v += ['# Local Variables']
    if type(get(s:state, 'localVars', [])) is type([])
      for c in s:state['localVars']
        let v += split(s:eval_tree(c, 0), "\n")
      endfor
    endif

    let v += ['']
    let v += ['# Function Arguments']
    if type(get(s:state, 'functionArgs', [])) is type([])
      for c in s:state['functionArgs']
        let v += split(s:eval_tree(c, 0), "\n")
      endfor
    endif

    call setline(1, v)
  finally
    setlocal nomodifiable
    exe l:cur_win 'wincmd w'
  endtry
endfunction

function! s:clearState() abort
  let s:state['currentThread'] = {}
  let s:state['localVars'] = {}
  let s:state['functionArgs'] = {}
  let s:state['message'] = []

  silent! sign unplace 9999
endfunction

function! s:configListType() abort
  return get(g:, 'go_list_type', '')
endfunction

function! s:configListTypeCommands() abort
  return get(g:, 'go_list_type_commands', {})
endfunction

function! s:configListAutoclose() abort
  return get(g:, 'go_list_autoclose', 1)
endfunction

function! s:configListHeight() abort
  return get(g:, "go_list_height", 0)
endfunction

" Window opens the list with the given height up to 10 lines maximum.
" Otherwise g:go_loclist_height is used.

" If no or zero height is given it closes the window by default.
" To prevent this, set g:go_list_autoclose = 0
function! s:listWindow(listtype, ...) abort
  " we don't use lwindow to close the location list as we need also the
  " ability to resize the window. So, we are going to use lopen and lclose
  " for a better user experience. If the number of errors in a current
  " location list increases/decreases, cwindow will not resize when a new
  " updated height is passed. lopen in the other hand resizes the screen.
  if !a:0 || a:1 == 0
    call s:listClose(a:listtype)
    return
  endif

  let height = s:configListHeight()
  if height == 0
    " prevent creating a large location height for a large set of numbers
    if a:1 > 10
      let height = 10
    else
      let height = a:1
    endif
  endif

  if a:listtype == "locationlist"
    exe 'lopen ' . height
  else
    exe 'copen ' . height
  endif
endfunction

" Close closes the location list
function! s:listClose(listtype) abort
  let autoclose_window = s:configListAutoclose()
  if !autoclose_window
    return
  endif
  if a:listtype == "locationlist"
    lclose
  else
    cclose
  endif
endfunction

" s:default_list_type_commands is the defaults that will be used for each of
" the supported commands (see documentation for g:go_list_type_commands).
" When defining a default, quickfix should be used if the command operates on
" multiple files, while locationlist should be used if the command operates
" on a single file or buffer. Keys that begin with an underscore are not
" supported in g:go_list_type_commands.
let s:default_list_type_commands = {
    \ "GoBuild":              "quickfix",
    \ "GoDebug":              "quickfix",
    \ "GoErrCheck":           "quickfix",
    \ "GoFmt":                "locationlist",
    \ "GoGenerate":           "quickfix",
    \ "GoInstall":            "quickfix",
    \ "GoLint": "quickfix",
    \ "GoMetaLinter": "quickfix",
    \ "GoMetaLinterAutoSave": "locationlist",
    \ "GoModFmt": "locationlist",
    \ "GoModifyTags": "locationlist",
    \ "GoRename": "quickfix",
    \ "GoRun": "quickfix",
    \ "GoTest": "quickfix",
    \ "GoVet": "quickfix",
    \ "_guru": "locationlist",
    \ "_term": "locationlist",
    \ "_job": "locationlist",
  \ }

function! s:listtype(listtype) abort
  let listtype = s:configListType()
  if empty(listtype)
    return a:listtype
  endif

  return listtype
endfunction
function! s:listType(for) abort
  let l:listtype = s:listtype(get(s:default_list_type_commands, a:for))
  if l:listtype == "0"
    echom 'unknown list type command value found (' . a:for . '. Please open a bug report in the vim-go repo."
    let l:listtype = "quickfix"
  endif
  return get(s:configListTypeCommands(), a:for, l:listtype)
endfunction

" Clean cleans and closes the location list 
function! s:listClean(listtype) abort
  if a:listtype == "locationlist"
    lex []
  else
    cex []
  endif
  call s:listClose(a:listtype)
endfunction

" Parse parses the given items based on the specified errorformat and
" populates the list.
function! s:listParseFormat(listtype, errformat, items, title) abort
  " backup users errorformat, will be restored once we are finished
  let old_errorformat = &errorformat
  " parse and populate the location list
  let &errorformat = a:errformat
  try
    call s:listParse(a:listtype, a:items, a:title)
  finally
    "restore back
    let &errorformat = old_errorformat
  endtry
endfunction

" Get returns the current items from the list
function! s:listGet(listtype) abort
  if a:listtype == "locationlist"
    return getloclist(0)
  else
    return getqflist()
  endif
endfunction

" JumpToFirst jumps to the first item in the location list
function! s:listJumpToFirst(listtype) abort
  if a:listtype == "locationlist"
    ll 1
  else
    cc 1
  endif
endfunction

function! s:jobstart(args) dict
  " if config#choCommandInfo() && self.statustype != ""
  "   let prefix = '[' . self.statustype . '] '
    " call go#util#EchoSuccess(prefix . "dispatched")
  " endif
  if self.statustype != ''
    let status = {
      \ 'desc': 'current status',
      \ 'type': self.statustype,
      \ 'state': "started",
    \ }

  " call go#statusline#Update(self.jobdir, status)
  endif
  let self.started_at = reltime()
endfunction

function! s:jobcallback(chan, msg) dict
  call add(self.messages, a:msg)
endfunction

function! s:jobexit_cb(job, exitval) dict
  let self.exit_status = a:exitval
  let self.exited = 1

  call self.show_status(a:job, a:exitval)

  if self.closed || has('nvim')
    call self.complete(a:job, self.exit_status, self.messages)
  endif
endfunction

function! s:jobclose_cb(ch) dict
   let self.closed = 1
   if self.exited
     let job = ch_getjob(a:ch)
     call self.complete(job, self.exit_status, self.messages)
   endif
endfunction

function! s:jobOptions(args)
    let cbs = {}
    let state = {
            \ 'winid': win_getid(winnr()),
            \ 'dir': getcwd(),
            \ 'jobdir': fnameescape(expand("%:p:h")),
            \ 'messages': [],
            \ 'bang': 0,
            \ 'for': "_job",
            \ 'exited': 0,
            \ 'exit_status': 0,
            \ 'closed': 0,
            \ 'errorformat': &errorformat,
            \ 'statustype' : ''
          \ }

    let cbs.cwd = state.jobdir

    if has_key(a:args, 'bang')
      let state.bang = a:args.bang
    endif

    if has_key(a:args, 'for')
      let state.for = a:args.for
    endif

    if has_key(a:args, 'statustype')
      let state.statustype = a:args.statustype
    endif

    if has_key(a:args, 'errorformat')
      let state.errorformat = a:args.errorformat
    endif

    function state.complete(job, exit_status, data)
      if has_key(self, 'custom_complete')
        let l:winid = win_getid(winnr())
        " Always set the active window to the window that was active when
        " the job wasstarted. Among other things, this makes sure that the
        " correct window's location list will be populated when the list type
        " is 'location' and the user has moved windows since starting the job.
        call win_gotoid(self.winid)
        call self.custom_complete(a:job, a:exit_status, a:data)
        call win_gotoid(l:winid)
      endif
      call self.show_errors(a:job, a:exit_status, a:data)
    endfunction

    function state.show_status(job, exit_status) dict
      if self.statustype ==  ''
        return
      endif

      " if go#config#EchoCommandInfo()
      "   let prefix =  '[' . self.statustype .  ']'
      "   if a:exit_status == 0
      "     echom prefix . "SUCCESS"
      "   else
      "     echom prefix . "FAIL"
      "   endif
      " endif
      let status = {
        \ 'desc': 'last status',
        \ 'type': self.statustype,
        \ 'state': "success" ,
      \}
   
      if a:exit_status
        let status.state = "failed" 
      endif

      if has_key(self, 'started_at')
        let elapsed_time = reltimestr(reltime(self.started_at))
        " strip whitespace
        let elapsed_time = substitute(elapsed_time, '^\s*\(.\{-}\)\s*$', '\1', '')
        let status.state .= printf(" (%ss)" , elapsed_time)
       endif
       " call go#statusline#Update(self.jobdir, status)
       echom status
     endfunction

    if has_key(a:args, 'complete')
      let state.custom_complete = a:args.complete
    endif

    " explicitly bind _start to state so that within it, self will
    " always refer to state. See :help Partial for more information.
    " _start is intended only for internal use and should not be
    " referenced outside of this file.
    let cbs._start = function('s:jobstart', [''], state)

    " explicitly bind callback to state so that within it, self will
    " always refer to state. See :help Partial for more information.
    let cbs.callback = function('s:jobcallback', [], state)

    " explicitly bind exit_cb to state so that within it, self will
    " always refer to state. See :help Partial for more information.
    let cbs.exit_cb = function('s:jobexit_cb', [], state)

    " explicitly bind close_cb to state so that within it, self will
    " always refer to state. See :help Partial for more information.
    let cbs.close_cb = function('s:jobclose_cb', [], state)

    function state.show_errors(job, exit_status, data)
      if self.for == '_'
        return
      endif

      let l:winid = win_getid(winnr()) 

      " Always set the active window to the window that was active when
      " the job was started. Among other things, this makes sure that
      " the correct window's location list will be populated when the
      " list type is 'location' and the user has moved windows since
      " starting the job.
      call win_gotoid(self.winid)
      let l:listtype = s:listType(self.for)
      if a:exit_status == 0
        call s:listClean(l:listtype)
        call win_gotoid(l:winid)
        return
      endif

      let l:listtype = s:listType(self.for)
      if len(a:data) == 0
        call s:listClean(l:listtype)
        call win_gotoid(l:winid)
        return
      endif

      let out = join(self.messages, " \n" )
      let l:cd = exists('*haslocaldir') && haslocaldir() ? 'lcd' : 'cd'
      try
        " parse the errors relative to self.jobdir 
        execute l:cd self.jobdir
        call s:listParseFormat(l:listtype, self.errorformat, out, self.for)
        let errors = s:listGet(l:listtype)
      finally
        execute l:cd fnameescape(self.dir)
      endtry

      if empty(errors)
        " failed to parse errors, output the original content
        echom self.dir . self.messages
        call win_gotoid(l:winid)
        return
      endif

      " only open the error window if user was still in the window from which
      " the job was started.
      if self.winid == l:winid
        call s:listWindow(l:listtype, len(errors))
      if self.bang
        call win_gotoid(l:winid)
      else
        call s:listJumpToFirst(l:listtype)
      endif
    endif
  endfunction

  return cbs
endfunction

function! s:jobWait(job) abort
  if has('nvim')
    call jobwait([a:job])
    return
  endif
  while job_status(a:job) is# 'run'
    sleep 50m
  endwhile
endfunction

function! s:jobStop(job) abort
  if has('nvim')
    call jobstop(a:job)
    return
  endif
  call job_stop(a:job)
  call s:jobWait(a:job)
  return
endfunction

function! s:jobStart(cmd, options)
  let l:cd = exists('*haslocaldir') && haslocaldir() ? 'lcd' : 'cd'
  let l:options = copy(a:options)

  if has('nvim')
    let l:options = s:neooptions(l:options)
  endif

  " Verify that the working directory for the job actually exists. Return
  " early if the directory does not exist. This helps avoid errors when
  " working with plugins that use virtual files that don't actually exist on
  " the file system.
  let l:filedir = expand("%:p:h")
  if has_key(l:options, 'cwd') && !isdirectory(l:options.cwd)
    return
  elseif !isdirectory(l:filedir)
    return
  endif

  let l:manualcd = 0
  if !has_key(l:options, 'cwd')
  " pre start
    let l:manualcd = 1
    let dir = getcwd()
    execute l:cd
    fnameescape(filedir)
  elseif !(has("patch-8.0.0902") || has('nvim'))
    let l:manualcd = 1
    let l:dir = l:options.cwd
    execute l:cd
    fnameescape(l:dir)
    call remove(l:options, 'cwd')
  endif

  if has_key(l:options, '_start')
    call l:options._start()
    " remove _start to play nicely with vim (when vim encounters an unexpected
    " job option it reports an "E475: invalid argument" error).
    unlet l:options._start
  endif

  " noblock was added in 8.1.350; remove it if it's not supported.
  if has_key(l:options, 'noblock') && (has('nvim') || !has("patch-8.1.350"))
    call remove(l:options, 'noblock')
  endif
  " if go#util#HasDebug('shell-commands')
  "   call go#util#EchoInfo('job command: ' . string(a:cmd))
  " endif

  if has('nvim')
    let l:input = []
    if has_key(a:options, 'in_io') && a:options.in_io ==# 'file' && !empty(a:options.in_name)
      let l:input = readfile(a:options.in_name, "b")
    endif

    let job = jobstart(a:cmd, l:options)
    if len(l:input) > 0
      call chansend(job, l:input)

      " close stdin to signal that no more bytes will be sent.
      call chanclose(job, 'stdin')
    endif
  else
    let l:cmd = a:cmd
    let job = job_start(l:cmd, l:options)
  endif
  
  if l:manualcd
  " post start
    execute l:cd 
    fnameescape(l:dir)
  endif

  return job
endfunction

function! s:stop() abort
  let l:res = s:call_jsonrpc('RPCServer.Detach', {'kill': v:true})

  if has_key(s:state, 'job')
    call s:jobWait(s:state['job'])

    " while waiting, the s:complete may have already removed job from s:state.
    if has_key(s:state, 'job')
      call remove(s:state, 'job')
    endif
  endif

  if has_key(s:state, 'ready')
    call remove(s:state, 'ready')
  endif

  if has_key(s:state, 'ch')
    call remove(s:state, 'ch')
  endif

  call s:clearState()
endfunction

function! Stop() abort
  " Remove all commands and add back the default commands.
  " for k in map(split(execute('command GoDebug'), "\n")[1:], 'matchstr(v:val, "^\\s*\\zs\\S\\+")')
  for k in ['Breakpoint', 'Continue', 'Next', 'Print', 'Restart', 'Set', 'Step', 'StepOut']
    let l:c = 'GoDebug' . k
    exe 'delcommand ' . l:c
  endfor
  command! -nargs=* GoDebugStart call Start(0, <f-args>)
  command! -nargs=* GoDebugTest  call Start(1, <f-args>)
  command! -nargs=? GoDebugBreakpoint call Breakpoint(<f-args>)

  " Remove all mappings.
  " for k in map(split(execute('map <Plug>(go-debug-'), "\n")[1:], 'matchstr(v:val, "^n\\s\\+\\zs\\S\\+")')
  for k in ['breakpoint', 'next', 'step', 'stepout', 'continue', 'stop', 'print'] 
    let l:p = '<Plug>(go-debug-' . k . ')'
    exe 'unmap' l:p
  endfor
  for k in ['b', 'n', 's', 'o', 'c', 'q', 'p']
    let l:m = '<buffer> <Leader>' . k
    exe 'nunmap' l:m
  endfor

  " Add back start and breakpoint
  nmap <Leader>d  :GoDebugStart<CR>
  nmap <Leader>b  :GoDebugBreakpoint<CR>

  call s:stop()

  let bufs = filter(map(range(1, winnr('$')), '[v:val,bufname(winbufnr(v:val))]'), 'v:val[1]=~"\.go$"')
  if len(bufs) > 0
    exe bufs[0][0] 'wincmd w'
  else
    wincmd p
  endif
  silent! exe bufwinnr(bufnr('__GODEBUG_STACKTRACE__')) 'wincmd c'
  silent! exe bufwinnr(bufnr('__GODEBUG_VARIABLES__')) 'wincmd c'
  silent! exe bufwinnr(bufnr('__GODEBUG_OUTPUT__')) 'wincmd c'

  if has('balloon_eval')
    let &noballooneval=s:ballooneval
    let &balloonexpr=s:balloonexpr
  endif

  augroup vim-go-debug
    autocmd!
  augroup END
  augroup! vim-go-debug
endfunction

function Help() abort
  echom '(b)reakpoint, (n)ext, (s)tep, step(o)ut, (c)ontinue, (q)uit, (p)rint'
endfunction

function! s:goto_file() abort
  let m = matchlist(getline('.'), ' - \(.*\):\([0-9]\+\)$')
  if m[1] == ''
    return
  endif
  let bufs = filter(map(range(1, winnr('$')), '[v:val,bufname(winbufnr(v:val))]'), 'v:val[1]=~"\.go$"')
  if len(bufs) == 0
    return
  endif
  exe bufs[0][0] 'wincmd w'
  let filename = m[1]
  let linenr = m[2]
  let oldfile = fnamemodify(expand('%'), ':p:gs!\\!/!')
  if oldfile != filename
    silent! exe 'edit' filename
  endif
  silent! exe 'norm!' linenr.'G'
  silent! normal! zvzz
endfunction

function! s:delete_expands()
  let nr = line('.')
  while 1
    let l = getline(nr+1)
    if empty(l) || l =~ '^\S'
      return
    endif
    silent! exe (nr+1) . 'd _'
  endwhile
  silent! exe 'norm!' nr.'G'
endfunction

function! s:expand_var() abort
  " Get name from struct line.
  let name = matchstr(getline('.'), '^[^:]\+\ze: [a-zA-Z0-9\.·]\+{\.\.\.}$')
  " Anonymous struct
  if name == ''
    let name = matchstr(getline('.'), '^[^:]\+\ze: struct {.\{-}}$')
  endif

  if name != ''
    setlocal modifiable
    let not_open = getline(line('.')+1) !~ '^ '
    let l = line('.')
    call s:delete_expands()

    if not_open
      call append(l, split(s:eval(name), "\n")[1:])
    endif
    silent! exe 'norm!' l.'G'
    setlocal nomodifiable
    return
  endif

  " Expand maps
  let m = matchlist(getline('.'), '^[^:]\+\ze: map.\{-}\[\(\d\+\)\]$')
  if len(m) > 0 && m[1] != ''
    setlocal modifiable
    let not_open = getline(line('.')+1) !~ '^ '
    let l = line('.')
    call s:delete_expands()
    if not_open
      " TODO: Not sure how to do this yet... Need to get keys of the map.
      " let vs = ''
      " for i in range(0, min([10, m[1]-1]))
      "   let vs .= ' ' . s:eval(printf("%s[%s]", m[0], ))
      " endfor
      " call append(l, split(vs, "\n"))
    endif

    silent! exe 'norm!' l.'G'
    setlocal nomodifiable
    return
  endif

  " Expand string.
  let m = matchlist(getline('.'), '^\([^:]\+\)\ze: \(string\)\[\([0-9]\+\)\]\(: .\{-}\)\?$')
  if len(m) > 0 && m[1] != ''
    setlocal modifiable
    let not_open = getline(line('.')+1) !~ '^ '
    let l = line('.')
    call s:delete_expands()

    if not_open
      let vs = ''
      for i in range(0, min([10, m[3]-1]))
        let vs .= ' ' . s:eval(m[1] . '[' . i . ']')
      endfor
      call append(l, split(vs, "\n"))
    endif

    silent! exe 'norm!' l.'G'
    setlocal nomodifiable
    return
  endif

  " Expand slice.
  let m = matchlist(getline('.'), '^\([^:]\+\)\ze: \(\[\]\w\{-}\)\[\([0-9]\+\)\]$')
  if len(m) > 0 && m[1] != ''
    setlocal modifiable
    let not_open = getline(line('.')+1) !~ '^ '
    let l = line('.')
    call s:delete_expands()

    if not_open
      let vs = ''
      for i in range(0, min([10, m[3]-1]))
        let vs .= ' ' . s:eval(m[1] . '[' . i . ']')
      endfor
      call append(l, split(vs, "\n"))
    endif
    silent! exe 'norm!' l.'G'
    setlocal nomodifiable
    return
  endif
endfunction

function! s:debugWindows() abort
  return get(g:, 'go_debug_windows', {
    \ 'stack': 'leftabove 20vnew',
    \ 'out':   'botright 10new',
    \ 'vars':  'leftabove 30vnew',
    \ }
  \ )
endfunction

function! s:start_cb() abort
  let l:winid = win_getid()
  silent! only!

  let winnum = bufwinnr(bufnr('__GODEBUG_STACKTRACE__'))
  if winnum != -1
    return
  endif

  let debugwindows = s:debugWindows()
  if has_key(debugwindows, "stack") && debugwindows['stack'] != ''
    exe 'silent ' . debugwindows['stack']
    silent file `='__GODEBUG_STACKTRACE__'`
    setlocal buftype=nofile bufhidden=wipe nomodified nobuflisted noswapfile nowrap nonumber nocursorline
    setlocal filetype=godebugstacktrace
    nmap <buffer> <cr> :<c-u>call <SID>goto_file()<cr>
    nmap <buffer> q <Plug>(go-debug-stop)
  endif

  if has_key(debugwindows, "out") && debugwindows['out'] != ''
    exe 'silent ' . debugwindows['out']
    silent file `='__GODEBUG_OUTPUT__'`
    setlocal buftype=nofile bufhidden=wipe nomodified nobuflisted noswapfile nowrap nonumber nocursorline
    setlocal filetype=godebugoutput
    nmap <buffer> q <Plug>(go-debug-stop)
  endif

  if has_key(debugwindows, "vars") && debugwindows['vars'] != ''
    exe 'silent ' . debugwindows['vars']
    silent file `='__GODEBUG_VARIABLES__'`
    setlocal buftype=nofile bufhidden=wipe nomodified nobuflisted noswapfile nowrap nonumber nocursorline
    setlocal filetype=godebugvariables
    call append(0, ["# Local Variables", "", "# Function Arguments"])
    nmap <buffer> <silent> <cr> :<c-u>call <SID>expand_var()<cr>
    nmap <buffer> q <Plug>(go-debug-stop)
  endif

  silent! delcommand GoDebugStart
  silent! delcommand GoDebugTest
  command! -nargs=0 GoDebugContinue   call Stack('continue')
  command! -nargs=0 GoDebugNext       call Stack('next')
  command! -nargs=0 GoDebugStep       call Stack('step')
  command! -nargs=0 GoDebugStepOut    call Stack('stepOut')
  command! -nargs=0 GoDebugRestart    call Restart()
  command! -nargs=0 GoDebugStop       call Stop()
  command! -nargs=* GoDebugSet        call Set(<f-args>)
  command! -nargs=1 GoDebugPrint      call Print(<q-args>)
  command! -nargs=0 GoDebugHelp       call Help()

  nnoremap <silent> <Plug>(go-debug-breakpoint) :<C-u>call Breakpoint()<CR>
  nnoremap <silent> <Plug>(go-debug-next)       :<C-u>call Stack('next')<CR>
  nnoremap <silent> <Plug>(go-debug-step)       :<C-u>call Stack('step')<CR>
  nnoremap <silent> <Plug>(go-debug-stepout)    :<C-u>call Stack('stepout')<CR>
  nnoremap <silent> <Plug>(go-debug-continue)   :<C-u>call Stack('continue')<CR>
  nnoremap <silent> <Plug>(go-debug-stop)       :<C-u>call Stop()<CR>
  nnoremap <silent> <Plug>(go-debug-print)      :<C-u>call Print(expand('<cword>'))<CR>
  nnoremap <silent> <Plug>(go-debug-help)       :<C-u>call Help()<CR>

  if has('balloon_eval')
    let s:balloonexpr=&balloonexpr
    let s:ballooneval=&ballooneval

    set balloonexpr=s:debugBalloonExpr()
    set ballooneval
  endif

  call win_gotoid(l:winid)

  augroup vim-go-debug
    autocmd! * <buffer>
    autocmd FileType go nmap <buffer> <Leader>c  <Plug>(go-debug-continue)
    autocmd FileType go nmap <buffer> <Leader>p  <Plug>(go-debug-print)
    autocmd FileType go nmap <buffer> <Leader>b  <Plug>(go-debug-breakpoint)
    autocmd FileType go nmap <buffer> <Leader>n  <Plug>(go-debug-next)
    autocmd FileType go nmap <buffer> <Leader>o  <Plug>(go-debug-stepout)
    autocmd FileType go nmap <buffer> <Leader>s  <Plug>(go-debug-step)
    autocmd FileType go nmap <buffer> <Leader>q  <Plug>(go-debug-stop)
    autocmd FileType go nmap <buffer> <Leader>h  <Plug>(go-debug-help)
  augroup END
  doautocmd vim-go-debug FileType go
endfunction

function! s:err_cb(ch, msg) abort
  if get(s:state, 'ready', 0) != 0
    call call('s:logger', ['ERR: ', a:ch, a:msg])
    return
  endif

  let s:state['message'] += [a:msg]
endfunction


function! s:debugAddress() abort
  return get(g:, 'go_debug_address', '127.0.0.1:8181')
endfunction

function! s:out_cb(ch, msg) abort
  if get(s:state, 'ready', 0) != 0
    call call('s:logger', ['OUT: ', a:ch, a:msg])
    return
  endif

  let s:state['message'] += [a:msg]

  if stridx(a:msg, s:debugAddress()) != -1
    if has('nvim')
      let s:state['data'] = []
      let l:state = {'databuf': ''}
      
      " explicitly bind callback to state so that within it, self will
      " always refer to state. See :help Partial for more information.
      let l:state.on_data = function('s:on_data', [], l:state)
      let l:ch = sockconnect('tcp', s:debugAddress(), {'on_data': l:state.on_data, 'state': l:state})
      if l:ch == 0
        echom "could not connect to debugger"
        call s:jobStop(s:state['job'])
        return
      endif
    else
      let l:ch = ch_open(s:debugAddress(), {'mode': 'raw', 'timeout': 20000})
      if ch_status(l:ch) !=# 'open'
        echom "could not connect to debugger"
        call jobStop(s:state['job'])
        return
      endif
    endif

    let s:state['ch'] = l:ch

    " After this block executes, Delve will be running with all the
    " breakpoints setup, so this callback doesn't have to run again; just log
    " future messages.
    let s:state['ready'] = 1

    " replace all the breakpoints set before delve started so that the ids won't overlap.
    let l:breakpoints = s:list_breakpoints()
    for l:bt in s:list_breakpoints()
      exe 'sign unplace '. l:bt.id
      call Breakpoint(l:bt.line, l:bt.file)
    endfor

    call s:start_cb()
  endif
endfunction

function! s:on_data(ch, data, event) dict abort
  let l:data = self.databuf
  for l:msg in a:data
    let l:data .= l:msg
  endfor

  try
    let l:res = json_decode(l:data)
    let s:state['data'] = add(s:state['data'], l:res)
    let self.databuf = ''
  catch
    " there isn't a complete message in databuf: buffer l:data and try
    " again when more data comes in.
    let self.databuf = l:data
  finally
  endtry
endfunction

function! s:autowrite() abort
  if &autowrite == 1 || &autowriteall == 1
    silent! wall
  else
    for l:nr in range(0, bufnr('$'))
      if buflisted(l:nr) && getbufvar(l:nr, '&modified')
        " Sleep one second to make sure people see the message. Otherwise it is
        " often immediacy overwritten by the async messages (which also  don't
        " invoke the "hit ENTER" prompt).
        echom '[No write since last change]'
        sleep 1
        return
      endif
    endfor
  endif
endfunction


" FromPath returns the import path of arg.
function! s:fromPath(arg) abort
  let l:cd = exists('*haslocaldir') && haslocaldir() ? 'lcd' : 'cd'
  let l:dir = getcwd()
  let l:path = a:arg
  if !isdirectory(l:path)
    let l:path = fnamemodify(l:path, ':h')
  endif
  execute l:cd fnameescape(l:path)
  let [l:out, l:err] = Exec(['go', 'list'])
  execute l:cd fnameescape(l:dir)
  if l:err != 0
    return -1
  endif
  let l:importpath = split(l:out, '\n')[0]
  " go list returns '_CURRENTDIRECTORY' if the directory is not inside GOPATH.
  " Check it and retun an error if that is the case
  if l:importpath[0] ==# '_'
    return -1
  endif
  return l:importpath
endfunction

function! s:debugLogOutput() abort
  return get(g:, 'go_debug_log_output', 'debugger, rpc')
endfunction


function! s:buildTags() abort
  return get(g:, 'go_build_tags', '')
endfunction
"
" Start the debug mode. The first argument is the package name to compile and
" debug, anything else will be passed to the running program.
function! Start(is_test, ...) abort
  call s:autowrite()

  " It's already running.
  if has_key(s:state, 'job')
    return s:state['job']
  endif

  let s:start_args = a:000

  if s:hasDebug('debugger-state')
    call s:setDebugDiag(s:state)
  endif

  let dlv = CheckBinPath("dlv")
  if empty(dlv)
    return
  endif

  try
    " remove start keybinding
    unmap <Leader>d
    if len(a:000) > 0
      let l:pkgname = a:1
      if l:pkgname[0] == '.'
        let l:pkgname = s:fromPath(l:pkgname)
      endif
    else
      let l:pkgname = s:fromPath(getcwd())
    endif

    if l:pkgname is -1
      echom 'could not determine package name'
      return
    endif

    " cd in to test directory; this is also what running "go test" does.
    if a:is_test
      " TODO(bc): Either remove this if it's ok to do so or else record it and
      " reset cwd after the job completes.
      lcd %:p:h
    endif

    let s:state.is_test = a:is_test

    let l:args = []
    if len(a:000) > 1
      let l:args = ['--'] + a:000[1:]
    endif

    let l:cmd = [
          \ dlv,
          \ (a:is_test ? 'test' : 'debug'),
          \ l:pkgname,
          \ '--output', tempname(),
          \ '--headless',
          \ '--api-version', '2',
          \ '--listen', s:debugAddress(),
    \]
    let l:debugLogOutput = s:debugLogOutput()
    if l:debugLogOutput != ''
      let cmd += ['--log', '--log-output', l:debugLogOutput]
    endif

    let l:buildtags = s:buildTags()
    if buildtags isnot ''
      let l:cmd += ['--build-flags', '--tags=' . buildtags]
    endif
    let l:cmd += l:args

    let s:state['message'] = []
    let l:opts = {
          \ 'for': 'GoDebug',
          \ 'statustype': 'debug',
          \ 'complete': function('s:complete'),
          \ }
    let l:opts = s:jobOptions(l:opts)
    let l:opts.out_cb = function('s:out_cb')
    let l:opts.err_cb = function('s:err_cb')
    let l:opts.stoponexit = 'kill'

    let s:state['job'] = s:jobStart(l:cmd, l:opts)
  catch
    echom v:exception
  endtry

  return s:state['job']
endfunction

" Translate a reflect kind constant to a human string.
function! s:reflect_kind(k)
  " Kind constants from Go's reflect package.
  return [
        \ 'Invalid Kind',
        \ 'Bool',
        \ 'Int',
        \ 'Int8',
        \ 'Int16',
        \ 'Int32',
        \ 'Int64',
        \ 'Uint',
        \ 'Uint8',
        \ 'Uint16',
        \ 'Uint32',
        \ 'Uint64',
        \ 'Uintptr',
        \ 'Float32',
        \ 'Float64',
        \ 'Complex64',
        \ 'Complex128',
        \ 'Array',
        \ 'Chan',
        \ 'Func',
        \ 'Interface',
        \ 'Map',
        \ 'Ptr',
        \ 'Slice',
        \ 'String',
        \ 'Struct',
        \ 'UnsafePointer',
  \ ][a:k]
endfunction

function! s:eval_tree(var, nest) abort
  if a:var.name =~ '^\~'
    return ''
  endif
  let nest = a:nest
  let v = ''
  let kind = s:reflect_kind(a:var.kind)
  if !empty(a:var.name)
    let v .= repeat(' ', nest) . a:var.name . ': '

    if kind == 'Bool'
      let v .= printf("%s\n", a:var.value)

    elseif kind == 'Struct'
      " Anonymous struct
      if a:var.type[:8] == 'struct { '
        let v .= printf("%s\n", a:var.type)
      else
        let v .= printf("%s{...}\n", a:var.type)
      endif

    elseif kind == 'String'
      let v .= printf("%s[%d]%s\n", a:var.type, a:var.len,
            \ len(a:var.value) > 0 ? ': ' . a:var.value : '')

    elseif kind == 'Slice' || kind == 'String' || kind == 'Map' || kind == 'Array'
      let v .= printf("%s[%d]\n", a:var.type, a:var.len)

    elseif kind == 'Chan' || kind == 'Func' || kind == 'Interface'
      let v .= printf("%s\n", a:var.type)

    elseif kind == 'Ptr'
      " TODO: We can do something more useful here.
      let v .= printf("%s\n", a:var.type)

    elseif kind == 'Complex64' || kind == 'Complex128'
      let v .= printf("%s%s\n", a:var.type, a:var.value)

    " Int, Float
    else
      let v .= printf("%s(%s)\n", a:var.type, a:var.value)
    endif
  else
    let nest -= 1
  endif

  if index(['Chan', 'Complex64', 'Complex128'], kind) == -1 && a:var.type != 'error'
    for c in a:var.children
      let v .= s:eval_tree(c, nest+1)
    endfor
  endif
  return v
endfunction

function! s:eval(arg) abort
  try
    let l:res = s:call_jsonrpc('RPCServer.State')
    let l:res = s:call_jsonrpc('RPCServer.Eval', {
          \ 'expr':  a:arg,
          \ 'scope': {'GoroutineID': l:res.result.State.currentThread.goroutineID}
      \ })
    return s:eval_tree(l:res.result.Variable, 0)
  catch
    echom v:exception
    return ''
  endtry
endfunction

function! s:debugBalloonExpr() abort
  silent! let l:v = s:eval(v:beval_text)
  return l:v
endfunction

function! s:debugPrint(arg) abort
  try
    echo substitute(s:eval(a:arg), "\n$", "", 0)
  catch
    echom v:exception
  endtry
endfunction

function! s:update_variables() abort
  " FollowPointers requests pointers to be automatically dereferenced.
  " MaxVariableRecurse is how far to recurse when evaluating nested types.
  " MaxStringLen is the maximum number of bytes read from a string
  " MaxArrayValues is the maximum number of elements read from an array, a slice or a map.
  " MaxStructFields is the maximum number of fields read from a struct, -1 will read all fields.
  let l:cfg = {
        \ 'scope': {'GoroutineID': s:groutineID()},
        \ 'cfg':   {'MaxStringLen': 20, 'MaxArrayValues': 20}
        \ }

  try
    let res = s:call_jsonrpc('RPCServer.ListLocalVars', l:cfg)
    let s:state['localVars'] = res.result['Variables']
  catch
    echom v:exception
  endtry

  try
    let res = s:call_jsonrpc('RPCServer.ListFunctionArgs', l:cfg)
    let s:state['functionArgs'] = res.result['Args']
  catch
    echom v:exception
  endtry

  call s:show_variables()
endfunction

function! Set(symbol, value) abort
  try
    let l:res = s:call_jsonrpc('RPCServer.State')
    call s:call_jsonrpc('RPCServer.Set', {
          \ 'symbol': a:symbol,
          \ 'value':  a:value,
          \ 'scope':  {'GoroutineID': l:res.result.State.currentThread.goroutineID}
    \ })
  catch
    echom v:exception
  endtry

  call s:update_variables()
endfunction

function! s:update_stacktrace() abort
  try
    let l:res = s:call_jsonrpc('RPCServer.Stacktrace', {'id': s:groutineID(), 'depth': 5})
    call s:show_stacktrace(l:res)
  catch
    echom v:exception
  endtry
endfunction

function! s:stack_cb(res) abort
  let s:stack_name = ''

  if empty(a:res) || !has_key(a:res, 'result')
    return
  endif
  call s:update_breakpoint(a:res)
  call s:update_stacktrace()
  call s:update_variables()
endfunction

" Send a command to change the cursor location to Delve.
"
" a:name must be one of continue, next, step, or stepOut.
function! Stack(name) abort
  let l:name = a:name

  " Run continue if the program hasn't started yet.
  if s:state.running is 0
    let s:state.running = 1
    let l:name = 'continue'
  endif

  " Add a breakpoint to the main.Main if the user didn't define any.
  if len(s:list_breakpoints()) is 0
    if Breakpoint() isnot 0
      let s:state.running = 0
      return
    endif
  endif

  try
    " TODO: document why this is needed.
    if l:name is# 'next' && get(s:, 'stack_name', '') is# 'next'
      call s:call_jsonrpc('RPCServer.CancelNext')
    endif
    let s:stack_name = l:name
    try
      let res =  s:call_jsonrpc('RPCServer.Command', {'name': l:name})
      call s:stack_cb(res)
    catch
      echom v:exception
      call s:clearState()
      call Restart()
    endtry
  catch
    echom v:exception
  endtry
endfunction

function! Restart() abort
  call s:autowrite()

  try
    call s:stop()

    let s:state = {
        \ 'rpcid': 1,
        \ 'running': 0,
        \ 'currentThread': {},
        \ 'localVars': {},
        \ 'functionArgs': {},
        \ 'message': [],
        \}

    call call('Start', s:start_args)
  catch
    echom v:exception
  endtry
endfunction

" Report if debugger mode is active.
function! s:isActive()
  return len(s:state['message']) > 0
endfunction

" Toggle breakpoint. Returns 0 on success and 1 on failure.
function! Breakpoint(...) abort
  let l:filename = fnamemodify(expand('%'), ':p:gs!\\!/!')
  let l:linenr = line('.')

  " Get line number from argument.
  if len(a:000) > 0
    let l:linenr = str2nr(a:1)
    if l:linenr is 0
      echom 'not a number: ' . a:1
      return 0
    endif
    if len(a:000) > 1
      let l:filename = a:2
    endif
  endif

  try
    " Check if we already have a breakpoint for this line.
    let l:found = {}
    for l:bt in s:list_breakpoints()
      if l:bt.file is# l:filename && l:bt.line is# l:linenr
        let l:found = l:bt
        break
      endif
    endfor

    " Remove breakpoint.
    if type(l:found) == v:t_dict && !empty(l:found)
      exe 'sign unplace '. l:found.id .' file=' . l:found.file
      if s:isActive()
        let res = s:call_jsonrpc('RPCServer.ClearBreakpoint', {'id': l:found.id})
      endif
    " Add breakpoint.
    else
      if s:isActive()
        let l:res = s:call_jsonrpc('RPCServer.CreateBreakpoint', {'Breakpoint': {'file': l:filename, 'line': l:linenr}})
        let l:bt = res.result.Breakpoint
        exe 'sign place '. l:bt.id .' line=' . l:bt.line . ' name=godebugbreakpoint file=' . l:bt.file
      else
        let l:id = len(s:list_breakpoints()) + 1
        exe 'sign place ' . l:id . ' line=' . l:linenr . ' name=godebugbreakpoint file=' . l:filename
      endif
    endif
  catch
    echom v:exception
    return 1
  endtry

  return 0
endfunction

function! s:list_breakpoints()
  " :sign place
  " --- Signs ---
  " Signs for a.go:
  "     line=15  id=2  name=godebugbreakpoint
  "     line=16  id=1  name=godebugbreakpoint
  " Signs for a_test.go:
  "     line=6  id=3  name=godebugbreakpoint

  let l:signs = []
  let l:file = ''
  for l:line in split(execute('sign place'), '\n')[1:]
    if l:line =~# '^Signs for '
      let l:file = l:line[10:-2]
      continue
    endif

    if l:line !~# 'name=godebugbreakpoint'
      continue
    endif

    let l:sign = matchlist(l:line, '\vline\=(\d+) +id\=(\d+)')
    call add(l:signs, {
          \ 'id': l:sign[2],
          \ 'file': fnamemodify(l:file, ':p'),
          \ 'line': str2nr(l:sign[1]),
    \ })
  endfor

  return l:signs
endfunction

sign define godebugbreakpoint text=> texthl=GoDebugBreakpoint
sign define godebugcurline    text== texthl=GoDebugCurrent    linehl=GoDebugCurrent

" restore Vi compatibility settings
let &cpo = s:cpo_save
unlet s:cpo_save

" vim: sw=2 ts=2 et
