@echo off
rem Double-click this on Windows.
rem Finds the bash that ships with Git for Windows, then opens .reprise/menu.
rem Deliberately avoids parenthesised if-blocks: %ProgramFiles(x86)% contains
rem brackets and breaks them.

cd /d "%~dp0"

set "BASH="
if exist "%ProgramFiles%\Git\bin\bash.exe" set "BASH=%ProgramFiles%\Git\bin\bash.exe"
if not defined BASH if exist "%ProgramFiles(x86)%\Git\bin\bash.exe" set "BASH=%ProgramFiles(x86)%\Git\bin\bash.exe"
if not defined BASH if exist "%LocalAppData%\Programs\Git\bin\bash.exe" set "BASH=%LocalAppData%\Programs\Git\bin\bash.exe"
if not defined BASH if exist "%UserProfile%\scoop\apps\git\current\bin\bash.exe" set "BASH=%UserProfile%\scoop\apps\git\current\bin\bash.exe"
if not defined BASH where bash.exe >nul 2>&1 && set "BASH=bash.exe"

if not defined BASH goto nogit

rem --- UPDATED LINE ---
rem Runs bash as a login/interactive shell and safely executes your menu script
"%BASH%" --login -i -c "bash ./.reprise/menu"
goto end

:nogit
echo.
echo   Git for Windows is not installed, so this cannot run yet.
echo.
echo   1. Go to https://gitforwindows.org
echo   2. Download it and click through the installer, accepting the defaults.
echo   3. Double-click this file again.
echo.
pause
exit /b 1

:end
rem .reprise/menu waits for Enter itself, but pause here too in case bash
rem failed to start and printed something we would otherwise lose.
if errorlevel 1 pause
exit /b 0