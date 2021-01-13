@echo off
SETLOCAL enabledelayedexpansion

IF "%~1"=="" (
  @echo ===========================================================
  @echo  INFO: gather details about a video
  @echo ===========================================================
  @echo  Given a video file, display width, height, framecount, etc.
  @echo ------------------------
  @echo USAGE: info.bat filename
  @echo  filename: an mp4, or mkv video
  @echo ------------------------
  @echo OUTPUT: information is printed to the screen
  exit /b
)

SET inputFile=%1
SET tempTxt=!inputFile!_tmp.txt
FOR /F %%i in ("%1") do @SET baseName=%%~ni

:frameRate
for /f "tokens=3 delims=: " %%j in ( 'mediainfo -f !inputFile! ^|find "Frame rate"' ) do (
  SET theFrameRate=%%j
  goto:frameRateMode
)
:frameRateMode
for /f "tokens=4 skip=1 delims=: " %%j in ( 'mediainfo -f !inputFile! ^|find "Frame rate mode"' ) do (
  SET theFrameRateMode=%%j
  goto:frameCount
)
:frameCount
for /f "tokens=3 delims=: " %%j in ( 'mediainfo -f !inputFile! ^|find "Frame count"' ) do (
  SET theFrameCount=%%j
  goto :duration
)
:duration
for /f "tokens=2 delims=: " %%j in ( 'mediainfo -f !inputFile! ^|find "Duration"' ) do (
  SET theDuration=%%j
  goto :rotation
)
:rotation
for /f "tokens=2 delims=: " %%j in ( 'mediainfo -f !inputFile! ^|find "Rotation"' ) do (
  SET theRotation=%%j
  goto :height
)
:height
for /f "tokens=2 delims=: " %%j in ( 'mediainfo -f !inputFile! ^|find "Height"' ) do (
  SET theHeight=%%j
  goto :width
)
:width
for /f "tokens=2 delims=: " %%j in ( 'mediainfo -f !inputFile! ^|find "Width"' ) do (
  SET theWidth=%%j
  goto :display
)
:display
@echo -----------------------
@echo Summary for !inputFile!:
@echo -----------------------
@echo !theFrameRate! frames per second
@echo !theFrameRateMode! frame rate mode
@echo !theFrameCount! frames
@echo !theDuration! milliseconds (duration)
@echo !theRotation! degrees (rotation)
@echo !theHeight! px (height)
@echo !theWidth! px (width)


exit /b
