
%if 0

RxCMDREN - RxDOS RENAME command

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


	global _Rename

	extern CheckFileClose
	extern CmndError_FileAlreadyExists
	extern DisplayErrorMessage
	extern DisplayLine
	extern PreProcessCmndLine
	extern BuildParsedFilenameArray
	extern CopyString

	extern BuildFullPathFirstFile
	extern BuildFullPathNextFile
	extern BuildFullPathClose
	extern CmndError_NoFilesFound


		; RENAME filenameA filenameB
		;
		; INP:	ss:di-> argument array
		;	ax = number of arguments in array
_Rename:
	entry
	def	ifAnyRenamed, 0
	def	findhandle, -1
	def	ptrname
	def	_argarray, di				; argument array

	defbytes	srcfile, sizeParsedFilename
	defbytes	destfile, sizeParsedFilename
	defbytes	finddata, sizeFINDDATA
	defbytes	_pathArg, sizeLFNPATH

	mov cx, 2
	mov dx, cx					; requires two arguments
	xor bx, bx
	call PreProcessCmndLine				; make sure arguments are ok
	ifc _renameError				; if error -->


		; make sure second argument contains no drive or path
	getarg di, __argarray
	mov cx, word [ sizeArgCmd + arglength + di ]
	mov si, word [ sizeArgCmd + argpointer + di ]	; second argument
	lea di, [ COMPAT_WORD _destfile + bp ]		; parsed destination buffer
	call BuildParsedFilenameArray

	cmp word [ _destfile + parsepathlength + bp ], byte 0
	ifnz _renameError				; second argument contains drive or path -->
	cmp word [ _destfile + parseptrfilename + bp ], byte 0
	ifz _renameError				; second argument contains no name -->


		; parse first argument
	getarg di, __argarray
	mov cx, word [ arglength + di ]
	mov si, word [ argpointer + di ]		; first argument
	lea di, [ COMPAT_WORD _srcfile + bp ]		; parsed source buffer
	call BuildParsedFilenameArray

	cmp word [ _srcfile + parseptrfilename + bp ], byte 0
	ifz _renameError				; if no name, then we have an error -->


		; simple case (no wild card case)
	mov ax, word [ _srcfile + parsewildcharflag + bp ]
%if 1
	add ax, word [ _destfile + parsewildcharflag + bp ]
%else
	or ax, word [ _destfile + parsewildcharflag + bp ]
%endif
	jnz _rename_14					; wild chars in either filename -->

	getarg di, __argarray
	mov dx, word [ argpointer + di ]		; first argument
	mov di, word [ argpointer + sizeArgCmd + di ]	; second argument
	Int21 LFNRenameFile				; rename file
	ifc _renameError				; if error -->

	Return


		; try to locate file(s)
_rename_14:
	getarg di, __argarray
	mov si, word [ argpointer + di ]		; point to source filename arg

	lea di, [ _finddata + bp ]			; finddata workspace
	lea dx, [ __pathArg + bp ]			; expanded path (sizeLFNPATH)
	fileAttrib ATTR_NORMAL
	call BuildFullPathFirstFile			; filename found for arg ?
	storarg _findHandle, bx				; save find handle
	storarg _ptrName, dx				; present name to next
	jc _rename_54					; no more -->

_rename_18:
	mov si, word [ _destfile + parseptrfilename + bp ]
	lea di, [ _finddata + findDataLongFilename + bp ]
	cmp byte [ di ], 00
	jnz _rename_22

	push si
	push di
	lea si, [ COMPAT_WORD _finddata + findDataShortFilename + bp ]
	call CopyString					; overwrite long name if missing
	pop di
	pop si

_rename_22:
	mov al, byte [ si ]
	or al, al					; end of name ?
	jz _rename_36					; not yet -->
	cmp al, '*'					; asterisk ?
	jz _rename_36					; cause rest of compare to look like ?'s

	inc si
	cmp al, '?'					; this char a '?' ?
	jz _rename_24					; yes, skip -->
	mov byte [ di ], al				; else store template char

_rename_24:
	inc di
	jmp short _rename_22
	

		; execute rename
_rename_36:
	storarg _ifAnyRenamed, True

	lea dx, [ __pathArg + bp ]			; expanded path (sizeLFNPATH)
	lea di, [ _finddata + findDataLongFilename + bp ]
	Int21 LFNRenameFile				; rename file
	jc _renameError					; if error -->

	getarg bx, _findHandle
	getarg si, _ptrName				; expanded path (sizeLFNPATH)
	lea di, [ _finddata + bp ]			; name area
	call BuildFullPathNextFile			; filename found for arg ?
	jnc _rename_18					; continue deleting -->

	getarg bx, _findHandle
	call BuildFullPathClose


		; no more files
_rename_54:
	cmp word [ _ifAnyRenamed + bp ], byte 0		; any files renamed ?
	jnz _rename_56					; yes -->

	mov dx, CmndError_NoFilesFound
	call DisplayErrorMessage

_rename_56:
	Return


		; error in rename command
_renameError:
	mov dx, CmndError_FileAlreadyExists
	call DisplayErrorMessage
	Return

