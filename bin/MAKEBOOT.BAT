@echo %DEBUG%off
echo.
echo.
echo. Create an RxDOS boot floppy
echo.------------------------------------------

if %1x==x goto Help

if %1==a: goto GoMake
if %1==A: goto GoMake
if %1==b: goto GoMake
if %1==B: goto GoMake
goto Help

:GoMake
if not exist RXD_BOOT.COM goto Cant_Copy
if not exist RXBIO.SYS goto Cant_Copy
if not exist RXDOS.SYS goto Cant_Copy
if not exist RXCMD.EXE goto Cant_Copy

echo.
echo. Do you want to write to disk %1 ?
echo. (Control-C to abort)
pause

dir /w %1
echo.
echo. Disk in drive %1: should not have any files
echo. and should be formatted.  This above directory
echo. will help you to decide whether you need to delete
echo. any files.
echo. 
echo. If there are any files you must delete them. Continue ?
echo. (Control-C to abort)
pause

echo.
echo. RxD_BOOT now installs the RxBOOT boot sector.
RXD_BOOT.COM /S %1
if errorlevel 4 goto Diskerror
:: errorlevel 4 in silent mode means disk error occured

echo.
echo. Copying system files.
copy RXBIO.SYS %1
copy RXDOS.SYS %1
copy RXCMD.EXE %1

echo.
echo. Copying completed.
dir /w %1
goto Done

:Diskerror
echo.
echo. Error writing the boot sector.
goto Done

:Cant_Copy
echo.
echo. Could not find one or more of these files:
echo.   RXBIO.SYS, RXDOS.SYS, RXCMD.EXE, RXD_BOOT.COM
echo.
echo. These files must all reside in the current directory.
goto Done

:Help
echo.
echo. Usage:
echo.
echo. makeboot drive:
echo.
echo. drive: is either A: or B:

:Done
