
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

	cpu 8086

	segment RXDOS align=16 class=RXDOS use16 public
	segment RXDOS

%include "RXDMACRO.MAC"
%include "RXDSTRUC.MAC"

	global allocateMemBlock
	global _freeMemBlock
	global _modifyMemBlock

	global _initializeMemoryBlock
	global _collectMemoryBlocks
	global _releaseOwnerMemoryBlocks
	global _allocateUpperMB
	global _allocateConvMB
	global _allocateMinMaxMemBlock

	extern _RxDOS_CurrentPSP
	extern _RxDOS_pStartMemBlock
	extern _RxDOS_DOSProgramName
	extern _RxDOS_AllocStrategy
	extern _RetCallersStackFrame

	extern pexterrInvalidFunction
	extern pexterrFileNotFound
	extern pexterrPathNotFound
	extern pexterrIllegalName
	extern pexterrNoHandlesAvailable
	extern pexterrAccessDenied
	extern pexterrInvalidHandle
	extern pexterrArenaTrashed
	extern pexterrNotEnoughMemory
	extern pexterrInvalidBlock
	extern pexterrInvalidAccess
	extern pexterrInvalidDrive
	extern pexterrCurrentDirectory
	extern pexterrNoMoreFiles
	extern pexterrFileExists


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

	Entry
	def	minParag, ax
	def	maxParag, dx

	mov cx, dx					; try for max
	call allocateMemBlock				; will probably fail
	jnc .gotalloc					; if ok -->

	cmp cx, word [ _minParag + bp ]			; largest available will fit ?
	jae .alloc					; yes, go for max -->
	SetError pexterrNotEnoughMemory, .error

.alloc:
	call allocateMemBlock				; allocate largest available
	jc .error
.gotalloc:
	mov es, ax					; segment address
	dec ax
	clc
.error:
	Return


		; Initialize Memory Block
		; 
		; es	segment points to memory block to initialize
		; ax	is size to initialize (paragraphs )
		; bx	parent
		;  0000 block is free
		;  0008 (_RxDOS_PARENT_SIGNATURE) block belongs to RxDOS
_initializeMemoryBlock:
	push ax						; init length (paragraphs )

	xor ax, ax
	xor di, di
	mov cx, (sizeMEMBLOCK)/2			; size of memory header (words )
	rep stosw

	pop ax
	xor di, di
	mov byte [ es:_memSignature ], _RxDOS_ENDSIGNATURE
	mov word [ es:_memAlloc ], ax
	mov word [ es:_memParent ], bx

		; if system MCB, copy RxDOS program name to memory block
	cmp bx, byte _RxDOS_PARENT_SIGNATURE		; RxDOS Block ?
	jnz _initMemory_20				; if not RxDOS -->

	push ds
	push si
	push di

	currSegment ds					; point to data segment
	mov si, _RxDOS_DOSProgramName
	lea di, [ word _memPgmName + di ]
	mov cx, 4					; (size _RxDOS_DOSProgramName)/2
	repe movsw					; copy RxDOS name to memory block

	pop di
	pop si
	pop ds

_initMemory_20:
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

	Entry
	def	allocation, cx

	mov bx, cx
	call _allocateUpperMB				; allocate upper mem blocks
	jnc allocateMemBlock_12				; if allocation made -->

	getarg bx, _allocation
	call _allocateConvMB				; allocate lower mem blocks

allocateMemBlock_12:
	mov es, ax					; segment allocation
	mov cx, dx					; largest block
	Return


		; Collect Memory Blocks
		; 
		; This routine will scan all memory blocks and merge all free
		; memory blocks together.
_collectMemoryBlocks:

	push ds
	push es
	push ax
	mov ax, word [ ss:_RxDOS_pStartMemBlock ]

		; is block free ?
_collectMemoryBlocks_08:
	mov ds, ax					; next in ax

_collectMemoryBlocks_12:
	cmp byte [ _memSignature ], _RxDOS_MEMSIGNATURE
	jnz _collectMemoryBlocks_36			; done -->

	cmp word [ _memParent ], byte 0			; is block free ?
	jnz _collectMemoryBlocks_26			; no, go to next -->

		; is next also free ?
	mov ax, ds					; get current segment
	add ax, word [ _memAlloc ]			; increment to next block
	inc ax
	mov es, ax
	cmp word [ es:_memParent ], byte 0		; is next block free ?
	jnz _collectMemoryBlocks_08			; no, go to next -->

	mov al, byte [ es:_memSignature ]		; last signature is passed to current block
	mov byte [ _memSignature ], al

	mov ax, word [ es:_memAlloc ]			; get next allocation
	inc ax						; kill interim Mem block as well
	add word [ _memAlloc ], ax			; add to current block

	jmp short _collectMemoryBlocks_12

		; go to next
