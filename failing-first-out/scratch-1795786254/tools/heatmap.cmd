@echo off
rem Wuber earnings heatmap: double-click after logging out (or /reload in every game window).
rem   heatmap.cmd --demo    made-up data, to see the report
rem   heatmap.cmd --wtf "<WoW folder>\_forever_\WTF"   another game folder
where node >nul 2>nul
if errorlevel 1 (
	echo Node.js is needed: install the LTS version from https://nodejs.org and run this again.
	pause
	exit /b 1
)
node "%~dp0heatmap.js" %*
if errorlevel 1 pause
