@echo off
SETLOCAL enabledelayedexpansion

IF "%~1"=="" (
@echo ===========================================================
@echo  TIMELAPSE: use ffmpeg to make a timelapse from a video
@echo ===========================================================
@echo USAGE: timelapse.bat filename multiplier
@echo filename: the name of a video file ... e.g. input.mp4
@echo multiplier: number between 0 and 1  based on "presentation timestamp"
@echo ------------------------
@echo OUTPUT: a video is generated 
@echo the video will be named timelapse_originalname.originalextension.mp4
exit /b
)

SET fileName=%1
SET multiplier=%2

ffmpeg -i %1 -filter:v "setpts=%2*PTS" -an timelapse_%1.mp4

@echo Converted %1 into timelapse_%1 
