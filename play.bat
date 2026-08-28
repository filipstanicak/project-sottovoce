@echo off
setlocal EnableDelayedExpansion
REM ===========================================================================
REM  Project Sottovoce - one session, from cold.
REM
REM    play.bat              a server, 3 bots, and you
REM    play.bat 5            a server, 5 bots, and you  (6 is the lobby cap)
REM    play.bat 3 27016      ...on another port
REM    play.bat 3 27015 42   ...with a fixed match seed, so the crowd repeats
REM
REM  Close the GAME WINDOW to end the session. This window then shuts the
REM  server and every bot down; you do not need to hunt them in Task Manager.
REM ===========================================================================

set "GODOT=C:\Users\Slimex\Desktop\Godot_v4.7.1-stable_win64.exe"
set "PORT=27015"
set "BOTS=3"
set "SEED="

if not "%~1"=="" set "BOTS=%~1"
if not "%~2"=="" set "PORT=%~2"
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

REM TUN-LOBBY-MAX-PLAYERS is 6 and you are one of them. A seventh peer is
REM refused by the handshake, so it would join, fail, and leave you wondering.
if %BOTS% GTR 5 (
    echo   %BOTS% bots plus you is over the 6-player lobby cap. Using 5.
    set "BOTS=5"
)

echo.
echo   Sottovoce - port %PORT%, %BOTS% bot^(s^) %SEED%
echo.

REM A stale server from a previous run still holds the port, and the failure
REM looks like the client being unable to connect for no reason.
echo   [1/4] clearing anything still running...
taskkill /F /IM "Godot_v4.7.1-stable_win64.exe" >nul 2>&1
timeout /t 1 /nobreak >nul

echo   [2/4] starting the server...
start "sottovoce server" /min "%GODOT%" --headless --path "%PROJECT%" -- --server --port %PORT% --max-players 6 %SEED%

REM The server places 78 NPCs and bakes four processions before it listens.
REM Bots that dial in early simply fail to connect and exit.
timeout /t 5 /nobreak >nul

echo   [3/4] adding %BOTS% bot^(s^)...
for /L %%i in (1,1,%BOTS%) do (
    start "sottovoce bot %%i" /min "%GODOT%" --headless --path "%PROJECT%" res://tools/bot_client.tscn -- --connect 127.0.0.1:%PORT% --bot %%i
    timeout /t 1 /nobreak >nul
)

timeout /t 2 /nobreak >nul
echo   [4/4] joining...
echo.
echo   WASD move  ^|  Ctrl blend-walk  ^|  Shift run  ^|  Shift Shift sprint
echo   Space traverse  ^|  E blend  ^|  Q Cinderfall  ^|  Tab score  ^|  Esc menu
echo   LEFT MOUSE kills  ^|  RIGHT MOUSE stuns  ^|  MIDDLE MOUSE crowd-scan
echo   F3 turns the debug overlays off.
echo.
echo   Close the game window when you are done.
echo.

REM Foreground on purpose: this window blocks here until you quit the game,
REM and everything below is the shutdown.
"%GODOT%" --path "%PROJECT%" -- --connect 127.0.0.1:%PORT%

echo.
echo   shutting the server and bots down...
taskkill /F /IM "Godot_v4.7.1-stable_win64.exe" >nul 2>&1
echo   done.
timeout /t 2 /nobreak >nul
endlocal
