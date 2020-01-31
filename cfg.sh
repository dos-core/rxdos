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
[ -z "$INICOMP_METHOD" ] && INICOMP_METHOD=lz4
					# none or lz4 or brieflz or snappy
[ -z "$INICOMP_LZ4C" ] && INICOMP_LZ4C=lz4c
[ -z "$INICOMP_SNZIP" ] && INICOMP_SNZIP=snzip
[ -z "$INICOMP_BLZPACK" ] && INICOMP_BLZPACK=blzpack

[ -z "$NASM" ] && NASM=nasm
[ -z "$CHECKSUM" ] && CHECKSUM="${INICHECK_DIR%/}"/iniload/checksum

[ -z "$use_build_revision_id" ] && use_build_revision_id=1
[ -z "$use_build_decomp_test" ] && use_build_decomp_test=0
[ -z "$use_build_inicheck" ] && use_build_inicheck=0
