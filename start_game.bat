@echo off
rem Runs the Space Warz game. Needs Godot_v4.6-stable_win64.exe in this same folder.
cd /d "%~dp0"
set GODOT=
for %%f in (Godot_v4.6*_win64.exe) do set GODOT=%%f
if not defined GODOT (
  echo.
  echo Godot not found. Download "Godot 4.6 - Windows" from https://godotengine.org/download/windows/
  echo unzip it, and put Godot_v4.6-stable_win64.exe in this folder:
  echo %~dp0
  echo.
  pause
  exit /b
)
if not exist game\.godot (
  echo First run: importing game assets, takes about a minute...
  "%GODOT%" --headless --path game --import
)
"%GODOT%" --path game
