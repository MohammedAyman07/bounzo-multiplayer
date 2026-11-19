@echo off
cd /d "%~dp0"
title BOUNZO ONLINE MULTIPLAYER SERVER (PORT 7777)
color 0A
cls
echo ======================================================================
echo             BOUNZO ONLINE MULTIPLAYER SERVER (PORT 7777)
echo ======================================================================
echo.
echo  PUBLIC INTERNET TUNNEL: cairo-constantly.tun.ply.gg:42174
echo  DIRECT PUBLIC IP:       147.185.221.213:42174
echo  LOCAL UDP PORT:         7777
echo.
echo  Mobile phones on 4G/5G and any Wi-Fi connect automatically!
echo.
echo  (KEEP THIS WINDOW OPEN WHILE PLAYERS ARE PLAYING)
echo ======================================================================
echo.
"C:\Users\moham\Downloads\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe" --headless --scene res://scenes/multiplayer/server_main.tscn -- --port 7777
pause