_collectMemoryBlocks_26:
	mov ax, ds					; get current segment
	add ax, word [ _memAlloc ]			; increment to next block
	inc ax
	jmp short _collectMemoryBlocks_08

		; done
_collectMemoryBlocks_36:
	pop ax
	pop es
	pop ds
	retn


		; Release all memory blocks for owner
		; 
		; Usage:
		; bx	PSP address of owner
_releaseOwnerMemoryBlocks:

	push es
	mov ax, word [ ss:_RxDOS_pStartMemBlock ]

		; does block belong to owner ?
_releaseOwnerMemoryBlocks_08:
	mov es, ax					; next block in ax
	cmp bx, word [ es:_memParent ]			; owner block ?
	jnz _releaseOwnerMemoryBlocks_12		; no -->
	mov word [ es:_memParent ], 0			; free up block

_releaseOwnerMemoryBlocks_12:
	cmp byte [ es:_memSignature ], _RxDOS_MEMSIGNATURE
	jnz _releaseOwnerMemoryBlocks_24		; if at end -->

	mov ax, es					; get current segment
	add ax, word [ es:_memAlloc ]			; increment to next block
	inc ax
	jmp short _releaseOwnerMemoryBlocks_08

_releaseOwnerMemoryBlocks_24:
	pop es
	retn


		; Free Memory Block
		; 
		; Usage:
		; es	memory block
_freeMemBlock:

	push es
	mov ax, es
	or ax, ax
	jz _freeMemBlock_16

	dec ax						; -> MCB
	mov es, ax
	cmp byte [ es:_memSignature ], _RxDOS_MEMSIGNATURE
	jz _freeMemBlock_12
	cmp byte [ es:_memSignature ], _RxDOS_ENDSIGNATURE
	jnz _freeMemBlock_16				; invalid block -->

_freeMemBlock_12:
	mov word [ es:_memParent ], 0			; free up block

_freeMemBlock_16:
	pop es
	retn


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
	entry
	def	modifyBlock
	def	modifySize, bx

	call _collectMemoryBlocks			; collect free blocks

	mov ax, es
	dec ax
	mov es, ax
	storarg _modifyBlock, ax

	cmp byte [ es:_memSignature ], _RxDOS_MEMSIGNATURE
	jz _modifyMemBlock_12
	cmp byte [ es:_memSignature ], _RxDOS_ENDSIGNATURE
	jz _modifyMemBlock_12

	SetError pexterrInvalidBlock, _modifyMemBlock_66

		; are we expanding allocation ?
_modifyMemBlock_12:
	cmp bx, word [ es:_memAlloc ]
	jb _modifyMemBlock_32				; if contracting allocation -->
	ifz _modifyMemBlock_42				; same size as now, ignore request -->

	mov dx, word [ es:_memAlloc ]			; get current allocation size
	cmp byte [ es:_memSignature ], _RxDOS_MEMSIGNATURE
	jnz _modifyMemBlock_14				; if at end block, can't expand ->

	inc dx
	mov ax, es
	add ax, dx
	mov es, ax					; address of next block
	cmp word [ es:_memParent ], byte 0		; is next block free ?
	jnz _modifyMemBlock_14				; no, error -->

	add dx, word [ es:_memAlloc ]			; total expansion space
	cmp bx, dx					; is extra block enough to expand ?
	jbe _modifyMemBlock_18				; yes, ok to try to expand -->

_modifyMemBlock_14:
	mov bx, dx					; available size
	jmp near _modifyMemBlock_46			; not enough memory -->

		; merge blocks together
_modifyMemBlock_18:
	mov al, byte [ es:_memSignature ]		; sig of next block

	getarg es, _modifyBlock
	mov word [ es:_memAlloc ], dx			; new expanded size
	mov byte [ es:_memSignature ], al		; sig of next block

		; collapse allocated space
