
%if 0

RxCMDDIR - RxCMD DIR command

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


	global _Dir
	global _makePath
	global BuildParsedFilenameArray

	extern CheckOptOneArg
	extern CmndError_InvalidDrive
	extern CmndError_NoFilesFound
	extern CRLF
	extern DisplayLine
	extern DisplayErrorMessage
	extern PreProcessCmndLine
	extern RxDOS_AllFiles
	extern RxDOS_AllExtensions
	extern setPagingMode
	extern _AppendPathName
	extern CopyString
	extern CheckFileClose
	extern CheckFile

	extern _mul32
	extern _div32

	extern _DirAttribSwitch
	extern _DirBareSwitch
	extern _DirLowerCaseSwitch
	extern _DirOrderSwitch
	extern _DirPauseSwitch
	extern _DirSubDirSwitch
	extern _DirSwitches
	extern _DirWideSwitch
	extern _Dir_DirectoryOf
	extern _Dir_DirEntry
	extern _Dir_FileEntry
	extern _Dir_Files_Summary
	extern _Dir_Files_MBSummary
	extern _Dir_NoVolumeLabel
	extern _Dir_VolumeLabel
	extern _Dir_VolumeSerialNumber

	extern _lowerCaseString
	extern _endofString
	extern _sprintf
	extern returnVolumeName


		; File time to ASCII (USA format)
		;
		; INP:	ax = time value
		;	di-> buffer for ASCII time
_dirTimeToAscii:

	push di

	push ax
	mov ch, 'a'
	mov cl, 11				; ch = 0
	shr ax, cl				; hours
	cmp ax, 13				; 1 pm or greater ?
	jc _dirTimeToAscii_08			; no -->

	sub ax, 12				; 1 pm or greater
	mov ch, 'p'				; set pm flag

_dirTimeToAscii_08:
	mov cl, 10
	div cl
	or ax, "00"				; convert to ASCII
	stosw

	mov al, ':'
	stosb

	pop ax
	mov cl, 5
	shr ax, cl				; minutes
	and ax, 00111111b			; mask off hours

	mov cl, 10
	div cl
	or ax, "00"
	stosw

	xor ah, ah
	mov al, ch
	stosw

	pop di
	cmp byte [ di ], '0'
	jnz _dirTimeToAscii_12
	mov byte [ di ], ' '

_dirTimeToAscii_12:
	retn


		; File date to ASCII (USA format)
		;
		; INP:	ax = date value
		;	di = buffer for ASCII date
_dirDateToAscii:

	push di
	push ax
	mov cl,	5
	shr ax, cl				; Month
	and ax, 00001111b			; mask off year

	mov cl, 10
	div cl
	or ax, "00"				; conv to ascii
	stosw

	mov al, '-'
	stosb

	pop ax
	push ax
	and ax, 00011111b			; mask off everything but day

	mov cl, 10
	div cl
	or ax, "00"				; conv to ascii
	stosw

	mov al, '-'
	stosb

	pop ax
	mov cl,	9
	shr ax, cl				; Year
	and ax, 01111111b			; mask
	add ax, 80				; 80 plus
	cmp ax, 100				; past year 2000 ?
	jc _dirDateToAscii_08			; no need to adjust -->

	sub ax, 100				; 2000 plus

_dirDateToAscii_08:
	mov cl, 10
	div cl
	or ax, "00"				; conv to ascii
	stosw

	xor al, al
	stosb

	pop di
	cmp byte [ di ], '0'
	jnz _dirDateToAscii_12
	mov byte [ di ], ' '

_dirDateToAscii_12:
	retn


		; Make path
		;
		; OUT:	si-> parsed filename
		;	di-> filename to build
_makePath:

	push si
	push di
	mov bx, si
	mov byte [ di ], 00

		; insert drive
	mov ax, word [ parsedrive + bx ]
	add ax, "A:"
	mov word [ di ], ax				; set drive

		; insert path
_makePath_08:
	; mov si, word [ parseptrpath + bx ]
	or si, si					; path available ?
	jz _makePath_16					; no -->

	call CopyString					; copy path to output

		; insert filename
