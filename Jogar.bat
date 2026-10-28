@echo off
rem Executa o protótipo do CYBLADE (duplo clique). Use "Jogar.bat -Editor" para abrir no editor.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\run.ps1" %*
if errorlevel 1 pause
