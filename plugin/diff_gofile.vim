" Copyright (c) 2007
" Vladimir Marek <vlmarek@volny.cz>
"
" We grant permission to use, copy modify, distribute, and sell this
" software for any purpose without fee, provided that the above copyright
" notice and this text are not removed. We make no guarantee about the
" suitability of this software for any purpose and we are not liable
" for any damages resulting from its use. Further, we are under no
" obligation to maintain or extend this software. It is provided on an
" "as is" basis without any expressed or implied warranty.

" Functions FindOrCreateBuffer and EqualFilePaths were takend from a.vim 2.16,
" http://www.vim.org/scripts/script.php?script_id=31. Thank you :)

" Description:
" If you are editing diff file and you want to jump quickly to corresponding
" source files, function DiffGoFile does that. Place cursor on the spot in diff
" file which interests you, call DiffGoFile and you will be presented with the
" source file exactly at the place you were looking at. Currently only unified
" diff is supported, but the script has framework for adding more types.

" Installation:
" Copy script to your plugins directory

" Invocation:
" Place cursor on the line you are interested in and
" :call DiffGoFile('X')
" Where X is one of: n - open in New window
"                    v - open in Vertical split
"                    h - open in Horizontal split
"                    t - open in new Tab

" Configuration:
" You may wish to setup a hotkey, I'm using CTRL-] (:tag) for example
"
" autocmd FileType diff nnoremap <buffer> <C-]> :call DiffGoFile('n')<CR>

" Possible TODOs:
" * Support other diff types (normal, context)
"   see http://en.wikipedia.org/wiki/Diff
"   - to add new diff type, copy ParseUnified function to new one, and update
"     s:parse_engines list at the end of this file
"
" Version: 2


if exists("loaded_diffgofile")
    finish
endif
let loaded_diffgofile = 1


" Function : DiffGoFile
" Purpose  : Find spot in file which corresponds to cursor in unified diff
" Args     : How to split the window. Possibilities are
"          : ('n', 'v', 'h', 't', 'n!', 'v!', 'h!', 't!')
"          : (No split, Vertical, Horizonal, Tab).
"          : adding '!' will call ':split !'
" Returns  : -
" Author   : Vladimir Marek <vlmarek@volny.cz>
" History  : Support for Mercurial diffs (a/file, b/file)
"          : Support for splitting horizontally/vertically/in tab
if !(exists("*s:DiffGoFile"))
function DiffGoFile(doSplit)
	let l:pos = <SID>SaveCursorPositon()

	for l:Engine in s:parse_engines
		call <SID>RestoreCursorPosition(l:pos)
		let l:result = l:Engine(l:pos)
		if type(l:result) == type([])
			break
		endif
	endfor

	if type(l:result) != type([])
		echoerr "Unknown diff format"
		return
	endif
	
	" Shouldn't this hack be rather moved to unified diff engine ? Can HG
	" create other than unified diffs ?
	if !filereadable(l:result[0])
		" Mercurial diff ?
		let l:result[0]=substitute(l:result[0], '^b/', '', '')
	endif

	if !filereadable(l:result[0])
		echoerr "Can't find file ".l:result[0]
		return
	endif

	" restore position in diff window
	call <SID>RestoreCursorPosition (l:pos)
	call <SID>FindOrCreateBuffer(l:result[0], a:doSplit, 1)
	call <SID>RestoreCursorPosition (l:result[1:])
endfunction
endif


