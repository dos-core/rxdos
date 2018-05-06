
%if 0

RxDOSMEM - RxDOS Memory management functions

This product is distributed AS IS and contains no warranty
whatsoever, including warranty of merchantability or
fitness for a particular purpose.

(c) Copyright 1990, 1999. Mike Podanoffsky

This is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License, see
the file LICENSE.TXT.

%endif

%include "RXDMACRO.NEW"
%include "RXDSTRUC.NEW"

	cpu 8086

%include "memory.asm"


		; Allocate Min Max Memory Block
		;
		; Input:
		; ax	minimum block
		; dx	maximum block
		;
		; Returns:
		; es	segment address of allocated memory block
		; ax	segment address of allocated memory block header
		; cx	size of memory available
_allocateMinMaxMemBlock:
	mov bx, ax	; bx = minimal
	mov ax, dx	; ax = maximal
	call GetMCBOwner			; dx = owner
%ifn _UMA
 %if _386
	movzx cx, byte [ss:_RxDOS_AllocStrategy]; cx = flags
 %else
	xor cx, cx
	mov cl, byte [ss:_RxDOS_AllocStrategy]	; cx = flags
 %endif
%else
	call GetMCBFlags			; cx = fixed flags
%endif
	call AllocateLargestMCBRandom
	jc .error
	mov es, ax
	dec ax
	mov cx, bx
.error:
	retn


		; Allocate Memory Block
		; 
		; Input:
		; cx	# paragraphs of memory requested
		; 
		; Returns:
		; es	segment address of allocated memory block
		; cy	if error
		;  cx	size of largest block of memory available in paragraphs
allocateMemBlock:
	mov bx, cx	; bx = size
	call AllocateMCB
	mov es, ax
	mov cx, bx
	retn


		; Collect Memory Blocks
		; 
		; This routine will scan all memory blocks and merge all free
		; memory blocks together.
_collectMemoryBlocks: equ CollectFreeMCBs


		; Release all memory blocks for owner
		; 
		; Usage:
		; bx	PSP address of owner
_releaseOwnerMemoryBlocks: equ ReleaseOwnersMCBs


		; Free Memory Block
		; 
		; Usage:
		; es	memory block
_freeMemBlock:
	mov ax, es
	jmp ReleaseMCB


		; Modify Block Size
		; 
		; On Call:
		; es	paragraph to modify
		; bx	new paragraph size
		; 
		; On Return:
		; es	paragraph to modify
		; bx	max block available
		; ax	error code, if error
		; cy	set if error
		; 
		; Contraction involves splitting a block into two smaller
		; portions. Expansion requires that the block which follows
		; be empty. If it is, it is combined with the modify block
		; to create a huge block, which can then be split.
_modifyMemBlock:
	mov ax, es
	jmp ModifyMCB