_makePath_16:
	mov si, word [ parseptrfilename + bx ]
	or si, si					; filename available ?
	jz _makePath_32					; no -->

	mov al, '\'
	stosb
	call CopyString					; copy filename to output

		; insert extension
_makePath_24:
	mov si, word [ parseptrextension + bx ]
	or si, si					; extension available ?
	jz _makePath_32					; no -->

	mov al, '.'
	stosb
	call CopyString					; copy filename to output

		; return
_makePath_32:
	pop di
	pop si
	retn


		; Show directory contents
		;
		; INP:	ss:di->	argument array
		;	ax = number of arguments in array
_Dir:
	entry
	xor ax, ax
	def	currdisk
	def	maxdisk
	def	filesread, ax
	def	dirhandle, -1
	def	extensionFlag
	def	_argarray, di				; argument array
	def	summaryline
	def	freespaceFraction
	ddef	freespace
	ddef	totalfilespace, ax, ax

	defbytes	asciiFileTime, 20
	defbytes	asciiFileDate, 20
	defbytes	pathname, sizeLFNPATH		; search pathname
	defbytes	filename, sizeLFNPATH		; search filename
	defbytes	parsedfilename, sizeParsedFilename
	defbytes	finddata, sizeFINDDATA
	defbytes	printbuffer, 1400
	defbytes	extendedfreespace, sizeEXTENDEDFREESPACE

	xor ax, ax
	mov word [ _filesread + bp ], ax
	mov word [ _totalfilespace + _low + bp ], ax
	mov word [ _totalfilespace + _high + bp ], ax

	mov cx, 0000					; min args
	mov dx, 0001					; max args
	mov bx, _DirSwitches				; dir switches
	call PreProcessCmndLine				; process switches and args
	ifc _dir_Exit					; if error -->

	mov ax, word [ _DirPauseSwitch + swFlags ]
	call setPagingMode

		; get current, max disks
	Int21 CurrentDisk				; get current disk
	mov dl, al
	inc al						; A:=1, ...
	storarg _currdisk, ax				; save disk letter

	Int21 SelectDisk				; use select disk to get max
	xor ah, ah					; top part is 00's
	storarg _maxdisk, ax				; save max disk letter

		; if no args, create a *.* arg
	getarg di, __argarray
	mov si, word [ argpointer + di ]		; locate dir argument
	or si, si					; no name provided ?
	jnz _dir_06					; name provided -->
	mov si, RxDOS_AllFiles				; use *.*

_dir_06:
	lea di, [ _pathname + bp ]
	call CopyString					; copy whatever was entered

	dec di						; point to zero terminator
	cmp byte [ di - 1 ], ':'			; only entered drive and colon ?
	jnz _dir_10					; no -->

	mov si, RxDOS_AllFiles
	call CopyString					; append *.*

		; get specific info from command: drive, extension
_dir_10:
	xor cx, cx
	lea si, [ _pathname + bp ]
	lea di, [ _parsedfilename + bp ]
	call BuildParsedFilenameArray			; pointers/length of arguments

	cmp word [ _parsedfilename + parsedrive + bp ], byte -1
	jz _dir_12					; no drive specified -->
	mov ax, word [ _maxdisk + bp ]			; get max disk letter
	cmp ax, word [ _parsedfilename + parsedrive + bp ]
	ja _dir_12					; drive is acceptable
	jmp _dir_DriveError				; else invalid drive selected -->

_dir_12:
	mov ax, word [ _parsedfilename + parseptrextension + bp ]
	mov word [ _extensionFlag + bp ], ax		; save whether extension was ever present

	mov cl, LFNEXPAND_GETFULLPATHNAME
	lea si, [ _pathname + bp ]
	lea di, [ _filename + bp ]
	mov word [ di ], '\'				; init area
	Int21 LFNGetActualFileName			; expand name
	jnc _dir_16					; if name is ok -->

	mov cl, LFNEXPAND_GETFULLPATHNAME
	mov si, RxDOS_AllFiles				; *.*
	lea di, [ _filename + bp ]
	mov word [ di ], '\'				; init area
	Int21 LFNGetActualFileName			; expand name

