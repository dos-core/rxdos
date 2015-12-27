#! /bin/bash

NASMENV="$@"

function nasmbin() {
	nasm -O0 -i../MACRO/ -d__MAPFILE__=../map/$1.MAP -l../lst/$1.LST -fbin -o../bin/$2.$3 $1.ASM
}
function nasmobj() {
	nasm -O0 -i../MACRO/ -l../lst/$1.LST -fobj -o../obj/$1.OBJ $1.ASM
}

cd "${0%/*}"
toolsdir="${PWD}/../dostools"
((debug)) && echo "toolsdir=\"$toolsdir\""

cd RxBIO
if [ -f RxBIO.ASM ]; then {
	echo Building RxBIO
	nasmbin RxBIO RXBIO SYS || exit
} fi


cd ../RxAPP
if [ -f RxVDISK.ASM ]; then {
	echo Building RxVDISK
	nasmbin RxVDISK RXVDISK SYS || exit
} fi

if [ -f RxBOOT.ASM ]; then {
	echo Building RxBOOT
	nasmbin RxBOOT RXBOOT SYS || exit
} fi

if [ -f RxMBR.ASM ]; then {
	echo Building RxMBR
	nasmbin RxMBR RXMBR SYS || exit
} fi

if [ -f RxD_BOOT.ASM ]; then {
	echo Building RxD_BOOT
	nasmbin RxD_BOOT RXD_BOOT SYS || exit
	if [ -f ../bin/RXBOOT.SYS ]; then {
	cat ../bin/RXD_BOOT.SYS ../bin/RXBOOT.SYS > ../bin/RXD_BOOT.COM
	} fi
} fi


cd ../RxDOS
if [ -f RxDOS.ASM -a \
	-f RxDOSCCB.ASM -a \
	-f RxDOSDEV.ASM -a \
	-f RxDOSEXE.ASM -a \
	-f RxDOSFAT.ASM -a \
	-f RxDOSFCB.ASM -a \
	-f RxDOSFIL.ASM -a \
	-f RxDOSLFN.ASM -a \
	-f RxDOSF32.ASM -a \
	-f RxDOSIFS.ASM -a \
	-f RxDOSMEM.ASM -a \
	-f RxDOSSFT.ASM -a \
	-f RxDOSSTR.ASM -a \
	-f RxDOSCTB.ASM -a \
	-f RxDOSERR.ASM -a \
	-f RxDOSINI.ASM ]; then {
	echo Building RxDOS
	for x in RxDOS RxDOSCCB RxDOSDEV RxDOSEXE RxDOSFAT RxDOSFCB RxDOSFIL \
		RxDOSLFN RxDOSF32 RxDOSIFS RxDOSMEM RxDOSSFT RxDOSSTR \
		RxDOSCTB RxDOSERR RxDOSINI; do
		nasmobj "$x" || exit;
	done

	echo > STACK\$\$.ASM
	echo	segment STACK\$\$ align=16 class=RXDOS use16 stack >> STACK\$\$.ASM
	echo			resw 1 >> STACK\$\$.ASM
	echo >> STACK\$\$.ASM
	nasm -fobj -o../obj/STACK\$\$.OBJ STACK\$\$.ASM || exit
	rm STACK\$\$.ASM

	cd ../obj

	echo "/s /mx /xt +" > warplink.lin
		for x in RxDOS RxDOSCCB RxDOSDEV RxDOSEXE RxDOSFAT RxDOSFCB RxDOSFIL \
			RxDOSLFN RxDOSF32 RxDOSIFS RxDOSMEM RxDOSSFT RxDOSSTR \
			RxDOSCTB RxDOSERR RxDOSINI; do
			echo $x.OBJ + >> warplink.lin
		done

	echo "STACK\$\$.OBJ,RxDOS.EXE,RxDOS.MAP,;" >> warplink.lin

	prevpwd="${PWD}"
	mkdir -p "$toolsdir/tmp"
	cp warplink.lin "$toolsdir/tmp"
	cp "$toolsdir/WARPLINK.EXE" "$toolsdir/tmp"
	for x in RxDOS RxDOSCCB RxDOSDEV RxDOSEXE RxDOSFAT RxDOSFCB RxDOSFIL \
		RxDOSLFN RxDOSF32 RxDOSIFS RxDOSMEM RxDOSSFT RxDOSSTR \
		RxDOSCTB RxDOSERR RxDOSINI; do
		cp "../obj/$x.OBJ" "$toolsdir/tmp"
	done
	cp "STACK\$\$.OBJ" "$toolsdir/tmp"
	cd "$toolsdir/tmp"
	unix2dos -q warplink.lin
	dosemu -dumb WARPLINK.EXE @warplink.lin || exit
	cp rxdos.exe "$prevpwd/../bin/RxDOS.EXE"
	cp rxdos.map "$prevpwd/../map/RxDOS.MAP"

	cp "$toolsdir/X2B_IGNR.COM" "$toolsdir/tmp"
#	exe2bin -r -l=0 RxDOS.EXE ..\bin\RXDOS.SYS || exit
#	exe2bin -x -r -l=0 RxDOS.EXE ../bin/RXDOS.SYS || exit
	dosemu -dumb X2B_IGNR.COM RxDOS.EXE RXDOS.SYS || exit

	cp rxdos.sys "$prevpwd/../bin/RXDOS.SYS"
	cd "$prevpwd"
	rm warplink.lin
	rm STACK\$\$.OBJ
} fi


