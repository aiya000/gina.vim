let s:String = vital#gina#import('Data.String')

let s:SCHEME = gina#command#scheme(expand('<sfile>'))


function! gina#command#log#call(range, args, mods) abort
  let git = gina#core#get_or_fail()
  let args = s:build_args(git, a:args)
  let bufname = gina#core#buffer#bufname(git, 'log', {
        \ 'path': args.params.path,
        \})
  call gina#core#buffer#open(bufname, {
        \ 'mods': 'keepalt ' . a:mods,
        \ 'group': args.params.group,
        \ 'opener': args.params.opener,
        \ 'cmdarg': args.params.cmdarg,
        \ 'callback': {
        \   'fn': function('s:init'),
        \   'args': [args],
        \ }
        \})
endfunction


" Private --------------------------------------------------------------------
function! s:build_args(git, args) abort
  let args = a:args.clone()
  let args.params.group = args.pop('--group', 'short')
  let args.params.opener = args.pop('--opener', &previewheight . 'split')

  call args.set('--color', 'always')
  call args.set('--graph', 1)
  call args.set('--pretty', "format:\e[32m%h\e[m - %s \e[33;1m%cr\e[m \e[35;1m<%an>\e[m\e[36;1m%d\e[m")
  call gina#core#args#extend_path(a:git, args, args.pop(1, v:null))
  if args.params.path isnot# v:null
    call args.residual([args.params.path] + args.residual())
  endif
  return args.lock()
endfunction

function! s:init(args) abort
  call gina#core#meta#set('args', a:args)

  if exists('b:gina_initialized')
    return
  endif
  let b:gina_initialized = 1

  setlocal buftype=nofile
  setlocal bufhidden=wipe
  setlocal noswapfile
  setlocal nomodifiable

  " Attach modules
  call gina#core#anchor#attach()
  call gina#action#attach(function('s:get_candidates'))
  call gina#action#include('browse')
  call gina#action#include('changes')
  call gina#action#include('commit')
  call gina#action#include('compare')
  call gina#action#include('diff')
  call gina#action#include('edit')
  call gina#action#include('show')

  augroup gina_internal_command
    autocmd! * <buffer>
    autocmd BufReadCmd <buffer> call s:BufReadCmd()
  augroup END
endfunction

function! s:BufReadCmd() abort
  let git = gina#core#get_or_fail()
  let args = gina#core#meta#get_or_fail('args')
  let pipe = gina#process#pipe#stream()
  let pipe.writer = gina#core#writer#new(extend(
        \ gina#process#pipe#stream_writer(),
        \ s:writer
        \))
  call gina#core#buffer#assign_cmdarg()
  call gina#process#open(git, args, pipe)
  setlocal filetype=gina-log
endfunction

function! s:get_candidates(fline, lline) abort
  let git = gina#core#get_or_fail()
  let path = gina#core#buffer#param('%', 'path', v:null)
  let candidates = map(
        \ filter(getline(a:fline, a:lline), '!empty(v:val)'),
        \ 's:parse_record(path, v:val)'
        \)
  return candidates
endfunction

function! s:parse_record(path, record) abort
  let record = s:String.remove_ansi_sequences(a:record)
  let rev = matchstr(record, '[a-z0-9]\+')
  let candidate = {
        \ 'word': record,
        \ 'abbr': a:record,
        \ 'path': a:path,
        \ 'rev': rev,
        \}
  return candidate
endfunction


" Writer ---------------------------------------------------------------------
let s:writer_super = gina#process#pipe#stream_writer()
let s:writer = {}

function! s:writer.on_stop() abort
  call call(s:writer_super.on_stop, [], self)
  call gina#core#emitter#emit('command:called', s:SCHEME)
endfunction


" Config ---------------------------------------------------------------------
call gina#config(expand('<sfile>'), {
      \ 'use_default_aliases': 1,
      \ 'use_default_mappings': 1,
      \})