_dir_16:
	xor cx, cx
	lea si, [ _filename + bp ]
	lea di, [ _parsedfilename + bp ]

	xor ah, ah
	mov al, byte [ si ]				; filename always starts with drive
	storarg _currdisk, ax				; save current disk
	sub al, 'A'					; subtract drive
	cmp al, byte [ _maxdisk + bp ]			; is it greater than max drive ?
	ifnc _dir_DriveError				; yes, bad drive -->

	call BuildParsedFilenameArray
	jnz _dir_28					; if wild characters found -->

		; test directory, handle dot and dotdot entries
	fileAttrib ATTR_DIRECTORY
	mov si, FINDDATA_MSDOSDATEFORMAT
	lea di, [ _finddata + bp ]
	lea dx, [ _filename + bp ]
	Int21 LFNFindFirstFile				; locate file
	jc _dir_28

	storarg _dirhandle, ax				; save handle

_dir_20:
	test byte [ _finddata + findDataAttributes + bp ], ATTR_DIRECTORY
	jz _dir_28					; if not a directory -->

	cmp byte [ _finddata + findDataShortFilename + bp ], '.'
	jnz _dir_22

	getarg bx, _dirhandle				; get handle
	mov si, FINDDATA_MSDOSDATEFORMAT		; format
	lea di, [ _finddata + bp ]			; find data
	Int21 LFNFindNextFile				; locate next file
	jnc _dir_20					; see if also a dir -->
	jmp short _dir_28

		; if a directory name, change to include *.* for all files
_dir_22:
	lea si, [ _filename + bp ]
	lea di, [ _pathname + bp ]
	Call CopyString

	mov si, RxDOS_AllFiles				; *.*
	lea di, [ _pathname + bp ]			; append here
	call _AppendPathName				; append all files to dir

		; is file name present ?
_dir_28:
	getarg bx, _dirhandle				; file handle
	call CheckFileClose

	lea si, [ _pathname + bp ]
	lea di, [ _filename + bp ]
	mov word [ di ], '\'				; init area

	mov cl, LFNEXPAND_GETFULLPATHNAME
	Int21 LFNGetActualFileName			; expand name to get real display name
	jnc _dir_42					; if ok -->

	lea si, [ _pathname + bp ]
	lea di, [ _filename + bp ]
	call CopyString

		; display header
_dir_42:
	test word [ _DirBareSwitch + swFlags ], SW_SWITCHSET
	jnz _dir_52					; skip header	-->

	mov al, byte [ _currdisk + bp ]			; get current disk value
	mov bx, _Dir_NoVolumeLabel			; assume no volume label
	lea di, [ _finddata + bp ]			; get volume label
	call returnVolumeName				; get volume for drive
	ifc _dir_DriveError				; cannot open drive -->
	jnz _dir_44					; if no volume name -->

	push di						; save vol label pointer
	mov bx, _Dir_VolumeLabel			; print statement format

_dir_44:
	lea di, [ _currdisk + bp ]			; pointer to current disk
	push di						; current disk
	push bx						; format
	lea di, [ _printbuffer + bp ]
	push di
	call _sprintf
	add sp, ax					; # args passed
	call DisplayLine

		; display drive: path
	lea si, [ _filename + bp ]
	lea di, [ _pathname + bp ]
	call CopyString					; copy to pathname

_dir_48:
	dec di
	cmp byte [ di ], '\'				; isolate path
	jnz _dir_48

	mov byte [ di ], 0

	lea di, [ _pathname + bp ]
	push di						; first arg encountered

	mov di, _Dir_DirectoryOf
	push di
	lea di, [ _printbuffer + bp ]
	push di
	call _sprintf
	add sp, ax					; # args passed
	call DisplayLine

		; scan through files
_dir_52:
	fileAttrib 0000, ATTR_DIRECTORY
	mov si, FINDDATA_MSDOSDATEFORMAT
	lea di, [ _finddata + bp ]
	lea dx, [ _filename + bp ]			; pointer to search filename
	Int21 LFNFindFirstFile				; locate file
	ifc _dir_72					; if none located -->
	storarg _dirhandle, ax				; save handle

