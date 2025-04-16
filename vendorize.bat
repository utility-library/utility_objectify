@echo off
setlocal

if "%~1"=="" (
    echo Drag and drop a folder onto this .bat file.
    pause
    exit /b
)

set "TARGET=%~1"

set "CLIENT_SRC=%~dp0client\api.lua"
set "SERVER_SRC=%~dp0server\api.lua"

set "CLIENT_DIR=%TARGET%\client"
set "SERVER_DIR=%TARGET%\server"
set "CLIENT_DEST=%CLIENT_DIR%\api.lua"
set "SERVER_DEST=%SERVER_DIR%\api.lua"

if not exist "%CLIENT_DIR%" mkdir "%CLIENT_DIR%"
if not exist "%SERVER_DIR%" mkdir "%SERVER_DIR%"

>nul fsutil hardlink create "%CLIENT_DEST%" "%CLIENT_SRC%"
>nul fsutil hardlink create "%SERVER_DEST%" "%SERVER_SRC%"

echo Vendorized!
pause