_modifyMemBlock_32:
	mov cx, es					; current segment
	add cx, bx
	inc cx						; where to create next mem seg

	mov dl, byte [ es:_memSignature ]		; sig of next block
	mov ax, word [ es:_memAlloc ]			; existing allocated space
	sub ax, bx					; size of remaining block
	jz _modifyMemBlock_42				; same as now -- done
	dec ax						; make room for mem header
	mov byte [ es:_memSignature ], _RxDOS_MEMSIGNATURE
	mov word [ es:_memAlloc ], bx			; re-allocate space

	push dx
	mov es, cx
	xor bx, bx					; free block
	call _initializeMemoryBlock			; initialize memory block.

	pop dx
	mov byte [ es:_memSignature ], dl

_modifyMemBlock_42:
	clc
	return

		; return with error ax, set caller's bx to bx
_modifyMemBlock_46:
	RetCallersStackFrame es, si
	mov word [ es:si + _BX ], bx			; max amount allowed
	mov ax, pexterrNotEnoughMemory

		; return with error ax
_modifyMemBlock_66:
	stc
	return


		; Allocate Upper Memory Blocks
		; 
		; bx	# paragraphs of memory requested
		; 
		; Returns:
		; ax	segment address of allocated memory block
		; CY if error
		;  dx	size of largest block of memory available in paragraphs
_allocateUpperMB:
	stc
	retn

%if 1
	test word [ _RxDOS_AllocStrategy ], (_MEM_FIRSTFIT_HIGH + _MEM_FIRSTFIT_HIGHONLY)
	jnz _allocateUpperMB_14				; if search upper memory blocks -->

_allocateUpperMB_12:
	xor dx, dx
	SetError pexterrNotEnoughMemory
	retn

_allocateUpperMB_14:
	mov ax, _RxDOS_HIGHMEMBLOCK
		; RxDOS 7.20N: Wrongly hard-coded top-of-LMA address.
	jmp short _localAreaAllocateMemory
%endif


		; Allocate Conventional Memory Blocks
		; 
		; bx	# paragraphs of memory requested
		; 
		; Returns:
		; ax	segment address of allocated memory block
		; CY if error
		;  dx	size of largest block of memory available in paragraphs
_allocateConvMB:
	test word [ _RxDOS_AllocStrategy ], (_MEM_FIRSTFIT_HIGHONLY )
	jz _allocateConvMB_14				; if search conv memory blocks -->

_allocateConvMB_12:
	xor dx, dx
	SetError pexterrNotEnoughMemory
	retn

_allocateConvMB_14:
	call _collectMemoryBlocks			; collect free blocks
	mov ax, word [ ss:_RxDOS_pStartMemBlock ]
		; fall through


		; Local Zone Memory Allocation
		; 
		;	ax = first MCB to begin search
		;	bx = number of paragraphs of memory requested
		; 
		; Returns:
		;	CY if error,
		;	 ax = error code
		;	 bx = size of largest block of memory available in paragraphs
		;	NC if successful,
		;	 ax = segment address of allocated memory block
_localAreaAllocateMemory:
	entry
	def	bestFit, 0				; segment of best fit
	def	lastFit, 0				; segment of last fit
	def	sizeFirstBlock				; size of first block
	def	sizeSecondBlock				; size of second block
	def	returnSegmentAddress			; return segment address
	def	firstSegmentAddress			; first segment
	def	secondSegmentAddress			; second segment

	push ds
	push es						; save segment registers
%if 0
	pushf						; save flags - will turn off IF
%endif

	or ax, ax					; zero if no memory area specified
	jnz _allocMem_10				; memory area available -->
	xor dx, dx					; no memory available
	SetError pexterrNotEnoughMemory, _allocMem_44	; error -->

		; scan memory blocks
_allocMem_10:
	cli						; prevent interrupts
	xor dx, dx					; largest available
	mov cx, 0FFFFh					; best fit

_allocMem_12:
	mov es, ax					; point to memory seg
	cmp byte [ es:_memSignature ], _RxDOS_MEMSIGNATURE
	jz _allocMem_14					; if valid arena -->
	cmp byte [ es:_memSignature ], _RxDOS_ENDSIGNATURE
	jz _allocMem_14					; if valid arena -->
	SetError pexterrArenaTrashed, _allocMem_44	; else, if error -->

_allocMem_14:
	cmp word [ es:_memParent ], byte 0		; free block ?
	jnz _allocMem_20				; no -->

	mov si, word [ es:_memAlloc ]			; get available space
%if 0
	cmp dx, si					; larger block ?
	jnb _allocMem_15				; no -->
	mov dx, si					; get size

