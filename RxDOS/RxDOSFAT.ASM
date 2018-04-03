
%if 0

RxDOSFAT - RxDOS walk through FAT code

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

%if _BUILD_OBJ
	segment RXDOS align=16 class=RXDOS use16 public
	segment RXDOS

	global AllocateCluster
	global AllocateInitCluster
	global AmountFreeSpace
	global UpdateFreeSpace
	global AppendCluster
	global computeLogSectorNumber

	global getNextClusterDskAccess
	global ReleaseClusterChain
	global ReleaseClusterChainDskAccess

	global updateClusterValue
	global _FATReadRandom

	extern CCBChanged
	extern getDPB
	extern getAddrDPB
	extern readBuffer
	extern readFATBuffer
	extern readSelBuffer
	extern SelBuffer
	extern CCBChanged
	extern updateChangedCCB
	extern updateAllChangedCCBBuffers
	extern DevRead
	extern _cmp32
	extern _mul32
	extern _div32
%endif

		; Definitions
MINCLUSTER	EQU 2					; min cluster value


		; Get Next Cluster
		;
		; Input:
		; ax	drive
		; ss:di	ptr diskAccess structure
		;
		; Output:
		; ax	drive
		; cx:dx	next cluster
		; zr	if end of cluster chain.
		;
		; Preserves:
		; es, ds, di, si, bx, ax
getNextClusterDskAccess:

	mov ax, word [ ss:diskAcDrive + di ]
	mov dx, word [ ss:diskAcCurCluster + _low + di ]
	mov cx, word [ ss:diskAcCurCluster + _high + di ]
	call getNextCluster

%if 0
		; RxDOS 7.20N:	Commented in former releases
	mov word [ ss:diskAcCurCluster + _low + di ], dx
	mov word [ ss:diskAcCurCluster + _high + di ], cx
%endif
	retn


		; Get Next Cluster
		;
		; Input:
		; ax	drive
		; cx:dx	current cluster
		;
		; Output:
		; ax	drive
		; cx:dx	next cluster
		; zr	if end of cluster chain.
		;
		; Preserves:
		; es, ds, di, si, cx, bx, ax