_dir_54:
	inc word [ _filesread + bp ]			; files read

	lea di, [ _finddata + findDataLongFilename + bp ]
	push di

	mov ax, word [ _finddata + findDataCreateTime + finddataTime + bp ]
	lea di, [ _asciiFileTime + bp ]
	call _dirTimeToAscii
	push di

	mov ax, word [ _finddata + findDataCreateTime + finddataDate + bp ]
	lea di, [ _asciiFileDate + bp ]
	call _dirDateToAscii
	push di

	test byte [ _finddata + findDataAttributes + bp ], ATTR_DIRECTORY
	jnz _dir_60					; if a directory -->

	lea di, [ _finddata + findDataFileSizeLow + bp ]
	mov ax, word [ _low + di ]
	mov dx, word [ _high + di ]
	add word [ _totalfilespace + _low + bp ], ax
	adc word [ _totalfilespace + _high + bp ], dx
	push di						; third arg: file size

_dir_60:
	lea di, [ _finddata + findDataShortFilename + bp ]
	mov al, byte [ di ]				; start of filename
	call _endofString				; point to null terminator

	push di						; terminator, in case no extension
	cmp al, '.'					; filename either . or .. ?
	jz _dir_64					; yes, no need to find extension -->

	mov al, '.'
	lea cx, [ _finddata + findDataShortFilename + bp ]
	xchg di, cx					; determine search length
	sub cx, di					; search length
	repnz scasb					; else scan for extension
	jnz _dir_64					; if found, di points to extension
	mov byte [ di-1 ], 0				; else, di will point to a null (no extension)
	pop ax
	push di						; extension address, if found

_dir_64:
	lea di, [ _finddata + findDataShortFilename + bp ]
	push di						; pointer to filename

	mov di, _Dir_FileEntry
	test byte [ _finddata + findDataAttributes + bp ], ATTR_DIRECTORY
	ifz _dir_66					; if not a directory -->

	mov di, _Dir_DirEntry

_dir_66:
	push di
	lea di, [ _printbuffer + bp ]
	push di
	call _sprintf
	add sp, ax					; # args passed

	test word [ _DirLowerCaseSwitch + swFlags ], SW_SWITCHSET
	jz _dir_68					; not lower case option ->
	push ss
	push si						; where string
	call _lowerCaseString				; lowercase string

_dir_68:
	call DisplayLine				; print line
	ifc _dir_Exit					; control C abort -->

	getarg bx, _dirhandle				; dir handle
	mov si, FINDDATA_MSDOSDATEFORMAT		; format
	lea di, [ _finddata + bp ]			; finddata
	Int21 LFNFindNextFile				; locate next file
	ifnc _dir_54					; if none located -->

		; print number of files
_dir_72:
	cmp word [ _filesread + bp ], byte 0		; any files read ?
	jnz _dir_76					; yes -->

	mov dx, CmndError_NoFilesFound
	call DisplayLine				; file not found
	jmp short _dir_Exit

		; display files, space used, space free
_dir_76:
	mov cx, sizeEXTENDEDFREESPACE
	lea dx, [ _filename + bp ]
	lea di, [ _extendedfreespace + bp ]
	Int21 LFNGetExtFreeSpace			; get free space

	mov word [ _summaryline + bp ], _Dir_Files_Summary
	mov ax, word [ es:di + _extFreeAvailablePhysSectors + _low ]
	mov dx, word [ es:di + _extFreeAvailablePhysSectors + _high ]
	mov cx, word [ es:di + _extFreeBytesPerSector + _low ]
	call _mul32					; * bx = total space

	test word [ es:di + _extFreeAvailablePhysSectors + _high ], 0FFF0h
	jz _dir_82					; if it doesn't exceed 4 GiB -->
		; RxDOS 7.20N:	This assumes 512 byte sectors, doesn't it?
		;		Remove and use new overflow detection in _mul32!

	mov ax, word [ es:di + _extFreeAvailablePhysSectors + _low ]
	mov dx, word [ es:di + _extFreeAvailablePhysSectors + _high ]
	add ax, 0ffffh
	adc dx, 7h					; handle possible rounding
	mov cx, 2 * 1024				; 1024 * 1024 / 512
	call _div32
	xor dx, dx
		; RxDOS 7.20N:	This assumes 512 byte sectors.

	mov word [ _summaryline + bp ], _Dir_Files_MBSummary
	lea di, [ _freespaceFraction + bp ]
	mov word [ di ], 0
	push di