" Function : ParseUnified (PRIVATE)
" Purpose  : Open file at location corresponding to current position in diff
"            file. This function understands unified diff format
" Args     : Current cursor position in diff buffer; list with three elements
"            * topmost visible line
"            * current line
"            * current column
" Returns  : If unsuccessful, returns anything than array
"            If successful, returns array of four elements
"            * Filename
"            * Topmost line which should be displayed in the filename
"            * Line with cursor displayed in the filename
"            * Column with cursor displayed in the filename
" Author   : Vladimir Marek <vlmarek@volny.cz>
" History  : 
function <SID>ParseUnified (pos)
	let l:current_top_line = a:pos[0]
	let l:current_line = a:pos[1]
	let l:current_column  = a:pos[2]

	try
		?^@@
	catch /Pattern not found/
		" echoerr "Does not look like unified diff - can't find ^@@ (".v:throwpoint.")"
		return
	endtry

	let l:at_line=line(".")
	let l:from_line=substitute(getline(l:at_line), '.*+\(\d*\).*', '\1', '')

	let g:cnt=0
	silent exe "let g:cnt=0 | ".l:at_line.",".l:current_line."g/^-/let g:cnt=g:cnt+1"

	try
		?^+++
	catch /Pattern not found/
		" echoerr "Does not look like unified diff - can't find ^+++ (".v:throwpoint.")"
		return
	endtry

	let l:filename=substitute(getline(line(".")), '+++ \(\f*\).*', '\1', '')

	let l:set_line=l:from_line+l:current_line-l:at_line-g:cnt-1
	let l:set_top_line=l:set_line-l:current_line+l:current_top_line

	return [ l:filename, l:set_top_line, l:set_line, l:current_column ]
endfunction


" Function : SaveCursorPositon (PRIVATE)
" Purpose  : Returns current window and cursor positon
" Args     : nothing
" Returns  : List with three elements
"            * topmost visible line
"            * current line
"            * current column
" Author   : Vladimir Marek <vlmarek@volny.cz>
" History  : 
function <SID>SaveCursorPositon()
	return [ line("w0"), line("."), virtcol(".") ]
endfunction


" Function : RestoreCursorPosition (PRIVATE)
" Purpose  : Tries to restore window position from values returned by SaveCursorPositon
" Args     : List with three elements
"            * topmost visible line
"            * current line
"            * current column
" Returns  : nothing
" Author   : Vladimir Marek <vlmarek@volny.cz>
" History  : 
function <SID>RestoreCursorPosition (position)
	exe "norm! ".a:position[0]."G0z\<CR>"
	exe "norm! ".a:position[1]."G0".a:position[2]."\<bar>"
endfunction


