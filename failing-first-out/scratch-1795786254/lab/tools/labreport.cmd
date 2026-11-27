@echo off
rem Wuber Lab report (developer only). Optional first argument: your WTF folder.
rem Default: C:\Program Files (x86)\World of Warcraft\_forever_\WTF
node "%~dp0labreport.js" %*
if "%~1"=="" pause
