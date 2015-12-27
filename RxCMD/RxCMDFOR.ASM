
%if 0

RxCMDFOR - RxCMD FOR command

This product is distributed AS IS and contains no warranty
whatsoever, including warranty of merchantability or
fitness for a particular purpose.

Copyright (C) 1990-1999 Mike Podanoffsky

This is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License, see
the file LICENSE.TXT.

%endif

	cpu 8086

	segment RXCMD align=16 class=RXCMD use16 public start=100h
	segment RXCMD

%include "RXDMACRO.MAC"
%include "RXDSTRUC.MAC"
%include "RXCSTRUC.MAC"


	global _For

	extern CheckOptOneArg
	extern CountArgs
	extern CmndLookup
	extern CmndError_SyntaxError
	extern CRLF
	extern DisplayErrorMessage
	extern DisplayLine
	extern DisplayPrompt
	extern CopyString
	extern ReplaceForVariables
	extern _CommandParser
	extern CheckFileClose

	extern RxDOS_ForArgs
	extern _lowerCaseString

	extern _computeLength
	extern _Seeif_WildCharacter


		; FOR %var IN (set) DO command
		;
		; Replace %var in command.
_For:
	entry
	def	_argarray, di
	def	_beginrepeatarg
	def	_endrepeatarg
	def	_cmdline

	def	letter
	def	length
	def	WildChars
	def	filehandle, -1

	defbytes	commandLine, 128
	defbytes	replacement, 128
	defbytes	finddata, sizeFINDDATA

		; get variable arg letter
	call CountArgs					; must have min of 8 args
	cmp ax, 8					; min args 
%if 1
	jge _For_08					; if at leats 8 -->
%else
	jae _For_08					; if at least 8 -->
%endif
	jmp _ForError					; else if less, syntax error -->

_For_08:
	mov si, word [ forVarIdent + di ]		; point to arg
	cmp byte [ si ], '%'				; is first argument a % variable ?
	ifnz _ForError					; if not, then syntax error -->

	mov al, byte [ si + 1 ]				; get letter
%if 1
	_lowerCase al
%else
	call lowercase
%endif
	cbw
	storarg _letter, ax

		; check for 'in' argument
	mov si, word [ forInArg + argpointer + di ]	; point to next argument
	mov cx, word [ forInArg + arglength + di ]	; get argument length
	mov di, RxDOS_ForArgs
	call CmndLookup					; lookup command
	ifc _ForError					; if not, then syntax error -->

	cmp bx, _IN					; 'in' returns a zero
	ifnz _ForError					; if not 'in', then syntax error -->

		; check for '(' argument
	getarg di, __argarray
	add di, forInStartParen + sizeArgCmd
	mov si, word [ argpointer - sizeArgCmd + di ]
	cmp byte [ si ], '('				; is argument a '(' ?
	ifnz _ForError					; if not, then syntax error -->

	storarg __beginrepeatarg, di			; di points to an argument

		; search for ') do' ...
_ForSearchForParen:
	storarg __endrepeatArg, di			; end repeat arg

	add di, sizeArgCmd
	mov si, word [ argpointer - sizeArgCmd + di ]
	or si, si					; end of arguments ?
	ifz _ForError					; if it is, then syntax error -->

	cmp byte [ si ], ')'				; is argument a ')' ?
	jnz _ForSearchForParen				; keep looking -->

		; search for last ) in case ))) ...
_ForSearchForDoLastParen:
	add di, sizeArgCmd
	mov si, word [ argpointer - sizeArgCmd + di ]
	or si, si					; end of arguments ?
	ifz _ForError					; if it is, then syntax error -->

	cmp byte [ si ], ')'				; is arg another ')' ?
	jz _ForSearchForDoLastParen			; keep looking -->

		; test for do argument
_ForSearchForDo:
	push di
	mov si, word [ argpointer - sizeArgCmd + di ]
	mov di, RxDOS_ForArgs
	call CmndLookup					; lookup command
	pop di						; restore arg pointer
	ifc _ForError					; if not, then syntax error -->

	cmp bx, _DO					; 'do' returns a 1
	ifnz _ForError					; if not, then syntax error -->

	storarg __cmdline, di				; where command line is
	mov si, word [ argpointer + di ]
	or si, si					; end of args ?
	ifz _ForError					; if not, then syntax error -->

		; sequentially walk through each argument
_ForNext:
	getarg bx, __beginrepeatarg			; point to argument list
	cmp bx, word [ __endrepeatArg + bp ]		; end repeat argument ?
	ifz _ForReturn					; if at end, exit -->

	storarg _WildChars, 0
	mov si, word [ argpointer + bx ]
	mov cx, word [ arglength + bx ]
	storarg _length, cx				; save length

	call _Seeif_WildCharacter			; see if wild characters in name.
	jc _ForNext_30					; if no -->

	lea di, [ _replacement + bp ]			; where to copy
	repz movsb					; copy argument
	xor ax, ax					; null terminate
	stosb						; null terminate
	storarg _WildChars, -1				; wild characters used.

	fileAttrib ATTR_NORMAL
	mov si, FINDDATA_MSDOSDATEFORMAT
	lea dx, [ _replacement + bp ]			; search for argument
	lea di, [ _finddata + bp ]
	Int21 LFNFindFirstFile				; any found ?
	jc _ForNext_36					; if none -->

	storarg _filehandle, ax				; search next handle

		; create replacement variable
_ForNext_14:
	lea si, [ _finddata + findFileName + bp ]
	lea di, [ _replacement + bp ]			; search for argument
	call CopyString					; get command line

		; build command line to execute
_ForNext_30:
	getarg di, __cmdline				; -> argument array where command line begins
	mov si, word [ argpointer + di ]		; -> text
	lea di, [ _commandLine + 1 + bp ]
	call CopyString					; get command line

	mov al, byte [ _letter + bp ]
	lea bx, [ _replacement + bp ]
	lea si, [ _commandLine + 1 + bp ]
	call ReplaceForVariables			; replace variable letter

	call DisplayPrompt				; display prompt

	lea dx, [ _commandLine + 1 + bp ]
	call DisplayLine				; echo line
	call CRLF

	lea si, [ _commandLine + bp ]
	mov byte [ si ], 128
	call _CommandParser				; reparse remainder of line

	cmp word [ _WildChars + bp ], byte 0		; wild character search ?
	jz _ForNext_36					; no, skip to next arg in set -->

	getarg bx, _filehandle
	lea di, [ _finddata + bp ]
	mov si, FINDDATA_MSDOSDATEFORMAT
	Int21 LFNFindNextFile				; search for next matching file
	jnc _ForNext_14					; continue -->

		; get next argument
_ForNext_36:
	getarg bx, _filehandle				; search next handle
	call CheckFileClose

	getarg di, __beginrepeatarg			; get current pointer to arg array
	mov dx, word [ argpointer + di ]		; get current reference
	add dx, word [ _length + bp ]			; offset to past current arg
	sub di, sizeArgCmd

_ForNext_38:
	add di, sizeArgCmd
	mov si, word [ argpointer + di ]		; get current reference
	cmp si, dx					; beyond or equal to current ?
	jc _ForNext_38					; not yet -->

	storarg __beginrepeatarg, di			; remember reference
	jmp _ForNext

		; error
_ForError:
	mov dx, CmndError_SyntaxError
	call DisplayErrorMessage

		; return
_ForReturn:
	Return