_allocMem_15:
%endif
	sub si, bx					; is block within allocation size ?
	jb _allocMem_16					; no -->

	storarg _lastFit, ax				; segment address of last fit
	test word [ _RxDOS_AllocStrategy ], _MEM_FIRSTFIT_MASK
	jz _allocMem_30					; allocate the block found first -->

	cmp cx, si					; is this block a better fit ?
	jb _allocMem_16					; not a better strategy -->
	mov cx, si					; else save fit
	storarg _bestFit, ax				; seg address of best fit

_allocMem_16:
%if 1
	cmp dx, word [ es:_memAlloc ]			; larger block ?
	jnb _allocMem_20				; no -->
	mov dx, word [ es:_memAlloc ]			; get size

_allocMem_20:
		; RxDOS 7.20N:	Moved code to above, can use si there.
%endif
	inc ax
	add ax, word [ es:_memAlloc ]
	cmp byte [ es:_memSignature ], _RxDOS_ENDSIGNATURE
	jnz _allocMem_12				; not at end yet -->

		; available block not found or allocation deferred to here
	getarg ax, _bestFit
	test word [ _RxDOS_AllocStrategy ], _MEM_BESTFIT_MASK
	jnz _allocMem_24				; allocate the best fit -->

	getarg ax, _lastFit
	test word [ _RxDOS_AllocStrategy ], _MEM_LASTFIT_MASK
	jz _allocMem_26					; invalid strategy -->
							; allocate the last fit
_allocMem_24:
	or ax, ax					; determine if no allocation
	jnz _allocMem_30				; if block available -->

_allocMem_26:
	SetError pexterrNotEnoughMemory, _allocMem_44	; error exit -->

		; Allocate block
		; 
		; ax = free MCB from where to allocate
		; bx = allocation size
_allocMem_30:
	mov es, ax
	storarg _returnSegmentAddress, es		; save this address
	mov dl, byte [ es:_memSignature ]		; current block signature
	mov ax, word [ es:_memAlloc ]			; get allocation

	sub ax, bx					; this is remaining alloc balance
	je _allocMem_38					; if exact fit, allocate full block -->

	mov cx, es
	add cx, ax					; where next block will be if high
	dec ax						; make room for second memory control block
	storarg _sizeFirstBlock, ax			; first block size, assume last fit
	storarg _sizeSecondBlock, bx			; second block size, assume last fit
	storarg _returnSegmentAddress, cx

	test word [ _RxDOS_AllocStrategy ], _MEM_LASTFIT_MASK
	jnz _allocMem_32				; if allocate is last fit -->

	mov cx, es
	add cx, bx					; space we'll need
	inc cx						; where next block will be
	storarg _sizeFirstBlock, bx			; first block size, assume other fit
	storarg _sizeSecondBlock, ax			; second block size, assume other fit
	storarg _returnSegmentAddress, es

_allocMem_32:
	storarg _firstSegmentAddress, es
	storarg _secondSegmentAddress, cx

	push dx						; current block signature
	mov es, cx					; create a block here
	xor bx, bx					; this block is free
	getarg ax, _sizeSecondBlock			; second block size
	call _initializeMemoryBlock			; initialize memory block.
	pop dx
	mov byte [ es:_memSignature ], dl		; save real signature

	getarg es, _firstSegmentAddress
	getarg bx, _sizeFirstBlock			; first block size
	mov word [ es:_memAlloc ], bx			; allocate what we need
	mov byte [ es:_memSignature ], _RxDOS_MEMSIGNATURE

		; update old memory control block
_allocMem_38:
	getarg es, _returnSegmentAddress		; get return seg address
	mov cx, word [ ss:_RxDOS_CurrentPSP ]
	or cx, cx					; NC
	jnz _allocMem_40
%if 1
	mov cx, _RxDOS_PARENT_SIGNATURE			; system block
%else
	mov cl, 8					; if zero, use system block identifier instead
%endif

_allocMem_40:
	mov word [ es:_memParent ], cx			; current owner

	mov dx, word [ es:_memAlloc ]			; allocated size
	mov ax, es
	inc ax						; segment address of data
%if 1
	clc						; no carry.
%endif

_allocMem_44:
%if 0
	jc .return_cy
	popf						; restore IF
	db __NOP_DATA2					; NC, skip "popf" and "stc"
.return_cy:
	popf
	stc
%endif
	pop es						; restore segment registers
	pop ds

%if 1
	sti
		; RxDOS 7.20N:	I see no reason to force IF on here.
%endif
	return
