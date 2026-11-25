@echo off
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File "%~dp0scripts\Patch.ps1" -Action Install %*
set "patch_exit=%errorlevel%"
pause
exit /b %patch_exit%
