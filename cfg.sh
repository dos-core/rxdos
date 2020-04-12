#! /bin/bash

# Usage of the works is permitted provided that this
# instrument is retained with the works, so that any entity
# that uses the works is notified of this instrument.
#
# DISCLAIMER: THE WORKS ARE WITHOUT WARRANTY.

# If you want to override configuration without the
# hassle of having to exclude differences in this file
# (cfg.sh) from the SCM, you may provide ovr.sh.
[ -f ovr.sh ] && . ovr.sh

# As the below only are set if no value is provided
# yet, any value can be overridden from the shell.
[ -z "$LMACROS_DIR" ] && LMACROS_DIR=lmacros/
[ -z "$INSTSECT_DIR" ] && INSTSECT_DIR=instsect/
[ -z "$LDOSBOOT_DIR" ] && LDOSBOOT_DIR=ldosboot/
[ -z "$SCANPTAB_DIR" ] && SCANPTAB_DIR=scanptab/
[ -z "$INICHECK_DIR" ] && INICHECK_DIR=crc16-t/
[ -z "$INICOMP_DIR" ] && INICOMP_DIR=inicomp/
[ -z "$INICOMP_METHOD" ] && INICOMP_METHOD="brieflz lz4 snappy exodecr x heatshrink"
	# none or brieflz or lz4 or snappy or exodecr or x or heatshrink
[ -z "$INICOMP_BLZPACK" ] && INICOMP_BLZPACK=blzpack
[ -z "$INICOMP_LZ4C" ] && INICOMP_LZ4C=lz4c
[ -z "$INICOMP_SNZIP" ] && INICOMP_SNZIP=snzip
[ -z "$INICOMP_EXOMIZER" ] && INICOMP_EXOMIZER=exomizer
[ -z "$INICOMP_X" ] && INICOMP_X=x
[ -z "$INICOMP_HEATSHRINK" ] && INICOMP_HEATSHRINK=heatshrink
[ -z "$INICOMP_LZIP" ] && INICOMP_LZIP=lzip

[ -z "$NASM" ] && NASM=nasm
[ -z "$CHECKSUM" ] && CHECKSUM="${INICHECK_DIR%/}"/iniload/checksum

[ -z "$use_build_revision_id" ] && use_build_revision_id=1
[ -z "$use_build_decomp_test" ] && use_build_decomp_test=0
[ -z "$use_build_inicheck" ] && use_build_inicheck=0