" Function : FindOrCreateBuffer (PRIVATE)
" Purpose  : searches the buffer list (:ls) for the specified filename. If
"            found, checks the window list for the buffer. If the buffer is in
"            an already open window, it switches to the window. If the buffer
"            was not in a window, it switches to that buffer. If the buffer did
"            not exist, it creates it.
" Args     : filename (IN) -- the name of the file
"            doSplit (IN) -- indicates whether the window should be split
"                            ("v", "h", "n", "v!", "h!", "n!", "t", "t!") 
"            findSimilar (IN) -- indicate weather existing buffers should be
"                                prefered
" Returns  : nothing
" Author   : Michael Sharpe <feline@irendi.com>
" History  : + bufname() was not working very well with the possibly strange
"            paths that can abound with the search path so updated this
"            slightly.  -- Bindu
"            + updated window switching code to make it more efficient -- Bindu
"            Allow ! to be applied to buffer/split/editing commands for more
"            vim/vi like consistency
"            + implemented fix from Matt Perry
function! <SID>FindOrCreateBuffer(fileName, doSplit, findSimilar)
  " Check to see if the buffer is already open before re-opening it.
  let FILENAME = a:fileName
  let bufNr = -1
  let lastBuffer = bufnr("$")
  let i = 1
  if (a:findSimilar) 
     while i <= lastBuffer
       if <SID>EqualFilePaths(expand("#".i.":p"), a:fileName)
         let bufNr = i
         break
       endif
       let i = i + 1
     endwhile

     if (bufNr == -1)
        let bufName = bufname(a:fileName)
        let bufFilename = fnamemodify(a:fileName,":t")

        if (bufName == "")
           let bufName = bufname(bufFilename)
        endif

        if (bufName != "")
           let tail = fnamemodify(bufName, ":t")
           if (tail != bufFilename)
              let bufName = ""
           endif
        endif
        if (bufName != "")
           let bufNr = bufnr(bufName)
           let FILENAME = bufName
        endif
     endif
  endif

  let splitType = a:doSplit[0]
  let bang = a:doSplit[1]
  if (bufNr == -1)
     " Buffer did not exist....create it
     let v:errmsg=""
     if (splitType == "h")
        silent! execute ":split".bang." " . FILENAME
     elseif (splitType == "v")
        silent! execute ":vsplit".bang." " . FILENAME
     elseif (splitType == "t")
        silent! execute ":tab split".bang." " . FILENAME
     else
        silent! execute ":e".bang." " . FILENAME
     endif
     if (v:errmsg != "")
        echo v:errmsg
     endif
  else

     " Find the correct tab corresponding to the existing buffer
     let tabNr = -1
     " iterate tab pages
     for i in range(tabpagenr('$'))
        " get the list of buffers in the tab
        let tabList =  tabpagebuflist(i + 1)
        let idx = 0
        " iterate each buffer in the list
        while idx < len(tabList)
           " if it matches the buffer we are looking for...
           if (tabList[idx] == bufNr)
              " ... save the number
              let tabNr = i + 1
              break
           endif
           let idx = idx + 1
        endwhile
        if (tabNr != -1)
           break
        endif
     endfor
     " switch the the tab containing the buffer
     if (tabNr != -1)
        execute "tabn ".tabNr
     endif

     " Buffer was already open......check to see if it is in a window
     let bufWindow = bufwinnr(bufNr)
     if (bufWindow == -1) 
        " Buffer was not in a window so open one
        let v:errmsg=""
        if (splitType == "h")
           silent! execute ":sbuffer".bang." " . FILENAME
        elseif (splitType == "v")
           silent! execute ":vert sbuffer " . FILENAME
        elseif (splitType == "t")
           silent! execute ":tab sbuffer " . FILENAME
        else
           silent! execute ":buffer".bang." " . FILENAME
        endif
        if (v:errmsg != "")
           echo v:errmsg
        endif
     else
        " Buffer is already in a window so switch to the window
        execute bufWindow."wincmd w"
        if (bufWindow != winnr()) 
           " something wierd happened...open the buffer
           let v:errmsg=""
           if (splitType == "h")
              silent! execute ":split".bang." " . FILENAME
           elseif (splitType == "v")
              silent! execute ":vsplit".bang." " . FILENAME
           elseif (splitType == "t")
              silent! execute ":tab split".bang." " . FILENAME
           else
              silent! execute ":e".bang." " . FILENAME
           endif
           if (v:errmsg != "")
              echo v:errmsg
           endif
        endif
     endif
  endif
endfunction


" Function : EqualFilePaths (PRIVATE)
" Purpose  : Compares two paths. Do simple string comparison anywhere but on
"            Windows. On Windows take into account that file paths could differ
"            in usage of separators and the fact that case does not matter.
"            "c:\WINDOWS" is the same path as "c:/windows". has("win32unix") Vim
"            version does not count as one having Windows path rules.
" Args     : path1 (IN) -- first path
"            path2 (IN) -- second path
" Returns  : 1 if path1 is equal to path2, 0 otherwise.
" Author   : Ilya Bobir <ilya@po4ta.com>
function! <SID>EqualFilePaths(path1, path2)
  if has("win16") || has("win32") || has("win64") || has("win95")
    return substitute(a:path1, "\/", "\\", "g") ==? substitute(a:path2, "\/", "\\", "g")
  else
    return a:path1 == a:path2
  endif
endfunction

" List of functions which are executed one by one to find the correct diff
" parser. First one who returns success is used
let s:parse_engines = [ function("<SID>ParseUnified") ]
