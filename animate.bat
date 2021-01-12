@echo off
SETLOCAL enabledelayedexpansion

IF "%~1"=="" (
@echo ===========================================================
@echo  ANIMATE: generate a series of cross sections from a video
@echo ===========================================================
@echo  Given a video file, find the length of the shortest axis
@echo  eg. for a 1920x1080 video the shorter axis is 1080
@echo  Then, for every pixel position on that axis.
@echo  Generate a cross section of the video
@echo  Optionally stitch together the resulting frames into a video
@echo ------------------------
@echo USAGE: animate.bat filename
@echo  filename: an mp4, or mkv video
@echo ------------------------
@echo OUTPUT: a series of TIFF images created by traverse.bat
@echo  e.g. 'file.mp4' becomes 'file_1.tiff' ... 'file_1920.tiff'
exit /b
)

SET inputFile=%1
FOR /F %%i in ("%1") do @SET baseName=%%~ni

SET tempTxt=!inputFile!_tmp.txt

REM we will need vbscript to do floating point math.
REM therefore step 1 is to create a vbs script.
REM this is the same as in traverse.bat
REM start with a clean slate

DEL "eval.vbs" >nul 2>&1
@ECHO WScript.Echo Eval^(WScript.Arguments^(0^)^) > "eval.vbs"

REM get duration and framerate info from the input file using mediainfo
mediainfo --Inform="Video;%%Duration%%" !inputFile! > DUR!tempTxt!
SET /p theDuration=<DUR!tempTxt!
DEL DUR!tempTxt!
mediainfo --Inform="Video;%%FrameRate%%" !inputFile! > FR!tempTxt!
SET /p theFrameRate=<FR!tempTxt!
DEL FR!tempTxt!

REM derive (approximate) frame count from duration and frame rate
FOR /f %%n in ('cscript //nologo eval.vbs "CInt((!theDuration!/1000)*!theFrameRate!)"') do ( SET theFrameCount=%%n )

REM output calculated values
@echo Duration: !theDuration! milliseconds ^(via mediainfo^)
@echo FrameRate: !theFrameRate! frames per second ^(via mediainfo^)
@echo Frame Count: !theFrameCount! frames ^(calculated^)

REM calcuate width of input file
@echo ffprobe -v error -select_streams v:0 -show_entries stream=width -of csv=s=x:p=0 !inputFile! > !tempTxt!
ffprobe -v error -select_streams v:0 -show_entries stream=width -of csv=s=x:p=0 !inputFile! > !tempTxt!
set /p theWidth= < !tempTxt!
@echo video width for !inputFile! is !theWidth!px ^(via ffprobe^)
del !tempTxt!

REM calcuate height of input file
ffprobe -v error -select_streams v:0 -show_entries stream=height -of csv=s=x:p=0 !inputFile! > !tempTxt!
set /p theHeight= < !tempTxt!
@echo video height for !inputFile! is !theHeight!px ^(via ffprobe^)
del !tempTxt!

if !theHeight! geq !theWidth! (
  SET /A shortAxis = !theWidth!
) else (
  SET /A shortAxis = !theHeight!
)

REM FOR /L %%A IN (1,1,!shortAxis!) DO (
REM FOR /L %%A IN (1,1,3) DO traverse.bat !inputFile! 0 %%A
@echo Rendering Frames via traverse.bat
SET /A numberOfFrames = %shortAxis%
FOR /L %%A IN (1,1,%numberOfFrames%) DO (

  SET fileID=0000000%%A
  SET fileID=!fileID:~-8!
  @echo ---
  @echo Frame %%A of !numberOfFrames! processing:
  @echo Target file is !baseName!_!fileID!.tiff
  REM if the frame does not yet exist, render it.
  IF EXIST !baseName!_!fileID!.tiff (
    @echo File already exists; skipping.
  ) else (
    REM /MIN means we start a new window minimized
    REM in this way it will avoid stealing focus from other apps
    REM /W means we wait for each frame to be finished before proceeding to the next.
    REM otherwise there will be a thousand CMD windows at once.
    REM /C means we close the child window when it is finished.
    REM this prevents the sceen from getting too cluttered.

    @echo Traversing video and rendering TIFF...
    start /MIN /W cmd /C traverse.bat !inputFile! 0 %%A
    @echo Rendering complete.
  )
)

@echo ----
@echo Finished rendering %numberOfFrames% frames.
@echo Assembling frame sequence as video.
ffmpeg -i !baseName!_%08d.tiff !baseName!_animation.mp4
@echo Video rendering complete:
@echo !baseName!_animation.mp4
