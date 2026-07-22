@echo off
cd /d "%~dp0"
echo 绿色军团 — 热座回合制策略游戏
echo =================================
echo.
python main.py
if errorlevel 1 (
    echo.
    echo 启动失败！请确保已安装 Python 3.x:
    echo   pip install pygame
    pause
)
