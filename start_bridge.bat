@echo off
rem Double-click to start the glove bridge (Windows).
cd /d "%~dp0bridge"
python -m pip install -q -r requirements.txt
python bridge.py %*
pause
