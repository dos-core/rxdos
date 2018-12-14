#! /bin/bash

# Usage of the works is permitted provided that this
# instrument is retained with the works, so that any entity
# that uses the works is notified of this instrument.
#
# DISCLAIMER: THE WORKS ARE WITHOUT WARRANTY.

export NASMENV="$@"

function nasmbin() {
	nasm -Ox -D_REVISIONID="'$build_revision_id'" -i../MACRO/ -I../bin/ -I../lmacros/ -I../../lmacros/ -d__MAPFILE__=../map/$1.MAP -l../lst/$1.LST -fbin -o../bin/$2.$3 $1.ASM
}
function nasmobj() {
	nasm -Ox -D_REVISIONID="'$build_revision_id'" -i../MACRO/ -l../lst/$1.LST -fobj -o../obj/$1.OBJ $1.ASM
}

(($use_build_revision_id)) &&
  if [ -z "$build_revision_id" ]; then {
    build_revision_id="hg $(hg id -i)"
  } fi

cd "${0%/*}"
toolsdir="${PWD}/../dostools"
((debug)) && echo "toolsdir=\"$toolsdir\""


cd RxAPP
if [ -f RxVDISK.ASM ]; then {
	echo Building RxVDISK
	nasmbin RxVDISK RxVDISK SYS || exit
} fi

cd ../ldosboot
echo Building boot12, boot16, boot32
NAME=RXDOS
SUFFIX=""
for FAT in 12 16; do
	nasm -D_COMPAT_LDOS -D_LOAD_NAME="'$NAME'" -D_CHS=1 -D_LBA_SKIP_CHECK \
		-D_USE_PART_INFO=1 -D_QUERY_GEOMETRY=1 -D_FAT$FAT=1 boot.asm \
		-o boot${FAT}${SUFFIX}.bin -D_MAP=boot${FAT}${SUFFIX}.map \
		-l boot${FAT}${SUFFIX}.lst -I../lmacros/
	done
nasm -D_COMPAT_LDOS -D_LOAD_NAME="'$NAME'" -D_CHS=1 -D_LBA_SKIP_CHECK \
	-D_USE_PART_INFO=1 -D_QUERY_GEOMETRY=1 boot32.asm \
	-o boot32${SUFFIX}.bin -D_MAP=boot32${SUFFIX}.map \
	-l boot32${SUFFIX}.lst -I../lmacros/

cd ../instsect
echo Building instsect.com
nasm instsect.asm -D_MAP=instsect.map -l instsect.lst \
	-I../gopt/ -I../ldosboot/ -I../lmacros/ -o instsect.com "$@"

cd ../ldos
echo Building RxDOS.COM
nasm -Ox -D_REVISIONID="'$build_revision_id'" \
	-I ../lmacros/ -I ../../lmacros/ -I ../MACRO/ -I ../RxBIO/ \
	-I ../instsect/ -I ../bin/ \
	-I ../RxDOS/ -f bin -D_BIN_FILE_DEFAULT=RXDOS.COM \
	-o lDOSLOAD.BIN -l lDOSLOAD.LST init.asm \
&& nasm -Ox -D_REVISIONID="'$build_revision_id'" \
	-D_IMAGE_EXE_MAX=0 \
	-D_IMAGE_EXE -D_IMAGE_EXE_AUTO_STACK -D_EXEC_OFFSET=32 \
	-D_IMAGE_EXE_MIN_CALC="(((_IMAGE_EXE_AUTO_STACK) + 15) & ~15)" \
	-I ../lmacros/ -f bin -o ../bin/RxDOS.COM -l ../lst/RxDOS.LST \
	-D_MAP=../map/RxDOS.MAP ../ldosboot/iniload.asm \
|| exit

cd ../inicomp

echo Building compressed RxDOSBLZ.COM
blzpack ../ldos/lDOSLOAD.BIN lDOSLOAD.BLZ
nasm inicomp.asm -o iniblz.bin -D_MAP=iniblz.map -l iniblz.lst -D_BRIEFLZ \
	-I ../lmacros/ -D_IMAGE_EXE -D_IMAGE_EXE_AUTO_STACK -D_EXEC_OFFSET=32 \
&& nasm -Ox -D_REVISIONID="'$build_revision_id'" \
	-D_IMAGE_EXE_MAX=0 \
	-D_IMAGE_EXE -D_IMAGE_EXE_AUTO_STACK -D_EXEC_OFFSET=32 \
	-D_IMAGE_EXE_MIN_CALC="((($(stat -c %s ../ldos/lDOSLOAD.BIN) + \
		_IMAGE_EXE_AUTO_STACK) + 15) & ~15)" \
	-I ../lmacros/ -f bin -o ../bin/RxDOSBLZ.COM -l ../lst/RxDOSBLZ.LST \
	-D_MAP=../map/RxDOSBLZ.MAP ../ldosboot/iniload.asm \
	-D_PAYLOAD_FILE=iniblz.bin

echo Building compressed RxDOSLZ4.COM
lz4c -9zfk -hc ../ldos/lDOSLOAD.BIN lDOSLOAD.LZ4
nasm inicomp.asm -o inilz4.bin -D_MAP=inilz4.map -l inilz4.lst -D_LZ4 \
	-I ../lmacros/ -D_IMAGE_EXE -D_IMAGE_EXE_AUTO_STACK -D_EXEC_OFFSET=32 \
&& nasm -Ox -D_REVISIONID="'$build_revision_id'" \
	-D_IMAGE_EXE_MAX=0 \
	-D_IMAGE_EXE -D_IMAGE_EXE_AUTO_STACK -D_EXEC_OFFSET=32 \
	-D_IMAGE_EXE_MIN_CALC="((($(stat -c %s ../ldos/lDOSLOAD.BIN) + \
		_IMAGE_EXE_AUTO_STACK) + 15) & ~15)" \
	-I ../lmacros/ -f bin -o ../bin/RxDOSLZ4.COM -l ../lst/RxDOSLZ4.LST \
	-D_MAP=../map/RxDOSLZ4.MAP ../ldosboot/iniload.asm \
	-D_PAYLOAD_FILE=inilz4.bin

cd ../RxCMD
if [ -f RxCMD.ASM -a \
	-f RxCMDCPY.ASM -a \
	-f RxCMDDIR.ASM -a \
	-f RxCMDFOR.ASM -a \
	-f RxCMDPRM.ASM -a \
	-f RxCMDREN.ASM ]; then
{
  if ((!_BUILD_OBJ)); then {
	echo Building RxCMD
	nasmbin RxCMD RxCMD EXE || exit
  } else {
	echo Building RxCMD
	for x in RxCMD RxCMDCPY RxCMDDIR RxCMDFOR \
	RxCMDPRM RxCMDREN; do
		nasmobj "$x" || exit
	done

	cd ../obj
	echo "/s /mx /xt +" > warplink.lin

	for x in RxCMDCPY RxCMDDIR RxCMDFOR \
	RxCMDPRM RxCMDREN RxCMD; do
		echo "$x.OBJ +" >> warplink.lin
	done
	echo ",..\\bin\\RxCMD.EXE,..\\map\\RxCMD.MAP,;" >> warplink.lin

	unix2dos -q warplink.lin
	cd ..
	dosemu -q -dumb -E "doscmd.bat $(realpath "$toolsdir" |
sed -re 's/\//\\/g') WARPLINK.EXE obj @warplink.lin" || exit

	cd obj
	rm warplink.lin
  } fi
} fi

cd ../doc
echo Building doc
./makdoc

cd ..