getNextCluster:

	saveRegisters es, di, si, bx, ax

	call getAddrDPB					; (es:bx) Device Parameter Block
	jnc getNextCluster_12				; continue if no error -->

	mov cx, -1
	mov dx, cx					; on error, set cx:dx to -1
	cmp dx, cx					; set ZR (they're the same)
	stc						; and set CY
	jmp short getNextCluster_Return			; exit -->

		; see if FAT32
getNextCluster_12:
	cmp word [ es:_dpbSectorsPerFat + bx ], byte 0
	jnz getNextCluster_16

		; if FAT32
	call _FAT32GetNextCluster
	jmp short getNextCluster_Return

		; if FAT12/FAT16
getNextCluster_16:
	call _FAT16GetNextCluster

getNextCluster_Return:
	restoreRegisters ax, bx, si, di, es
	retn


		; Get next cluster (FAT12/FAT16)
		;
		; Input:
		; ax	drive
		; dx	current cluster
		;
		; Output:
		; ax	drive
		; dx	next cluster
		; zr	if end of cluster chain.
		;
		; Preserves:
		; es, ds, di, si, cx, bx, ax
_FAT16GetNextCluster:

	Entry
	def	drive, ax
	def	cluster, dx

	call getAddrDPB					; (es:bx) Device Parameter Block
	mov dx, -1					; presume end if error
	jc _FAT16GetNextCluster_Return			; exit if error -->

		; determine FAT12 or FAT16
	mov ax, word [ _cluster + bp ]			; get cluster #
	cmp ax, byte MINCLUSTER				; less than min cluster ?
	jb _FAT16GetNextCluster_22			; exit with -1 -->

	cmp ax, word [ es:bx + _dpbMaxClusterNumber ]
	jc _FAT16GetNextCluster_08			; if valid -->
	jnz _FAT16GetNextCluster_22			; else exit with -1 -->

_FAT16GetNextCluster_08:
	xor dx, dx
	test word [ es:bx + _dpbMaxClusterNumber ], 0F000h
	jnz _FAT16GetNextCluster_16Bits			; if 16 -->

		; If FAT12
_FAT16GetNextCluster_12Bits:
	mov ax, word [ _drive + bp ]			; get drive
	mov dx, word [ _cluster + bp ]			; and cluster
	call _get_12Bit_ClusterValue
	jmp short _FAT16GetNextCluster_Return

		; If FAT16
_FAT16GetNextCluster_16Bits:
	mov cx, word [ es:bx + _dpbBytesPerSector ]
	shr cx, 1
	div cx						; FAT sector/Offset

	; ax will contain FAT sector
	; dx will contain byte offset into FAT sector

	add dx, dx					; make word offset
	push dx

	xor cx, cx
	mov dx, word [ es:bx + _dpbFirstFAT ]		; where is first FAT table ?
	add dx, ax					; add offset required
	mov ax, word [ _drive + bp ]			; get drive
	call readFATBuffer				; read FAT Table
	or byte [ es:di + ccbStatus ], ( ccb_isFAT )

	pop bx						; word offset into FAT table
	mov dx, word [ es:di + ccbData + bx ]		; get FAT word

	xor cx, cx
	mov ax, dx
	and al, 0F8h					; FAT value, 16 bit entries
	cmp ax, byte 0FFF8h				; end of chain ?
	jnz _FAT16GetNextCluster_22			; no -->
	mov dx, -1					; if end, set end value
	mov cx, dx					;  (32 bit value)

_FAT16GetNextCluster_22:
	clc

		; return
_FAT16GetNextCluster_Return:
	getarg ax, _drive
	Return


		; Get Next Cluster (FAT32)
		;
		; Input:
		; ax	drive
		; cx:dx	current cluster
		;
		; Output:
		; ax	drive
		; cx:dx	next cluster
		; zr	if end of cluster chain.
		;
		; Preserves:
		; es, ds, di, si, cx, bx, ax
_FAT32GetNextCluster:

	Entry
	def	drive, ax
	ddef	cluster, cx, dx
	ddef	alloccluster, -1, -1			; allocated cluster at -1 (error for now)
	ddef	maxclusters

	call getAddrDPB					; (es:bx) Device Parameter Block
	ifc _FAT32GetNextCluster_Return			; exit if error -->

	call SeeIfMaxClusters				; at max clusters ?
	stordarg _maxclusters, cx, dx			; (save max clusters )
	ifc _FAT32GetNextCluster_22			; exit with -1 -->

	mov cx, word [ es:bx + _dpbBytesPerSector ]
	shr cx, 1
	shr cx, 1					; divide by 4 (4 bytes/entry)

	getdarg dx, ax, _cluster			; restore cluster address
	call _div32					; FAT sector/ offset

	; dx:ax will contain FAT sector
	; cx will contain byte offset into FAT sector

	push cx
	add ax, word [ es:bx + _dpbxReserveSectors + _low ]
	adc dx, word [ es:bx + _dpbxReserveSectors + _high ]	; point to fat sector

	mov cx, dx
	mov dx, ax					; copy sector address to cx:dx
	getarg ax, _drive				; set drive
	call readFATBuffer				; read FAT Table
	or byte [ es:di + ccbStatus ], ( ccb_isFAT )

	pop bx						; offset into FAT table
	add bx, bx
	add bx, bx
	mov dx, word [ es:di + ccbData + bx + _low ]	; get FAT
	mov cx, word [ es:di + ccbData + bx + _high ]
	stordarg _alloccluster, cx, dx

	call isEndOfFAT32
	jnz _FAT32GetNextCluster_22			; no -->
	stordarg _alloccluster, -1, -1			; set end value

_FAT32GetNextCluster_22:
	clc

		; return
_FAT32GetNextCluster_Return:
	getdarg cx, dx, _alloccluster
	Return


		; Scan Ahead Cluster Map
		; Determines how many sequential clusters can be read.
		; It will never return more than 65,536 seq clusters.
		;
		; Input:
		; stack	max clusters to scan
		; ax	drive
		; cx:dx	current cluster
		;
		; Output:
		; ax	# clusters that can be sequentially read
		; cx:dx	last cluster value
scanClusterMap:

	Entry 1
	arg	maxClustersToScan

	def	drive, ax
	ddef	cluster, cx, dx
	def	clusterCount, 0

scanClusterMap_12:
	inc word [ _clusterCount + bp ]		; cluster count
	getarg ax, _maxClustersToScan
	or ax, ax					; zero clusters to scan ?
	jz scanClusterMap_22				; yes -->

	getarg ax, _drive
	call getNextCluster				; get next cluster

	cmp cx, byte -1					; at max cluster ?
	jne scanClusterMap_14				; no -->
	cmp dx, byte -1					; end ?
	je scanClusterMap_22				; yes -->

scanClusterMap_14:
	mov ax, dx
	sub ax, word [ _cluster + _low + bp ]		; are clusters sequential (diff = 1)
	cmp ax, byte 1					;  identified by an offset of 1
	jne scanClusterMap_22				; if NOT sequential -->

	cmp cx, word [ _cluster + _high + bp ]
	jne scanClusterMap_22				; not sequential -->

	stordarg _cluster, cx, dx			; save cluster
	dec word [ _maxClustersToScan + bp ]		; scan more ?
	jnz scanClusterMap_12				; yes -->

scanClusterMap_22:
	mov ax, word [ _clusterCount + bp ]	; # sequential clusters
	getdarg cx, dx, _cluster			; return end cluster
	Return


		; Update Cluster Value
		;
		; Updates the value given for any cluster.
		;
		; Input:
		; ax	drive
		; cx:dx	cluster
		; stack	darg cluster value
		;
		; Returns:
		; cx	original contents in cluster cell
		;
updateClusterValue:

	Entry 2
	darg	updatevalue

	SaveRegisters es, bx, ax

	call getAddrDPB					; (es:bx) Device Parameter Block
	jc updateClusterValue_Return			; exit if error -->

	cmp word [ es:bx + _dpbSectorsPerFat ], byte 0	; small value zero if FAT32
	jnz updateClusterValue_FAT16

		; Update FAT32 cluster
	push word [ _updatevalue + _high + bp ]		; stack args
	push word [ _updatevalue + _low + bp ]		; cx:dx is cluster address
	call _FAT32UpdateClusterValue
	jmp short updateClusterValue_Return

		; Update FAT16 cluster
updateClusterValue_FAT16:
	mov cx, word [ _updatevalue + _low + bp ]
	call _FAT16UpdateClusterValue

updateClusterValue_Return:
	RestoreRegisters ax, bx, es
	Return


		; Update Cluster Value (FAT32)
		;
		; Updates the value given for any cluster.
		;
		; Input:
		; ax	drive
		; cx:dx	cluster
		; stack	value
		;
		; Returns:
		; cx:dx	original contents in cluster cell
		;
_FAT32UpdateClusterValue:

	Entry 2
	darg	updatevalue

	def	drive, ax
	ddef	cluster, cx, dx
	def	sectorsize
	ddef	sector

	saveRegisters es, di, si, bx, ax


		; fix EOF value
	cmp word [ _updatevalue + _high + bp ], byte -1
	jnz _FAT32UpdateCluster_08
	cmp word [ _updatevalue + _low + bp ], byte -1
	jnz _FAT32UpdateCluster_08
	mov word [ _updatevalue + _high + bp ], 0FFFh	; FFFFFFFFh passed through RxDOS
							;  but the actual EOF is 0FFFFFFFh
							; (It's actually rather FAT28...)

		; find FAT sector
_FAT32UpdateCluster_08:
	call getAddrDPB					; (es:bx) Device Parameter Block
	call SeeIfMaxClusters				; at max clusters ?
	ifnc _FAT32UpdateCluster_12			; exit with -1 -->

	mov word [ _updatevalue + _low + bp ], -1
	mov word [ _updatevalue + _high + bp ], -1
	jmp short _FAT32UpdateCluster_26

_FAT32UpdateCluster_12:
	mov cx, word [ es:bx + _dpbBytesPerSector ]
	shr cx, 1
	shr cx, 1					; divide by 4 (4 bytes/entry)

	getdarg dx, ax, _cluster			; restore cluster address
	call _div32					; FAT sector/offset

	; dx:ax will contain FAT sector
	; cx will contain byte offset into FAT sector

	push cx
	add ax, word [ es:bx + _dpbxReserveSectors + _low ]
	adc dx, word [ es:bx + _dpbxReserveSectors + _high ]	; point to fat sector

	mov cx, dx
	mov dx, ax					; copy sector address to cx:dx
	getarg ax, _drive				; set drive
	call readFATBuffer				; read FAT Table
	or byte [ es:di + ccbStatus ], ( ccb_isFAT )

	pop bx						; offset into FAT table
	add bx, bx
	add bx, bx

	getdarg cx, dx, _updatevalue
	xchg dx, word [ es:di + ccbData + bx + _low ]
	xchg cx, word [ es:di + ccbData + bx + _high ]
	stordarg _updatevalue, cx, dx

	call CCBChanged
	or cx, cx

_FAT32UpdateCluster_26:
	getdarg cx, dx, _updatevalue
	call isEndOfFAT32

	restoreRegisters ax, bx, si, di, es
	Return


		; Update Cluster Value (FAT12/FAT16)
		;
		; Updates the value given for any cluster.
		;
		; Input:
		; ax	drive
		; cx	value
		; dx	cluster
		;
		; Returns:
		; cx	original contents in cluster cell
_FAT16UpdateClusterValue:

	Entry
	def	drive, ax
	def	value, cx
	def	cluster, dx
	def	sectorsize
	ddef	sector

	saveRegisters es, di, si, dx, bx, ax

		; determine whether its 12 or 16 bit FAT entries

	call getAddrDPB					; (es:bx) Device Parameter Block
	jc _FAT16UpdateClusterValue_04			; if error -->

	mov ax, word [ _cluster + bp ]			; get cluster #
	cmp ax, byte MINCLUSTER				; invalid number
	jc _FAT16UpdateClusterValue_04			; exit -->
	cmp ax, word [ es:bx + _dpbMaxClusterNumber ]
	jbe _FAT16UpdateClusterValue_08			; if valid cluster # -->

_FAT16UpdateClusterValue_04:
	mov dx, -1
	cmp dl, dl					; set ZR
	stc						; set CY
	jmp _FAT16UpdateClusterValue_Return

_FAT16UpdateClusterValue_08:
	xor dx, dx
	test word [ es:bx + _dpbMaxClusterNumber ], 0F000h
	ifnz _FAT16UpdateClusterValue_16Bits		; if FAT16 -->

		; FAT12
_FAT16UpdateClusterValue_12Bits:
	mov cx, ax
	add ax, ax
	add ax, cx					; nibble address

	mov cx, word [ es:bx + _dpbBytesPerSector ]
	mov word [ _sectorsize + bp ], cx
	dec word [ _sectorsize + bp ]
	shl cx, 1					; nibbles / sector
	div cx						; sector to read

	; ax will contain sector
	; dx will contain nibble offset

	shr dx, 1					; word offset
	push dx						; word offset

	xor cx, cx					; 32 bit address
	mov dx, ax
	add dx, word [ es:bx + _dpbFirstFAT ]		; where is first FAT table ?
	stordarg _sector, cx, dx			; read next cluster sector
	mov ax, word [ _drive + bp ]			; get drive
	call readFATBuffer				; read FAT Table
	or byte [ es:di + ccbStatus ], ( ccb_isFAT )

	getarg cx, _cluster				; get cluster value
	getarg dx, _value				; get value to update
	and dx, 0FFFh

	pop bx						; word offset into FAT table
	cmp bx, word [ _sectorsize + bp ]		; at sector size -1 boundry ?
	jnz _FAT16UpdateClusterValue_16			; no, ok to return as is -->

	call _updateCrossSectorEntry
%if 0
		; RxDOS 7.20N:	Commented for optimization
	call updateAllChangedCCBBuffers
%endif

	clc						; if no carry
	jmp short _FAT16UpdateClusterValue_Return

	; see if odd or even cluster

_FAT16UpdateClusterValue_16:
	shr cx, 1					; even or odd cluster
	jnc _FAT16UpdateClusterValue_20			; even, take value -->

	shl dx, 1
	shl dx, 1
	shl dx, 1
	shl dx, 1					; shift value

	mov cx, word [ es:di + ccbData + bx ]		; get current value
	and word [ es:di + ccbData + bx ], byte 000Fh	; clear area.

	shr cx, 1
	shr cx, 1
	shr cx, 1
	shr cx, 1					; old value shifted correctly
	jmp short _FAT16UpdateClusterValue_22

_FAT16UpdateClusterValue_20:
	mov cx, word [ es:di + ccbData + bx ]		; get current value
	and word [ es:di + ccbData + bx ], 0F000h	; clear area.

_FAT16UpdateClusterValue_22:
	or word [ es:di + ccbData + bx ], dx		; update FAT word

_FAT16UpdateClusterValue_26:
	and cx, 0FFFh					; mask off unwanted bits
	mov ax, cx
	and ax, 0FF8h					; FAT value, 12 bit entries.
	cmp ax, 0FF8h					; end of chain ?
	jnz _FAT16UpdateClusterValue_UpdatedRet		; no -->

	mov cx, -1					; if end, set end value
	jmp short _FAT16UpdateClusterValue_UpdatedRet

		; FAT16
_FAT16UpdateClusterValue_16Bits:
	mov cx, word [ es:bx + _dpbBytesPerSector ]
	shr cx, 1
	div cx						; FAT sector/Offset

	; ax will contain FAT sector
	; dx will contain byte offset into FAT sector

	add dx, dx					; make word offset
	push dx

	xor cx, cx
	mov dx, word [ es:bx + _dpbFirstFAT ]		; where is first FAT table ?
	add dx, ax					; add offset required
	mov ax, word [ _drive + bp ]			; get drive
	call readFATBuffer				; read FAT Table
	or byte [ es:di + ccbStatus ], ( ccb_isFAT )

	pop bx						; word offset into FAT table
	getarg cx, _value				; update value
	xchg cx, word [ es:di + ccbData + bx ]		; update value

		; update
_FAT16UpdateClusterValue_UpdatedRet:
	call CCBChanged
	or cx, cx

		; return
_FAT16UpdateClusterValue_Return:
	restoreRegisters ax, bx, dx, si, di, es
	Return


		; Update Cross Sector Entry
		;
		; Input:
		; es:di	points to current ccb
		; bx	offset into buffer
		; dx	value to update
		; cx	cluster number
		;
		; Output:
		; cx	value at cluster (value before update)
_updateCrossSectorEntry:

	Entry
	def	sectorflag, cx
	def	updatevalue, dx
	def	returnvalue

	mov ax, word [ es:di + ccbData + bx ]		; get value at current sector
	storarg _returnvalue, ax

	shr cx, 1					; even or odd cluster
	jnc _updateCrossSector_20			; even, take value -->

	shl dx, 1
	shl dx, 1
	shl dx, 1
	shl dx, 1
	and dx, byte 0FFF0h
	storarg _updatevalue, dx
	and byte [ es:di + ccbData + bx ], 0Fh		; init area
	or byte [ es:di + ccbData + bx ], dl		; set high value (just the single nibble)
	jmp short _updateCrossSector_22			;

_updateCrossSector_20:
	mov byte [ es:di + ccbData + bx ], dl		; update low order FAT word

		; update next sector
_updateCrossSector_22:
	call CCBChanged

	xor ah, ah
	mov al, byte [ es:di + ccbDrive ]		; ax = drive
	mov cx, word [ es:di + ccbLBN + _high ]
	mov dx, word [ es:di + ccbLBN + _low ]
	inc dx
	adc cx, byte 0					; increase full 32 bit LBN by one
	call readFATBuffer				; read FAT Table
	or byte [ es:di + ccbStatus ], ( ccb_isFAT )

	getarg dx, _updatevalue
	mov ax, word [ es:di + ccbData ]		; get value at current sector
	test word [ _sectorflag + bp ], 1		; even or odd cluster
	jz _updateCrossSector_30			; even, take value -->
	mov byte [ es:ccbData + di ], dh		; set low order value

	xchg ah, al
	mov al, byte [ _returnvalue + bp ]
	shr ax, 1
	shr ax, 1
	shr ax, 1
	shr ax, 1					; return value in ax
	jmp short _updateCrossSector_32			;

_updateCrossSector_30:
	and byte [ es:di + ccbData ], 0F0h		; clear high order
	or byte [ es:di + ccbData ], dh			; update high order FAT word

	xchg ah, al
	mov al, byte [ _returnvalue + bp ]

		; rebuild original value
_updateCrossSector_32:
	push ax
	call CCBChanged

	pop cx
	and cx, 0FFFh
	Return


		; Get FAT12 Table Value
		;
		; Input:
		; ax	drive
		; dx	current cluster
		;
		; Output:
		; dx	value at cluster (next cluster)
		; zr	if end of cluster chain.
_get_12Bit_ClusterValue:

	Entry
	def	drive, ax
	def	cluster, dx
	def	sectorsize
	ddef	sector
	ddef	dpb, es, bx

	mov ax, dx
	add ax, ax
	add ax, dx					; nibble address

	xor dx, dx
	mov cx, word [ es:bx + _dpbBytesPerSector ]
	mov word [ _sectorsize + bp ], cx
	dec word [ _sectorsize + bp ]
	shl cx, 1					; nibbles/sector
	div cx						; sector to read

	; ax will contain sector
	; dx will contain nibble offset

	shr dx, 1					; word offset
	push dx

	xor cx, cx					; 32 bit address
	mov dx, ax
	add dx, word [ es:bx + _dpbFirstFAT ]		; where is first FAT table ?
	stordarg _sector, cx, dx			; 32 bit sector address

	mov ax, word [ _drive + bp ]			; get drive
	call readFATBuffer				; read FAT Table
	or byte [ es:di + ccbStatus ], ( ccb_isFAT )

	pop bx						; word offset into FAT table
	mov dx, word [ es:di + ccbData + bx ]		; get FAT word

	cmp bx, word [ _sectorsize + bp ]		; at sector size -1 boundry ?
	jnz _get_12Bit_ClusterValue_12			; no, ok to return as is -->

	push dx						; else save what we have
	getdarg cx, dx, _sector				; read next cluster sector
	add dx, byte 1					; incr by one
	adc cx, byte 0

	mov ax, word [ _drive + bp ]			; get drive
	call readFATBuffer				; read FAT Table
	or byte [ es:di + ccbStatus ], ( ccb_isFAT )

	pop dx
	mov dh, byte [ es:di + ccbData ]		; get FAT word

_get_12Bit_ClusterValue_12:
	test word [ _cluster + bp ], 1			; is cluster Odd ?
	jz _get_12Bit_ClusterValue_14			; no, just take value -->

	mov cl, 4
	shr dx, cl

_get_12Bit_ClusterValue_14:
	xor cx, cx					; return 0 in high order
	and dx, 0FFFh					; 12 bit mask
	mov ax, dx
	and ax, 0FF8h					; FAT value, 12 bit entries.
	cmp ax, 0FF8h					; end of chain ?
	jnz _get_12Bit_ClusterValue_16			; no -->
	mov dx, -1					; if end, set end value
	mov cx, dx

_get_12Bit_ClusterValue_16:
	getarg ax, _drive
	clc
	Return


		; Delete Cluster Chain (Disk Access Pointer)
		;
		; Removes ENTIRE cluster chain starting at the address passed
		; in the diskAccess block.
		;
		; Input:
		; ds:di-> disk access
		;
		; Output:
		; none
ReleaseClusterChainDskAccess:

	push ax

	mov ax, word [ ss:di + diskAcDrive ]
	mov cx, word [ ss:di + diskAcCurCluster + _high ]
	mov dx, word [ ss:di + diskAcCurCluster + _low ]
	call ReleaseClusterChain

	mov word [ ss:di + diskAcCurCluster + _low ], 0
	mov word [ ss:di + diskAcCurCluster + _high ], 0
	pop ax
	retn


		; Delete Cluster Chain
		;
		; Removes ENTIRE cluster chain starting at the address passed
		; in cx:dx.
		;
		; Input:
		; ax	drive
		; cx:dx	starting cluster value
		;
		; Output:
		; none
ReleaseClusterChain:

	Entry
	ddef	cluster, cx, dx

	saveSegments ax, bx, si, di
	call getAddrDPB					; (es:bx) Device Parameter Block
	jc releaseClusterChain_Return			; if device invalid -->

	cmp word [ es:bx + _dpbSectorsPerFat ], byte 0
	jz releaseClusterChain_32Bits

	mov dx, word [ _cluster + _low + bp ]
	call _FAT16ReleaseClusterChain			; release 16-bits
	mov cx, 0					; insure zero for top 16 bits
	jmp short releaseClusterChain_Return

releaseClusterChain_32Bits:
	getdarg cx, dx, _cluster
	call _FAT32ReleaseClusterChain			; release 32-bits

releaseClusterChain_Return:
	restoreSegments di, si, bx, ax
	Return


		; Delete Cluster Chain (FAT12/FAT16)
		;
		; Removes cluster addressed in dx from FAT tables and
		; returns pointer to next cluster (or FFFF).
		;
		; Input:
		; ax	drive
		; dx	cluster address
		;
		; Output:
		; ZR if end of cluster chain
_FAT16ReleaseClusterChain:

	saveAllRegisters
	call getAddrDPB					; (es:bx) Device Parameter Block
	jc _FAT16ReleaseClusterChain_16			; if device invalid -->

	or dx, dx					; cluster valid ?
	jz _FAT16ReleaseClusterChain_16			; no, exit -->
	cmp dx, word [ es:bx + _dpbMaxClusterNumber ]
	jc _FAT16ReleaseClusterChain_08
	jnz _FAT16ReleaseClusterChain_16		; no, exit -->

_FAT16ReleaseClusterChain_08:
	cmp word [ es:bx + _dpbFreeCount + _low ], byte -1
	jz _FAT16ReleaseClusterChain_12			; if value not initialized -->
	inc word [ es:bx + _dpbFreeCount + _low ]	; increment allocated unit

_FAT16ReleaseClusterChain_12:
	xor cx, cx					; 16-bit drives, ok to pass args in cx
	call _FAT16UpdateClusterValue			; _release cluster at ax:dx
	jz _FAT16ReleaseClusterChain_16			; no more -->

	mov dx, cx					; next cluster
	cmp dx, byte -1					; end of chain ?
	jnz _FAT16ReleaseClusterChain_08		; no -->

_FAT16ReleaseClusterChain_16:
	restoreAllRegisters
	retn


		; Delete Cluster Chain (FAT32)
		;
		; Removes cluster addressed in dx from FAT tables and
		; returns pointer to next cluster (or FFFF).
		;
		; Input:
		; ax	drive
		; cx:dx	cluster address
		;
		; Output:
		; zr	if end of cluster chain.
_FAT32ReleaseClusterChain:

	Entry
	ddef	cluster, cx, dx

	saveAllRegisters
	call getAddrDPB					; (es:bx) Device Parameter Block
	jc _FAT32ReleaseClusterChain_16			; if device invalid -->
	call SeeIfMaxClusters				; at max clusters ?
	jc _FAT32ReleaseClusterChain_16			; invalid -->

	getdarg cx, dx, _cluster
	call isEndOfFAT32
	jz _FAT32ReleaseClusterChain_16

_FAT32ReleaseClusterChain_08:
	add word [ es:bx + _dpbFreeCount + _low ], byte 1	; increment allocated unit
	adc word [ es:bx + _dpbFreeCount + _high ], byte 0
	or word [ es:bx + _dpbxFlags ], byte BPB_FREESPACEALTERED

	mov di, -1
	push di
	push di						; update value is -1
	call _FAT32UpdateClusterValue			; release block
	jnz _FAT32ReleaseClusterChain_08		; keep going till end -->

_FAT32ReleaseClusterChain_16:
	restoreAllRegisters
	Return


		; Find All Free Space
		;
		; Input:
		; ax	drive
		;
		; Output:
		; ax	drive
		; cx:dx	# free clusters
		; es:bx	pointer to DPB
AmountFreeSpace:

	Entry
	def	currcluster
	def	maxclusters
	def	entriesPerSector

	def	drive, ax
	ddef	dpb
	ddef	sector
	ddef	buffer

	ddef	freeclusters, 0, 0

		; if FAT32 drive
	call getDPB					; (es:bx) Device Parameter Block
	stordarg _dpb, es, bx				; save
	ifc amountFreeSpace_Return			; exit if invalid -->

	mov cx, word [ es:bx + _dpbFreeCount + _high ]
	mov dx, word [ es:bx + _dpbFreeCount + _low ]
	stordarg _freeclusters, cx, dx

	cmp word [ es:bx + _dpbSectorsPerFat ], byte 0
	ifz amountFreeSpace_Return

	cmp word [ es:bx + _dpbFreeCount + _low ], byte -1
	ifnz amountFreeSpace_Return

amountFreeSpace_12:
	xor cx, cx
	mov word [ _currcluster + bp ], cx
	mov word [ _freeclusters + _low + bp ], cx
	mov word [ _freeclusters + _high + bp ], cx

	mov dx, word [ es:bx + _dpbMaxClusterNumber ]
	mov word [ _maxclusters + bp ], dx

	test word [ es:bx + _dpbMaxClusterNumber ], 0F000h
	jnz amountFree16BitFAT				; if 16-bit FAT -->

	mov word [ _currcluster + bp ], MINCLUSTER

		; FAT12
amountFree12BitFAT:
	getarg ax, _drive				; restore drive
	getarg dx, _currcluster				; current cluster
	getdarg es, bx, _dpb				; restore dpb
	call _get_12Bit_ClusterValue			; optimized get value

	or dx, dx					; cluster free ?
	jnz amountFree12BitFAT_18			; no -->
	inc word [ _freeclusters + _low + bp ]

amountFree12BitFAT_18:
	inc word [ _currcluster + bp ]			; current cluster
	dec word [ _maxclusters + bp ]			; more clusters to go ?
	jnz amountFree12BitFAT				; yes -->
	jmp short amountFreeSpace_Return

		; FAT16
amountFree16BitFAT:
	mov cx, word [ es:bx + _dpbBytesPerSector ]
	shr cx, 1					; entries per sector
	storarg _entriesPerSector, cx

	xor cx, cx
	mov dx, word [ es:bx + _dpbFirstFAT ]		; where is first FAT table ?
	stordarg _sector, cx, dx
	storarg _currcluster, cx
	add word [ _maxclusters + bp ], byte 2		; adjust for FAT16 entries

	mov ax, word [ _drive + bp ]			; get drive
	call readFATBuffer				; read FAT Table
	stordarg _buffer, es, di			; save buffer address
	or byte [ es:di + ccbStatus ], ( ccb_isFAT )

amountFree16BitFAT_08:
	xor ax, ax
	getarg cx, _entriesPerSector
	mov di, word [ _buffer + _pointer + bp ]
	lea di, [ byte ccbData + di ]			; start of buffer

amountFree16BitFAT_12:
	repne scasw					; search for null word
	jnz amountFree16BitFAT_16			; count is zero -->
	inc word [ _freeclusters + _low + bp ]		; increment free space
	or cx, cx					; more clusters this sector ?
	jnz amountFree16BitFAT_12			; yes -->

amountFree16BitFAT_16:
	mov cx, word [ _entriesPerSector + bp ]
	add cx, word [ _currcluster + bp ]
	mov word [ _currcluster + bp ], cx

	sub cx, word [ _maxclusters + bp ]		; entries to go
	jnc amountFreeSpace_Return			; if at end -->

	neg cx
	cmp cx, word [ _entriesPerSector + bp ]
	jnc amountFree16BitFAT_20
	mov word [ _entriesPerSector + bp ], cx		; max to read last sector

amountFree16BitFAT_20:
	getarg ax, _drive				; get drive
	getdarg es, di, _buffer				; no longer scan through ccb
	inc word [ _sector + bp ]
	getdarg cx, dx, _sector				; get next sector
	call readSelBuffer				; else read buffer (bypass scan)
	jmp short amountFree16BitFAT_08

amountFreeSpace_Return:
	getarg ax, _drive
	getdarg es, bx, _dpb				; restore DPB
	getdarg cx, dx, _freeclusters			; get free clusters
	mov word [ es:bx + _dpbFreeCount + _low ], dx
	mov word [ es:bx + _dpbFreeCount + _high ], cx

	Return


		; Update Free Space on FAT32 Volumes
		;
		; Input:
		; ax	drive
		;
UpdateFreeSpace:

	SaveAllRegisters
	call getAddrDPB					; (es:bx) Device Parameter Block
	jc UpdateFreeSpace_Return			; if drive invalid -->

	cmp word [ es:bx + _dpbSectorsPerFat ], byte 0
	jnz UpdateFreeSpace_Return			; if not FAT32 -->

	test word [ es:bx + _dpbxFlags ], BPB_FREESPACEALTERED
	jz UpdateFreeSpace_Return			; if free space not updated -->

	and word [ es:bx + _dpbxFlags ], byte ~BPB_FREESPACEALTERED
	mov dx, word [ es:bx + _dpbFreeCount + _low ]
	mov cx, word [ es:bx + _dpbFreeCount + _high ]
	mov word [ es:bx + _dpbxFreeClusterCount + _low ], dx
	mov word [ es:bx + _dpbxFreeClusterCount + _high ], cx

		; update FSINFO sector
	mov si, [ es:bx + _dpbxFSINFOSector ]		; check the FSINFO sector
	inc si
	jz UpdateFreeSpace_Return			; (was -1) invalid -->
	dec si
	jz UpdateFreeSpace_Return			; (was 0) invalid -->

	push cx						; (high)
	push dx						; (low ) free space value

	xor cx, cx
	mov dx, si					; free space (FSINFO) sector
	call readBuffer					; read sector

	lea bx, [ di + ccbData + sizeSector - (BIGFATBOOTFSINFO_size) - 4 ]
							; bx now points to the free cluster count structure
	pop word [ bx + _bfFSInfoFreeClusterCnt + _low ]
	pop word [ bx + _bfFSInfoFreeClusterCnt + _high ]

	call updateChangedCCB				; update changed buffer

		; return
UpdateFreeSpace_Return:
	RestoreAllRegisters
	retn


		; Allocate Next Free Cluster
		;
		; Input:
		; ax	drive
		; cx:dx	recommended start search address
		;
		; Output:
		; ax	drive
		; cx:dx	allocated cluster number
		; cy	if end of cluster chain.
AllocateCluster:

	Entry
	def	drive, ax

	ddef	dpb
	ddef	maxclusters
	ddef	cluster, cx, dx
	ddef	origCluster, cx, dx

	call getAddrDPB					; (es:bx) Device Parameter Block
	stordarg _dpb, es, bx				; save _dpb address
	jc allocateCluster_NoneFree			; if device invalid -->

	call GetMaxClusters
	stordarg _maxclusters, cx, dx

		; loop through entire FAT table search for free cluster
allocateCluster_12:
	getarg ax, _drive				; get drive
	getdarg cx, dx, _cluster			; starting cluster
	call getNextCluster				; get value at cluster
	jc allocateCluster_Return			; if error -->

	mov ax, dx
	or ax, cx					; is cluster free ?
	jz allocateCluster_18				; yes -->

	add word [ _cluster + _low + bp ], byte 1	; increment by one
	adc word [ _cluster + _high + bp ], byte 0

	getdarg cx, dx, _cluster
	cmp dx, word [ _origCluster + _low + bp ]	; back at recommended cluster ?
	jnz allocateCluster_14				; no, keep searching -->
	cmp cx, word [ _origCluster + _high + bp ]	; back at recommended cluster ?
	jz allocateCluster_NoneFree			; yes, none are free -->

allocateCluster_14:
	push word [ _maxclusters + _high + bp ]
	push word [ _maxclusters + _low + bp ]
	call _cmp32
	jc allocateCluster_12

	mov word [ _cluster + _low + bp ], MINCLUSTER
	mov word [ _cluster + _high + bp ], 0
	jmp short allocateCluster_12

		; if no space available on disk
allocateCluster_NoneFree:
	stc
	jmp short allocateCluster_Return

		; update allocated buffer
allocateCluster_18:
	mov dx, -1
	push dx
	push dx						; set allocate value 0xFFFFFFFF
	getarg ax, _drive				; get drive
	getdarg cx, dx, _cluster			; get cluster value
	call updateClusterValue				; update value at cluster cx:dx

	getdarg es, bx, _dpb				; get _dpb address
	mov ax, word [ es:bx + _dpbFreeCount + _low ]
	and ax, word [ es:bx + _dpbFreeCount + _high ]	; if both values were FFFF, ax is now too
	inc ax						; if ax were FFFF, it's zero now (and ZR set)
	jz allocateCluster_Return			; value is 0xFFFFFFFF hence don't update it -->

	sub word [ es:bx + _dpbFreeCount + _low ], byte 1	; subtract allocated unit
	sbb word [ es:bx + _dpbFreeCount + _high ], byte 0
	or word [ es:bx + _dpbxFlags ], byte BPB_FREESPACEALTERED

		; return
allocateCluster_Return:
	getarg ax, _drive
	getdarg cx, dx, _cluster			; get cluster value
	getdarg es, bx, _dpb
	Return


		; Allocate/Init A Cluster
		;
		; Note:
		; This function will allocate a cluster and completely fill
		; it with zeroes. Ideal for directories which must have
		; initialized entries.
		;
		; Input:
		; ax	drive
		;
		; Output:
		; ax	drive
		; cx:dx	cluster
		; es:di	pointer to a CCB buffer
AllocateInitCluster:

	Entry
	def	drive, ax
	def	secPerCluster
	ddef	cluster
	ddef	sector

		; allocate a free cluster
	saveRegisters si, bx
	call getAddrDPB					; point to DPB

	mov cx, 1
	add cl, byte [ es:bx + _dpbClusterSizeMask ]
	mov word [ _secPerCluster + bp ], cx

	xor dx, dx
	xor cx, cx					; recommended cluster
	call AllocateCluster				; allocate a cluster
	stordarg _cluster, cx, dx
	jc AllocateInitCluster_12

	call computeLogSectorNumber			; cluster -> sector number
	stordarg _sector, cx, dx			; save sector #

		; allocate a buffer/init

	call SelBuffer					; allocate a buffer
	push di						; pointer to header
	lea di, [ byte ccbData + di ]			; point to buffered data
	clearMemory sizeCCBData				; clear to zeroes
	pop di						; pointer to header

AllocateInitCluster_08:
	call updateChangedCCB				; MUST force write updated buffer

	add word [ es:di + ccbLBN + _low ], byte 1
	adc word [ es:di + ccbLBN + _high ], byte 0
	dec word [ _secPerCluster + bp ]		; continuous write of directory
	jnz AllocateInitCluster_08			;  loops until complete cluster filled

		; return
	getdarg cx, dx, _sector
	mov word [ es:di + ccbLBN + _low ], dx
	mov word [ es:di + ccbLBN + _high ], cx
							; no need to really read the sector at cx:dx
							;  because we just updated it to zero as well
	or cx, cx					; no carry

AllocateInitCluster_12:
	getarg ax, _drive
	getdarg cx, dx, _cluster
	restoreRegisters bx, si
	Return


		; Append a cluster
		;
		; Input:
		; ax	drive
		; cx:dx	last cluster of the former chain (holds EOF)
		;
		; Output:
		; ax	drive
		; cx:dx	new cluster value
AppendCluster:

	Entry
	def	drive, ax
	ddef	cluster, cx, dx
	ddef	allocatedCluster

		; allocate a free cluster
AppendCluster_06:
	push bx
	call AllocateCluster				; allocate a cluster
	jc appendCluster_08				; if error -->

	stordarg _allocatedCluster, cx, dx		; allocated cluster
	
	; We now allocated a new cluster chain (with only one cluster). The end of this
	; short chain is already marked as EOF inside the FAT. We'll now append the short
	; chain to the former chain. The cluster given in cx:dx points to the last cluster
	; in the former chain (it's still marked as EOF inside the FAT).

	push word [ _allocatedCluster + _high + bp ]
	push word [ _allocatedCluster + _low + bp ]
	getdarg cx, dx, _cluster
	call updateClusterValue				; update cluster value
	
	; Now the last cluster of the former chain links to the allocated cluster. The
	; former cluster chain got updated to contain one cluster more.

	getdarg cx, dx, _allocatedCluster		; restore allocated cluster
	or dx, dx					; clear carry

appendCluster_08:
	pop bx
	Return


		; Get Max Clusters
		;
		; Input:
		; ax	drive
		;
		; Output:
		; ax	drive
		; cx:dx	maximal clusters for drive
GetMaxClusters:

	push es
	push bx
	call getAddrDPB
	jc GetMaxClusters_20

	xor cx, cx
	mov dx, word [ es:bx + _dpbMaxClusterNumber ]
	or dx, dx					; if non-zero, small value used
	jnz GetMaxClusters_20

	mov dx, word [ es:bx + _dpbxMaxCluster + _low ]
	mov cx, word [ es:bx + _dpbxMaxCluster + _high ]; else large value

GetMaxClusters_20:
	pop bx
	pop es
	retn


		; See if cluster in range
		;
		; Input:
		; ax	drive
		; cx:dx	cluster number
		;
		; Output:
		; ax	drive
		; cx:dx	max clusters
		; CY if cluster number invalid (below 2 or above max)
		;
SeeIfMaxClusters:
		; Check if given cluster isn't below MINCLUSTER
	or cx, cx
	jnz SeeIfMaxClusters_08				; (could only be < 2 if cx zero) -->
	cmp dx, byte MINCLUSTER
	jc SeeIfMaxClusters_Return			; if below MIN -->

SeeIfMaxClusters_08:
		; Check if given cluster isn't above maximal cluster
	push cx
	push dx						; cx:dx on stack

	call GetMaxClusters
	call _cmp32					; caller's cx:dx still on stack
SeeIfMaxClusters_Return:
	retn


		; Is cluster number end of FAT32 chain
		;
		; INP:	cx:dx = cluster number
		; OUT:	ZR if end of chain (>= 0FFFFFF8h)
		;	NZ if not
		;	NC
isEndOfFAT32:

	push ax
	mov ax, cx
	and ax, 0FFFh					; mask off the FAT32 reserved bits
	cmp ax, 0FFFh					; high value of FAT32 EOF ?
	jnz isEndOfFAT32_Return				; no -->

	mov ax, dx
	and al, 0F8h					; mask off those different EOF bits
	cmp ax, byte 0FFF8h				; low value of FAT32 EOF ?
isEndOfFAT32_Return:
	clc
	pop ax
	retn


		; Compute Logical Sector Number
		;
		; Input:
		; ax	drive
		; cx:dx	cluster number
		;
		; Output:
		; ax	drive
		; cx:dx	logical sector number
computeLogSectorNumber:

	push es
	push bx
	push ax						; drive

	call getAddrDPB					; get first sector address from DPB
	cmp word [ es:bx + _dpbMaxClusterNumber ], byte 0
	jnz computeLogSectorNumber_40			; if not FAT32 -->

		; FAT32 drive
	mov ax, dx
	mov dx, cx

		; LSN in dx:ax

	or cx, ax					; is it root directory ?
							;  (passes LSN 0)
	jnz computeLogSectorNumber_16			; no -->
	mov ax, word [ es:bx + _dpbxRootCluster + _low ]
	mov dx, word [ es:bx + _dpbxRootCluster + _high ]

computeLogSectorNumber_16:
	sub ax, byte 2
	sbb dx, byte 0					; adjust cluster by 2 (min cluster 2)
	mov cx, 1
	add cl, byte [ es:bx + _dpbClusterSizeMask ]
	call _mul32

	add ax, word [ es:bx + _dpbxFirstSector + _low ]
	adc dx, word [ es:bx + _dpbxFirstSector + _high ]

	mov cx, dx					; high part
	mov dx, ax					; low part
	jmp short computeLogSectorNumber_Return

		; FAT16 drive
computeLogSectorNumber_40:
	mov ax, dx					; cluster
	mov dx, word [ es:bx + _dpbFirstDirSector ]	; root directory cluster
	xor cx, cx					; (high part of LSN zero)
	or ax, ax					; if root directory (LSN 0) requested
	jz computeLogSectorNumber_Return		;  then return the value -->

	dec ax
	dec ax						; adjustment because clusters start with 2
	mov cx, 1
	add cl, byte [ es:bx + _dpbClusterSizeMask ]
	mul cx						; compute sector
	add ax, word [ es:bx + _dpbFirstDataSector ]
	adc dx, byte 0
	mov cx, dx					; high part
	mov dx, ax					; low part

computeLogSectorNumber_Return:
	pop ax						; restore drive
	pop bx
	pop es
	retn


		; Read Random Buffer FAT File
		;
		; Input:
		; ss:bx FAT access control block
		; Output:
		; es:bx	pointer in block buffer to data
		; cx	remaining bytes in block
		; zr	means end of file or wrong address
_FATReadRandom:

	Entry
	ddef	accessControl, ss, bx
	ddef	endcluster
	ddef	reqOffset
	def	bytesPerCluster
	ddef	DPBPointer
	ddef	BufferAddress
	def	bytesremain, 0
	def	isnotFAT32				; zero means FAT32

	saveRegisters ds, di, si, dx, ax
	setDS ss
	and word [ diskAcOptions + bx ], ~ (DISKAC_RESULT_READMULTIPLESECTORS)

	mov ax, word [ diskAcDrive + bx ]
	call getAddrDPB					; (es:bx) Device Parameter Block
	stordarg _DPBPointer, es, bx
	ifc _FATReadRandom_Return			; if error, exit -->

	mov ax, word [ es:bx + _dpbSectorsPerFat ]	; is FAT32 drive ?
	storarg _isnotFAT32, ax				; zero means FAT32

		; if request is before start of buffer
	setDS ss
	mov bx, word [ _accessControl + _pointer + bp ]
	mov ax, word [ diskAcPosition + _low + bx ]
	mov dx, word [ diskAcPosition + _high + bx ]
	stordarg _reqOffset, dx, ax

	sub ax, word [ diskAcOffAtBegCluster + _low + bx ]
	sbb dx, word [ diskAcOffAtBegCluster + _high + bx ]
	jae _FATReadRandom_16				; (same as jnb, jnc)

	xor ax, ax
	mov word [ diskAcOffAtBegBuffer + _low + bx ], ax
	mov word [ diskAcOffAtBegBuffer + _high + bx ], ax
	mov word [ diskAcOffAtBegCluster + _low + bx ], ax
	mov word [ diskAcOffAtBegCluster + _high + bx ], ax
	mov word [ diskAcCurCluster + _low + bx ], ax
	mov word [ diskAcCurCluster + _high + bx ], ax

		; locate starting cluster and sector
_FATReadRandom_16:
	mov dx, word [ diskAcCurCluster + _low + bx ]
	or dx, word [ diskAcCurCluster + _high + bx ]
	jnz _FATReadRandom_18
	mov dx, word [ diskAcBegCluster + _low + bx ]
	mov cx, word [ diskAcBegCluster + _high + bx ]
	mov word [ diskAcCurCluster + _low + bx ], dx
	mov word [ diskAcCurCluster + _high + bx ], cx

		; compute a fake sector size if addressing cluster 0 (root dir).
_FATReadRandom_18:
	getdarg es, si, _DPBPointer
	mov ax, word [ es:si + _dpbBytesPerSector ]
	mov cl, byte [ es:si + _dpbClusterSizeShift ]
	shl ax, cl					; bytes per cluster

	mov dx, word [ diskAcBegCluster + _low + bx ]
	or dx, word [ diskAcBegCluster + _high + bx ]
	jnz _FATReadRandom_20
	cmp word [ _isnotFAT32 + bp ], byte 0		; is FAT32 drive ?
	jz _FATReadRandom_20				; if FAT32 drive, keep value in ax -->

	mov ax, word [ es:si + _dpbMaxAllocRootDir ]
	mov cx, sizeDIRENTRY
	mul cx						; compute root directory size in bytes

_FATReadRandom_20:
	mov word [ _bytesPerCluster + bp ], ax

		; see if within current cluster
_FATReadRandom_22:
	mov dx, word [ _reqOffset + _low + bp ]
	mov cx, word [ _reqOffset + _high + bp ]
	sub dx, word [ diskAcOffAtBegCluster + _low + bx ]
	sbb cx, word [ diskAcOffAtBegCluster + _high + bx ]
	jnz _FATReadRandom_24				; if have to scan forward -->
	cmp dx, word [ _bytesPerCluster + bp ]		; beyond cluster size ?
	jc _FATReadRandom_32				; no, within current cluster -->

_FATReadRandom_24:
	mov dx, word [ diskAcCurCluster + _low + bx ]
	mov cx, word [ diskAcCurCluster + _high + bx ]

	mov ax, cx
	or ax, dx					; zero cluster ?
	jnz _FATReadRandom_26				; no, go scan clusters -->

	cmp word [ _isnotFAT32 + bp ], byte 0		; is non FAT32 drive and root directory ?
	ifnz _FATReadRandom_Return			; yes, quit -->

_FATReadRandom_26:
	mov di, bx					; dskAccess to ss:di
	call getNextClusterDskAccess			; get next cluster
	ifz _FATReadRandom_Return			; if end of cluster chain -->

	mov word [ diskAcCurCluster + _low + bx ], dx
	mov word [ diskAcCurCluster + _high + bx ], cx

	mov cx, word [ _bytesPerCluster + bp ]
	add word [ diskAcOffAtBegCluster + _low + bx ], cx
	adc word [ diskAcOffAtBegCluster + _high + bx ], byte 0
	jmp short _FATReadRandom_22

		; see if within current sector
_FATReadRandom_32:
	lds bx, [ _accessControl + bp ]
	mov ax, word [ diskAcDrive + bx ]
	mov dx, word [ diskAcCurCluster + _low + bx ]
	mov cx, word [ diskAcCurCluster + _high + bx ]
	call computeLogSectorNumber			; cluster -> sector number

	push cx
	push dx						; save logical sector number

	mov ax, word [ _reqOffset + _low + bp ]
	mov dx, word [ _reqOffset + _high + bp ]
	sub ax, word [ diskAcOffAtBegCluster + _low + bx ]
	sbb dx, word [ diskAcOffAtBegCluster + _high + bx ]
	div word [ es:si + _dpbBytesPerSector ]

	mov cx, word [ _reqOffset + _low + bp ]
	sub cx, dx					; subtract out remainder
	mov word [ diskAcOffAtBegBuffer + _low + bx ], cx
	mov cx, word [ _reqOffset + _high + bp ]
	mov word [ diskAcOffAtBegBuffer + _high + bx ], cx

	pop dx
	pop cx						; restore LSN
	add dx, ax					; real sector offset
	adc cx, byte 0

		; read sector
	mov ax, word [ diskAcDrive + bx ]
	mov word [ diskAcCurSector + _low + bx ], dx
	mov word [ diskAcCurSector + _high + bx ], cx

	test word [ _reqOffset + _low + bp ], (SIZESECTOR - 1)
	ifnz _FATReadRandom_52				; if not on sector boundary ->
	test word [ diskAcOptions + bx ], DISKAC_READ_MULTIPLESECTORS
	ifz _FATReadRandom_52				; if not multiple sectors ->

		; identify max forward scan clusters
	mov es, word [ diskAcBufferPtr + _segment + bx ]
	mov di, word [ diskAcBufferPtr + _pointer + bx ]
	NormalizeBuffer es, di				; normalize buffer pointer
	stordarg _BufferAddress, es, di

		; compute clusters to read (can't round up)
	xor dx, dx
	mov ax, word [ _bytesPerCluster + bp ]		; wrap up by adding
	dec ax						; bytes per cluster - 1
	add ax, word [ diskAcBytesToRead + bx ]		; allow max requested
	adc dx, byte 0
	div word [ _bytesPerCluster + bp ]		; compute max clusters to scan

	push ax						; max clusters to scan
	mov ax, word [ diskAcDrive + bx ]
	mov dx, word [ diskAcCurCluster + _low + bx ]
	mov cx, word [ diskAcCurCluster + _high + bx ]
	call scanClusterMap				; number contiguous clusters
	stordarg _endcluster, cx, dx

	xor dx, dx
	mul word [ _bytesPerCluster + bp ]		; compute total bytes to read

	or dx, dx
	jnz _FATReadRandom_40				; if > 64 KiB, drop down to actual request
	cmp ax, word [ diskAcBytesToRead + bx ]		; more than requested ?
	jc _FATReadRandom_42				; no -->

_FATReadRandom_40:
	mov ax, word [ diskAcBytesToRead + bx ]		; limit to requested size

_FATReadRandom_42:
	xor dx, dx
	mov cx, SIZESECTOR				; into sectors
	div cx						; sectors to read

	getdarg es, di, _BufferAddress
	or word [ diskAcOptions + bx ], DISKAC_RESULT_READMULTIPLESECTORS
	mov dx, word [ diskAcCurSector + _low + bx ]
	mov cx, word [ diskAcCurSector + _high + bx ]
	mov bx, word [ diskAcDrive + bx ]
	xchg ax, bx
	call DevRead

	mov ax, SIZESECTOR				; sector size
	mul cx						; actual sectors read
	storarg _bytesremain, ax			; actual bytes returned

	getdarg es, di, _BufferAddress
	jmp short _FATReadRandom_Return			; return bytes read

		; read sector (unoptimized read)
_FATReadRandom_52:
	mov ax, word [ diskAcDrive + bx ]
	mov dx, word [ diskAcCurSector + _low + bx ]
	mov cx, word [ diskAcCurSector + _high + bx ]
	call readBuffer					; read sector
	mov ax, word [ diskAcOptions + bx ]
	or byte [ es:di + ccbStatus ], al		; type of block

	lea di, [ byte ccbData + di ]			; point to data
	mov word [ diskAcBufferPtr + _segment + bx ], es
	mov word [ diskAcBufferPtr + _pointer + bx ], di

		; return pointer
_FATReadRandom_60:
	lds bx, [ _accessControl + bp ]
	les si, [ _DPBPointer + bp ]
	mov cx, word [ es:si + _dpbBytesPerSector ]

	mov ax, word [ _reqOffset + _low + bp ]
	mov dx, word [ _reqOffset + _high + bp ]
	sub ax, word [ diskAcOffAtBegBuffer + _low + bx ]
	sbb dx, word [ diskAcOffAtBegBuffer + _high + bx ]

	les bx, [ diskAcBufferPtr + bx ]
	add bx, ax					; offset into buffer
	sub cx, ax					; bytes remaining in buffer
	storarg _bytesremain, cx

		; return
_FATReadRandom_Return:
	restoreRegisters ax, dx, si, di, ds
	getarg cx, _bytesremain
	or cx, cx
	Return
