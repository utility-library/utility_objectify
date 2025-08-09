@echo off
setlocal

if "%~1"=="" (
    echo Drag and drop a folder onto this .bat file.
    pause
    exit /b
)

set "TARGET=%~1"

set "SHARED_SRC=%~dp0shared\api.lua"
set "SHARED_DIR=%TARGET%\shared"
set "SHARED_DEST=%SHARED_DIR%\objectify.lua"

if not exist "%SHARED_DIR%" mkdir "%SHARED_DIR%"

>nul fsutil hardlink create "%SHARED_DEST%" "%SHARED_SRC%"

echo Vendorized!
pause

