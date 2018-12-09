@echo off
SETLOCAL enabledelayedexpansion

IF "%~1"=="" (
@echo ===========================================================
@echo  TRAVERSE: a tool to generate a cross section from a video
@echo ===========================================================
@echo - All frames are cropped to 2px slices: e.g. 1920x2 pixels.
@echo - Slices are re-assembled with 1px overlap in sequence
@echo - Output is saved as a panorama.
@echo ------------------------
@echo USAGE: traverse.bat [string inputFile]
@echo - inputFile: an mp4, or mkv video, or an avs script
@echo ------------------------
@echo OUTPUT: a TIFF image file is generated in the same folder
@echo - The output file name will match that of the input file:
@echo - e.g. 'content.mp4' results in 'content.tiff'
exit /b
)

REM TODO
REM use input file length to automate a ramp/envelope equation

SET inputFile=%1
SET panoramaSize=%2

FOR /F %%i in ("%1") do @SET baseName=%%~ni
SET avsFile=!baseName!.avs
SET outputFile=!baseName!.tiff
SET tempVideo=!baseName!_tmp.mp4
SET tempTxt=!inputFile!_tmp.txt
SET ffindexFile=!inputFile!.ffindex
SET theWidth=1
SET theHeight=1
SET theRotation=0

REM if a desired panorama size is given, calculate the necessary framerate
REM and frame-interpolate the Video on the fly by generating an .avs script
IF "%~2" NEQ "" (

  @echo Requested panorama size: !panoramaSize!
  REM we will need vbscript to do floating point math.
  REM therefore step 1 is to create a vbs script
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
  FOR /f %%n in ('cscript //nologo eval.vbs "(!theDuration!/1000)*!theFrameRate!"') do ( SET theFrameCount=%%n )

  REM output calculated values
  @echo Duration: !theDuration! milliseconds ^(via mediainfo^)
  @echo FrameRate: !theFrameRate! frames per second ^(via mediainfo^)
  @echo Frame Count: !theFrameCount! frames ^(calculated^)

  REM if the framecount is already large enough
  REM (i.e. if the framecount meets or exceeds the desired panorama size)
  REM then we dont need to do any interpolation
  FOR /f %%n in ('cscript //nologo eval.vbs "!panoramaSize!>!theFrameCount!"') do (
    SET doInterpolation=%%n
  )

  IF !doInterpolation! EQU 0 (
    @echo Frame count !theFrameCount! already meets or exeeds the desired panorama size !panoramaSize!
    @echo No need for any frame interpolation.
  ) ELSE (
    @ECHO Framecount !theFrameCount! is less than the desired panorama size !panoramaSize!
    @ECHO Therefore we will do some frame interpolation.
    REM calculate framerate for interpolation to achieve desired panorama size
    FOR /f %%n in ('cscript //nologo eval.vbs "CInt((!panoramaSize!/!theFrameCount!)*!theFrameRate!)"') do (  SET theNewFrameRate=%%n  )
     REM output the calculated values

     @echo Desired Panorama Size: !panoramaSize! ^(via input^)
     @echo New Frame Rate: !theNewFrameRate! ^(calculated^)

     REM designate a name for the avs file
     @echo FFmpegsource2^("!inputFile!"^)> !avsFile!
     @echo InterFrame^(Cores=4, Preset="Medium", Tuning="Film", NewNum=!theNewFrameRate!, NewDen=1, GPU=true^)>> !avsFile!
     @echo created !avsFile! to support frame interpolation.
     @echo changing frame rate from !theFrameRate! to !theNewFrameRate!
     SET inputFile=!avsFile!
  )
)

ffprobe -v error -select_streams v:0 -show_entries stream=width -of csv=s=x:p=0 !inputFile! > !tempTxt!
set /p theWidth= < !tempTxt!
@echo video width for !inputFile! is !theWidth!px (via ffprobe)
del !tempTxt!

ffprobe -v error -select_streams v:0 -show_entries stream=height -of csv=s=x:p=0 !inputFile! > !tempTxt!
set /p theHeight= < !tempTxt!
@echo video height for !inputFile! is !theHeight!px (via ffprobe)
del !tempTxt!

ffprobe -loglevel error -select_streams v:0 -show_entries stream_tags=rotate -of default=nw=1:nk=1 -i !inputFile! > !tempTxt!
set /p theRotation= < !tempTxt!
@echo video rotation for !inputFile! is !theRotation! degrees (via ffprobe)
del !tempTxt!

SET /A ySlicePos =  !theHeight! / 2
SET /A xSlicePos =  !theWidth! / 2

IF !theWidth! gtr !theHeight! (
 @echo Landscape Width=!theWidth!, Height=!theHeight!
REM you still need to account for a 270 degree rotation.
 IF !theRotation! EQU 90 (
  @echo Original file is rotated 90 degrees
  @echo Treating as if a Portrait Width=!theHeight!, Height=!theWidth!
  @echo Slicing vertically at X Position: !ySlicePos!
  @echo Will transpose with Counterclockwise Rotation and Vertical flip.
  ffmpeg -i !inputFile! -vf "crop=2:!theWidth!:!ySlicePos!:0,transpose=0" -an !tempVideo!
 ) ELSE (
  IF !theRotation! EQU 270 (
   @echo Original file is rotated 270 degrees
   @echo Treating as if a Portrait Width=!theHeight!, Height=!theWidth!
   @echo Slicing vertically at X Position: !ySlicePos!
   @echo Will transpose with Counterclockwise Rotation and Vertical flip.
   ffmpeg -i !inputFile! -vf "crop=2:!theWidth!:!ySlicePos!:0,transpose=0" -an !tempVideo!
  ) ELSE (
  @echo Slicing horizontally at Y Position: !ySlicePos!
  ffmpeg -i !inputFile! -vf "crop=!theWidth!:2:0:!ySlicePos!" -an !tempVideo!
  )
 )
 @echo Smushing !tempVideo! into !outputFile! using -smush
 magick convert !tempVideo! -smush -1 -rotate 90 !outputFile!
)


IF !theHeight! gtr !theWidth! (
 @echo Portrait Width=!theWidth!, Height=!theHeight!
 IF !theRotation! EQU 90 (
  @echo Unexpected rotation issues. You do not normally have a natively vertical video with 90 degrees rotation. wtf.
 ) ELSE (
  @echo Slicing vertically at X Position: !xSlicePos!
  ffmpeg -i !inputFile! -vf "crop=2:!theHeight!:!xSlicePos!:0" -an !tempVideo!
  @echo Smushing !tempVideo! into !outputFile! using +smush
  magick convert !tempVideo! +smush -1 !outputFile!
 )
)


DEL !tempVideo! >nul 2>&1
DEL !avsFile! >nul 2>&1
DEL !tempTxt! >nul 2>&1
DEL !ffindexFile!

IF EXIST "inputFile" DEL /F "inputFile"
@echo Finished.
