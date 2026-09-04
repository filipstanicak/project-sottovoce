@echo off
setlocal EnableDelayedExpansion
REM ===========================================================================
REM  Project Sottovoce - MAP-SANDBOX. A bench, not a match.
REM
REM    sandbox.bat              a server, 1 hunter, 12 civilians, and you
REM    sandbox.bat 2            two hunters
REM    sandbox.bat 1 0          one hunter and an EMPTY district
REM    sandbox.bat 1 12 3       one hunter, 12 civilians and 3 QUARRY bots
REM    sandbox.bat 0 12 3       nobody hunting you - three to stalk
REM    sandbox.bat 1 12 3 42    ...with a fixed match seed
REM
REM  HUNTERS pursue their contract and cast on cooldown. QUARRY bots join the
REM  same lobby and stroll in random legs, hunting nobody - somebody to stalk,
REM  approach and kill without being chased while you do it.
REM
REM  YOU CANNOT HAVE TWO PURSUERS OR TWO PREY, WHATEVER THESE NUMBERS SAY, and
REM  that is the design rather than a limit of this script. The contract graph
REM  is ONE HAMILTONIAN CYCLE over the living players (GDD-03 section 7), so
REM  every player has exactly one outgoing edge - their contract - and exactly
REM  one incoming edge - their pursuer. So:
REM
REM    * at most ONE bot holds a contract on you, however many hunt;
REM    * exactly ONE player is yours to kill at any instant;
REM    * whether that is a hunter or a quarry bot is the cycle's to decide.
REM
REM  What the third number buys is the ODDS and the TEMPO: with 1 hunter and 3
REM  quarry your contract is a passive bot three times in four, and in a "3 0"
REM  run the two hunters that are not on you are hunting each other.
REM
REM  A 40 x 40 m walled courtyard: one block in the middle to break sightlines,
REM  a corner nook with a single 2 m mouth, and two vaultable stalls. Spawn
REM  points are 15 m apart, so you and the bot meet in about ten seconds.
REM
REM  A HUNTER IS RECKLESS ON PURPOSE, which is the arrangement worth practising
REM  against: TUN-STUN-MIN-TIER makes a careful hunter unstunnable by design,
REM  so a bot that never casts can never be stunned by you. A QUARRY bot is
REM  therefore NOT stunnable - it is there to be killed, not defended against.
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
set "QUARRY=0"
set "SEED="

if not "%~1"=="" set "BOTS=%~1"
if not "%~2"=="" set "CROWD=%~2"
if not "%~3"=="" set "QUARRY=%~3"
if not "%~4"=="" set "SEED=--seed %~4"

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

REM TUN-LOBBY-MAX-PLAYERS is 6 and you are one of them, so the cap is on the
REM TOTAL rather than on either number. A seventh peer is refused by the
REM handshake: it would start, fail to join and vanish, which reads as a bot
REM that crashed rather than as a lobby that is full. The hunters are kept and
REM the quarry is trimmed, because a session that asked for hunters is a
REM session about being hunted.
if %BOTS% GTR 5 (
    echo   %BOTS% hunters plus you is over the 6-player lobby cap. Using 5.
    set "BOTS=5"
)
set /a TOTAL=%BOTS%+%QUARRY%
if %TOTAL% GTR 5 (
    set /a QUARRY=5-%BOTS%
    echo   %BOTS% hunter^(s^) + %QUARRY% quarry + you is over the 6-player cap.
    echo   Trimming the quarry to !QUARRY!.
)

echo.
echo   Sottovoce SANDBOX - port %PORT%, %BOTS% hunter^(s^), !QUARRY! quarry, %CROWD% civilians %SEED%
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

echo   [3/4] adding %BOTS% hunter^(s^) and !QUARRY! quarry...
REM --map MUST be passed to the bot as well. A bot instantiates the client root
REM itself rather than going through boot.gd, so without it the bot loads the
REM district while the server runs the courtyard.
if %BOTS% GTR 0 (
    for /L %%i in (1,1,%BOTS%) do (
        start "sottovoce hunter %%i" /min "%GODOT%" --headless --path "%PROJECT%" res://tools/bot_client.tscn -- --connect 127.0.0.1:%PORT% --map sandbox --bot %%i --hunt --reckless
        timeout /t 1 /nobreak >nul
    )
)

REM THE QUARRY CONTINUES THE --bot NUMBERING RATHER THAN RESTARTING AT 1.
REM `--bot N` is the bot's own RNG seed and nothing else, so two bots given the
REM same number walk the same legs at the same moments - they would stroll as a
REM pair and read as one body with a shadow.
set /a FIRST_QUARRY=%BOTS%+1
set /a LAST_QUARRY=%BOTS%+!QUARRY!
if !QUARRY! GTR 0 (
    for /L %%i in (!FIRST_QUARRY!,1,!LAST_QUARRY!) do (
        start "sottovoce quarry %%i" /min "%GODOT%" --headless --path "%PROJECT%" res://tools/bot_client.tscn -- --connect 127.0.0.1:%PORT% --map sandbox --bot %%i
        timeout /t 1 /nobreak >nul
    )
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
