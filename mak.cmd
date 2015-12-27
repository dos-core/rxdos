@echo %DEBUG%off

set NASMENV=%1 %2 %3 %4 %5 %6 %7 %8 %9

echo.@echo %%DEBUG%%off > %TEMP%\nasmbin.cmd
echo.nasm -O0 -i..\MACRO\ -d__MAPFILE__=..\map\%%1.MAP -l..\lst\%%1.LST -fbin -o..\bin\%%2.%%3 %%1.ASM >> %TEMP%\nasmbin.cmd
echo.@echo %%DEBUG%%off > %TEMP%\nasmobj.cmd
echo.nasm -O0 -i..\MACRO\ -l..\lst\%%1.LST -fobj -o..\obj\%%1.OBJ %%1.ASM >> %TEMP%\nasmobj.cmd

cd RxBIO

:bio
if not exist RxBIO.ASM goto nobio
echo.Building RxBIO
call %TEMP%\nasmbin.cmd RxBIO RXBIO SYS
if errorlevel 1 goto end
:nobio

cd ..\RxAPP

:vdisk
if not exist RxVDISK.ASM goto novdisk
echo.Building RxVDISK
call %TEMP%\nasmbin.cmd RxVDISK RXVDISK SYS
if errorlevel 1 goto end
:novdisk

:boot
if not exist RxBOOT.ASM goto noboot
echo.Building RxBOOT
call %TEMP%\nasmbin.cmd RxBOOT RXBOOT SYS
if errorlevel 1 goto end
:noboot

:mbr
if not exist RxMBR.ASM goto nombr
echo.Building RxMBR
call %TEMP%\nasmbin.cmd RxMBR RXMBR SYS
if errorlevel 1 goto end
:nombr

:d_boot
if not exist RxD_BOOT.ASM goto nod_boot
echo.Building RxD_BOOT
call %TEMP%\nasmbin.cmd RxD_BOOT RXD_BOOT SYS
if errorlevel 1 goto end
copy /y /b ..\bin\RXD_BOOT.SYS + ..\bin\RXBOOT.SYS ..\bin\RXD_BOOT.COM > nul
:nod_boot

cd ..\RxDOS

:dos
if not exist RxDOS.ASM goto nodos
if not exist RxDOSCCB.ASM goto nodos
if not exist RxDOSDEV.ASM goto nodos
if not exist RxDOSEXE.ASM goto nodos
if not exist RxDOSFAT.ASM goto nodos
if not exist RxDOSFCB.ASM goto nodos
if not exist RxDOSFIL.ASM goto nodos
if not exist RxDOSLFN.ASM goto nodos
if not exist RxDOSF32.ASM goto nodos
if not exist RxDOSIFS.ASM goto nodos
if not exist RxDOSMEM.ASM goto nodos
if not exist RxDOSSFT.ASM goto nodos
if not exist RxDOSSTR.ASM goto nodos
if not exist RxDOSCTB.ASM goto nodos
if not exist RxDOSERR.ASM goto nodos
if not exist RxDOSINI.ASM goto nodos
echo.Building RxDOS

call %TEMP%\nasmobj.cmd RxDOS
if errorlevel 1 goto end
call %TEMP%\nasmobj.cmd RxDOSCCB
if errorlevel 1 goto end
call %TEMP%\nasmobj.cmd RxDOSDEV
if errorlevel 1 goto end
call %TEMP%\nasmobj.cmd RxDOSEXE
if errorlevel 1 goto end
call %TEMP%\nasmobj.cmd RxDOSFAT
if errorlevel 1 goto end
call %TEMP%\nasmobj.cmd RxDOSFCB
if errorlevel 1 goto end
call %TEMP%\nasmobj.cmd RxDOSFIL
if errorlevel 1 goto end
call %TEMP%\nasmobj.cmd RxDOSLFN
if errorlevel 1 goto end
call %TEMP%\nasmobj.cmd RxDOSF32
if errorlevel 1 goto end
call %TEMP%\nasmobj.cmd RxDOSIFS
if errorlevel 1 goto end
call %TEMP%\nasmobj.cmd RxDOSMEM
if errorlevel 1 goto end
call %TEMP%\nasmobj.cmd RxDOSSFT
if errorlevel 1 goto end
call %TEMP%\nasmobj.cmd RxDOSSTR
if errorlevel 1 goto end
call %TEMP%\nasmobj.cmd RxDOSCTB
if errorlevel 1 goto end
call %TEMP%\nasmobj.cmd RxDOSERR
if errorlevel 1 goto end
call %TEMP%\nasmobj.cmd RxDOSINI
if errorlevel 1 goto end

