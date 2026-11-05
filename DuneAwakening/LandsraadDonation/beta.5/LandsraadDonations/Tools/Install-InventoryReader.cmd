@echo off
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%~dp0Install-InventoryReader.ps1"
if errorlevel 1 echo Inventory reader installation did not complete. See the message above.
pause
