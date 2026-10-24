@echo off
rem Starts the bridge with one fake glove - for testing the game without hardware.
cd /d "%~dp0bridge"
python -m pip install -q -r requirements.txt
python bridge.py --sim 1
pause
