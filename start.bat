@echo off
cd /d "%~dp0"
echo Green Army - Hotseat Strategy Game
echo ==================================
echo.
py -3 main.py
if errorlevel 1 (
    python main.py
)
if errorlevel 1 (
    echo.
    echo Failed to start. Install Python 3.x then:
    echo   pip install pygame
    pause
)
