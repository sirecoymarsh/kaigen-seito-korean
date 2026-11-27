@echo off
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File "%~dp0scripts\Hotfix.ps1" -Action Install %*
set "patch_exit=%errorlevel%"
pause
exit /b %patch_exit%