echo. > STACK$$.ASM
echo.	segment STACK$$ align=16 class=RXDOS use16 stack >> STACK$$.ASM
echo.			resw 1 >> STACK$$.ASM
echo. >> STACK$$.ASM
nasm -fobj -o..\obj\STACK$$.OBJ STACK$$.ASM
if errorlevel 1 goto end
del STACK$$.ASM


cd ..\obj

if not (%USEALINK%)==() goto :dosalink

:doswarplink
echo. /s /mx /xt + > warplink.lin
for %%x in (RxDOS.OBJ RxDOSCCB.OBJ RxDOSDEV.OBJ RxDOSEXE.OBJ RxDOSFAT.OBJ RxDOSFCB.OBJ RxDOSFIL.OBJ RxDOSLFN.OBJ RxDOSF32.OBJ RxDOSIFS.OBJ RxDOSMEM.OBJ RxDOSSFT.OBJ RxDOSSTR.OBJ RxDOSCTB.OBJ RxDOSERR.OBJ RxDOSINI.OBJ) do echo.%%x + >> warplink.lin

echo. STACK$$.OBJ,RxDOS.EXE,..\map\RxDOS.MAP,; >> warplink.lin

warplink @warplink.lin
if errorlevel 1 goto end
del warplink.lin
goto :doslinkdone

:dosalink

alink -oEXE -o RxDOS.EXE -p- -m+ -c+ RxDOS.OBJ RxDOSCCB.OBJ RxDOSDEV.OBJ RxDOSEXE.OBJ RxDOSFAT.OBJ RxDOSFCB.OBJ RxDOSFIL.OBJ RxDOSLFN.OBJ RxDOSF32.OBJ RxDOSIFS.OBJ RxDOSMEM.OBJ RxDOSSFT.OBJ RxDOSSTR.OBJ RxDOSCTB.OBJ RxDOSERR.OBJ RxDOSINI.OBJ STACK$$.OBJ
if errorlevel 1 goto end

:doslinkdone
del STACK$$.OBJ

::exe2bin -r -l=0 RxDOS.EXE ..\bin\RXDOS.SYS

exe2bin -x -r -l=0 RxDOS.EXE ..\bin\RXDOS.SYS
if errorlevel 1 goto end

:nodos

cd ..\RxCMD

:cmd
if not exist RxCMD.ASM goto nocmd
if not exist RxCMDCPY.ASM goto nocmd
if not exist RxCMDDIR.ASM goto nocmd
if not exist RxCMDFOR.ASM goto nocmd
if not exist RxCMDPRM.ASM goto nocmd
if not exist RxCMDREN.ASM goto nocmd
echo.Building RxCMD

call %TEMP%\nasmobj.cmd RxCMD
if errorlevel 1 goto end
call %TEMP%\nasmobj.cmd RxCMDCPY
if errorlevel 1 goto end
call %TEMP%\nasmobj.cmd RxCMDDIR
if errorlevel 1 goto end
call %TEMP%\nasmobj.cmd RxCMDFOR
if errorlevel 1 goto end
call %TEMP%\nasmobj.cmd RxCMDPRM
if errorlevel 1 goto end
call %TEMP%\nasmobj.cmd RxCMDREN
if errorlevel 1 goto end

echo. > STACK$$.ASM
echo.	segment STACK$$ align=16 class=RXDOS use16 stack >> STACK$$.ASM
echo.			resw 1 >> STACK$$.ASM
echo. >> STACK$$.ASM
nasm -fobj -o..\obj\STACK$$.OBJ STACK$$.ASM
if errorlevel 1 goto end
del STACK$$.ASM


cd ..\obj

if not (%USEALINK%)==() goto :cmdalink

:cmdwarplink
echo. /s /mx /xt + > warplink.lin
for %%x in (RxCMDCPY.OBJ RxCMDDIR.OBJ RxCMDFOR.OBJ RxCMDPRM.OBJ RxCMDREN.OBJ RxCMD.OBJ) do echo.%%x + >> warplink.lin

echo. STACK$$.OBJ,..\bin\RXCMD.EXE,..\map\RxCMD.MAP,; >> warplink.lin

warplink @warplink.lin
if errorlevel 1 goto end
del warplink.lin
goto :cmdlinkdone

:cmdalink

alink -oEXE -o ..\bin\RXCMD.EXE -p- -m+ -c+ RxCMDCPY.OBJ RxCMDDIR.OBJ RxCMDFOR.OBJ RxCMDPRM.OBJ RxCMDREN.OBJ RxCMD.OBJ
if errorlevel 1 goto end

:cmdlinkdone
del STACK$$.OBJ

:nocmd

cd ..
goto :eof

:end
if exist warplink.lin del warplink.lin
cd ..
:eof
