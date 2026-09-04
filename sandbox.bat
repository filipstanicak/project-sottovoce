@echo off
setlocal EnableDelayedExpansion
REM ===========================================================================
REM  Project Sottovoce - MAP-SANDBOX. A bench, not a match.
REM
REM    sandbox.bat            a server, 1 hunting bot, 12 civilians, and you
REM    sandbox.bat 2          two bots
REM    sandbox.bat 1 0        one bot and an EMPTY district
REM    sandbox.bat 1 12 42    ...with a fixed match seed
REM
REM  A 40 x 40 m walled courtyard: one block in the middle to break sightlines,
REM  a corner nook with a single 2 m mouth, and two vaultable stalls. Spawn
REM  points are 15 m apart, so you and the bot meet in about ten seconds.
REM
REM  THE BOT HUNTS AND IS RECKLESS, which is the arrangement worth practising
REM  against: TUN-STUN-MIN-TIER makes a careful hunter unstunnable on purpose,
REM  so a bot that never casts can never be stunned by you.
REM
REM  WHAT THIS IS NOT: there are no processions, no zones and no theatre spaces
REM  here, and SpawnRules cannot give 40 m between a victim and their killer on
REM  a 40 m map, so every respawn takes its fallback. Do not measure spawn
REM  separation, crowd density or clone parity on this map - measure those on
REM  MAP-VETRAIO with play.bat.
REM
REM  Close the GAME WINDOW to end the session.
REM ===========================================================================

set "GODOT=C:\Users\Slimex\Desktop\Godot_v4.7.1-stable_win64.exe"
set "PORT=27015"
set "BOTS=1"
set "CROWD=12"
set "SEED="

if not "%~1"=="" set "BOTS=%~1"
if not "%~2"=="" set "CROWD=%~2"
if not "%~3"=="" set "SEED=--seed %~3"

REM %~dp0 ends in a backslash, which would escape the closing quote.
set "PROJECT=%~dp0"
if "%PROJECT:~-1%"=="\" set "PROJECT=%PROJECT:~0,-1%"

if not exist "%GODOT%" (
    echo.
    echo   Godot is not at:
    echo     %GODOT%
    echo.
    echo   Edit the GODOT line at the top of this file. It is not on PATH on
    echo   this machine, which is why it is spelled out rather than looked up.
    echo.
    pause
    exit /b 1
)

if %BOTS% GTR 5 (
    echo   %BOTS% bots plus you is over the 6-player lobby cap. Using 5.
    set "BOTS=5"
)

echo.
echo   Sottovoce SANDBOX - port %PORT%, %BOTS% hunting bot^(s^), %CROWD% civilians %SEED%
echo.

REM A stale server from a previous run still holds the port, and the failure
REM looks like the client being unable to connect for no reason.
echo   [1/4] clearing anything still running...
taskkill /F /IM "Godot_v4.7.1-stable_win64.exe" >nul 2>&1
timeout /t 1 /nobreak >nul

echo   [2/4] starting the server on MAP-SANDBOX...
start "sottovoce sandbox server" /min "%GODOT%" --headless --path "%PROJECT%" -- --server --port %PORT% --max-players 6 --map sandbox --crowd %CROWD% %SEED%

REM Far less to place than the district, but the navmesh still needs two
REM synchronisation passes before anything can be put on it.
timeout /t 3 /nobreak >nul

echo   [3/4] adding %BOTS% hunting bot^(s^)...
REM --map MUST be passed to the bot as well. A bot instantiates the client root
REM itself rather than going through boot.gd, so without it the bot loads the
REM district while the server runs the courtyard.
for /L %%i in (1,1,%BOTS%) do (
    start "sottovoce bot %%i" /min "%GODOT%" --headless --path "%PROJECT%" res://tools/bot_client.tscn -- --connect 127.0.0.1:%PORT% --map sandbox --bot %%i --hunt --reckless
    timeout /t 1 /nobreak >nul
)

timeout /t 2 /nobreak >nul
echo   [4/4] joining...
echo.
echo   WASD move  ^|  Ctrl blend-walk  ^|  Shift run  ^|  Shift Shift sprint
echo   Space traverse  ^|  E blend  ^|  Q Cinderfall  ^|  F Lunge  ^|  Esc menu
echo   LEFT MOUSE kills  ^|  RIGHT MOUSE stuns  ^|  MIDDLE MOUSE crowd-scan
echo   F3 turns the debug overlays off.
echo.
echo   Close the game window when you are done.
echo.

REM Foreground on purpose: this window blocks here until you quit the game.
"%GODOT%" --path "%PROJECT%" -- --connect 127.0.0.1:%PORT% --map sandbox

echo.
echo   shutting the server and bots down...
taskkill /F /IM "Godot_v4.7.1-stable_win64.exe" >nul 2>&1
echo   done.
timeout /t 2 /nobreak >nul
endlocal