cd ../RxCMD
if [ -f RxCMD.ASM -a \
	-f RxCMDCPY.ASM -a \
	-f RxCMDDIR.ASM -a \
	-f RxCMDFOR.ASM -a \
	-f RxCMDPRM.ASM -a \
	-f RxCMDREN.ASM ]; then
{
	echo Building RxCMD
	for x in RxCMD RxCMDCPY RxCMDDIR RxCMDFOR \
	RxCMDPRM RxCMDREN; do
		nasmobj "$x" || exit
	done
	
	echo > STACK\$\$.ASM
	echo	segment STACK\$\$ align=16 class=RXDOS use16 stack >> STACK\$\$.ASM
	echo			resw 1 >> STACK\$\$.ASM
	echo >> STACK\$\$.ASM
	nasm -fobj -o../obj/STACK\$\$.OBJ STACK\$\$.ASM || exit
	rm STACK\$\$.ASM


	cd ../obj
	echo "/s /mx /xt +" > warplink.lin

	for x in RxCMDCPY RxCMDDIR RxCMDFOR \
	RxCMDPRM RxCMDREN RxCMD; do
		echo "$x.OBJ +" >> warplink.lin
	done
	echo "STACK\$\$.OBJ,RXCMD.EXE,RxCMD.MAP,;" >> warplink.lin

	prevpwd="${PWD}"
	mkdir -p "$toolsdir/tmp"
	cp warplink.lin "$toolsdir/tmp"
	cp "$toolsdir/WARPLINK.EXE" "$toolsdir/tmp"
	for x in RxCMD RxCMDCPY RxCMDDIR RxCMDFOR \
	RxCMDPRM RxCMDREN; do
		cp "../obj/$x.OBJ" "$toolsdir/tmp"
	done
	cp "STACK\$\$.OBJ" "$toolsdir/tmp"
	cd "$toolsdir/tmp"
	unix2dos -q warplink.lin
	dosemu -dumb WARPLINK.EXE @warplink.lin || exit
	cp rxcmd.exe "$prevpwd/../bin/RxCMD.EXE"
	cp rxcmd.map "$prevpwd/../map/RxCMD.MAP"

	cd "$prevpwd"
	rm warplink.lin
	rm STACK\$\$.OBJ
} fi

cd ..