_dir_82:
	stordarg _freespace, dx, ax

	lea di, [ _freespace + bp ]
	push di
	lea di, [ _totalfilespace + bp ]
	push di
	lea di, [ _filesread + bp ]
	push di

	push word [ _summaryline + bp ]
	lea di, [ _printbuffer + bp ]
	push di
	call _sprintf
	add sp, ax					; # args passed
	call DisplayLine				; print line

		; done
_dir_Exit:
	getarg bx, _dirhandle				; file handle
	call CheckFileClose

_dir_Return:
	Return

		; if error
_dir_DriveError:
	mov dx, CmndError_InvalidDrive
	call DisplayErrorMessage			; display message
	Return


		; Build parsed filename array
		;
		; Scans a filename and builds a pointer list to drive, path,
		; filename and extension terms.
		;
		; INP:	cx = length of argument
		;	es:si-> input filename passed
		;	ss:di-> parse list structure
		; OUT:	ss:di-> pointer structure
		;	ZR if name does not contain any wild character
BuildParsedFilenameArray:
	entry
	def	length, cx
	def	source, si
	def	parseliststruct, di

	clearMemory sizeParsedFilename			; clear parsed filename area

	or cx, cx					; length passed ?
	jnz _filenameparsearray_06			; yes -->

	push si
	push di
	mov di, si
	xor ax, ax
	mov cx, -1
	repnz scasb					; scan arg length
	not cx
	dec cx
	pop di
	pop si

_filenameparsearray_06:
	mov word [ parseptrstartstring + _pointer + di ], si
	mov word [ parseptrstartstring + _segment + di ], es
	mov word [ parsestringlength + di ], cx
	mov word [ parsedrive + di ], -1		; set drive invalid
	storarg _length, cx

		; see if drive is passed
	mov ax, word [ es:si ]				; get first term
	cmp ah, ':'					; drive separator ?
	jnz _filenameparsearray_08			; no -->

	and ax, 1Fh
	dec ax
	mov word [ parsedrive + di ], ax		; drive

		; scan string through entire path until extension, if any.
_filenameparsearray_08:
	getarg si, _source				; source pointer
	add si, cx					; points to end

_filenameparsearray_12:
	dec si
	mov al, byte [ es:si ]

	Goto '?', _filenameparsearray_WildChar
	Goto '*', _filenameparsearray_WildChar
	Goto '.', _filenameparsearray_Extension
	Goto ':', _filenameparsearray_Path
	Goto '\', _filenameparsearray_Path

_filenameparsearray_18:
	loop _filenameparsearray_12

	getarg ax, _source
	mov word [ parseptrfilename + di ], si
	jmp short _filenameparsearray_32

_filenameparsearray_WildChar:
	mov word [ parsewildcharflag + di ], TRUE
	jmp short _filenameparsearray_18

_filenameparsearray_Extension:
	mov dx, si
	inc dx
	mov word [ parseptrextension + di ], dx

	getarg ax, _length
	sub ax, cx
	mov word [ parseextensionlength + di ], ax
	jmp short _filenameparsearray_18

_filenameparsearray_Path:
	mov dx, si
	inc dx
	mov word [ parseptrfilename + di ], dx

_filenameparsearray_32:
	mov ax, word [ parseptrfilename + di ]
	sub ax, word [ _source + bp ]
	mov word [ parsepathlength + di ], ax

	mov ax, word [ parseptrextension + di ]
	sub ax, word [ parseptrfilename + di ]
	dec ax
	mov word [ parsefilenamelength + di ], ax

	mov ax, word [ parsewildcharflag + di ]
	or ax, ax
	Return
