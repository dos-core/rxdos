@echo off

:: Usage of the works is permitted provided that this
:: instrument is retained with the works, so that any entity
:: that uses the works is notified of this instrument.
::
:: DISCLAIMER: THE WORKS ARE WITHOUT WARRANTY.

:: %1 = (full linux) path to executable
:: %2 = filename of executable
:: linux cwd = top-level cwd
:: %3 = sub-cwd below the top-level cwd
:: %4+ = parameters for command
lredir X: linux\fs%1 ro > nul
set /E UCWD=unix -w
lredir Y: linux\fs%UCWD% > nul
Y:
cd Y:\%3
X:\%2 %4 %5 %6 %7 %8 %9
exitemu
