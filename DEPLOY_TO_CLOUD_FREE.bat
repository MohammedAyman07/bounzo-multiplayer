@echo off
setlocal enabledelayedexpansion
cd /d "%~dp0"
title BOUNZO 24/7 FREE CLOUD SERVER DEPLOYER
color 0B
cls

echo ======================================================================
echo          BOUNZO 24/7 FREE CLOUD SERVER DEPLOYER (NO PC NEEDED)
echo ======================================================================
echo.
echo  This tool deploys your BOUNZO dedicated server to a FREE cloud host.
echo  Once deployed:
echo   - Runs 24/7 in the cloud ($0 forever)
echo   - Works across 4G/5G and any Wi-Fi in the world
echo   - YOUR PC DOES NOT NEED TO BE ON!
echo.
echo ======================================================================
echo.

set "FLY_EXE=%USERPROFILE%\.fly\bin\flyctl.exe"

if not exist "!FLY_EXE!" (
    echo [1/3] Downloading Fly.io CLI...
    powershell -Command "iwr https://fly.io/install.ps1 -useb | iex"
)

echo [1/3] Checking Cloud Account Login...
"!FLY_EXE!" auth whoami >nul 2>&1
if errorlevel 1 (
    echo.
    echo Opening browser to log in (100%% Free - Sign up with Google/GitHub)...
    echo.
    "!FLY_EXE!" auth login
)

echo.
echo [2/3] Deploying 24/7 Cloud Server Container...
echo.
"!FLY_EXE!" launch --no-deploy --copy-config --yes
"!FLY_EXE!" deploy

echo.
echo ======================================================================
echo [3/3] CLOUD SERVER DEPLOYMENT COMPLETE!
echo ======================================================================
echo.
echo Your server is now running 24/7 in the cloud.
echo You can turn off your PC anytime - players connect directly!
echo.
pause
