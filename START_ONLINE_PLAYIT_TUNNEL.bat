@echo off
setlocal enabledelayedexpansion
cd /d "%~dp0"
title BOUNZO ONLINE PUBLIC SERVER (PLAYIT.GG)
color 0B
cls

echo ======================================================================
echo          BOUNZO ONLINE MULTIPLAYER - FREE PUBLIC SERVER
echo ======================================================================
echo.
echo  [1/2] Starting local BOUNZO game server (port 7777)...
echo.

start "BOUNZO DEDICATED SERVER" cmd /k "%~dp0START_LOCAL_SERVER.bat"

echo  [OK] Local game server is running!
echo.
echo ======================================================================
echo  [2/2] STARTING PUBLIC INTERNET ACCESS (PLAYIT.GG)
echo ======================================================================
echo.

if exist "C:\Program Files\playit_gg\bin\playit.exe" (
    "C:\Program Files\playit_gg\bin\playit.exe" start
    echo.
    echo Attaching to Playit tunnel monitor...
    "C:\Program Files\playit_gg\bin\playit.exe" attach
) else (
    echo Playit is not installed. Running installer now...
    msiexec /i "%~dp0playit_setup.msi" /qn
    "C:\Program Files\playit_gg\bin\playit.exe" start
    "C:\Program Files\playit_gg\bin\playit.exe" attach
)

pause
