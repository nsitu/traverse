@echo off

IF "%~1"=="" ( 
@echo Usage: traverse.bat [string video.mp4] [int sliceThickness] 
exit /b
)

SET inputFile=%1
SET outputFile=%inputFile:.mp4=.tiff%
SET tempVideo=%inputFile:.mp4=_tmp.mp4%
SET theWidth=1
SET theHeight=1
SET theRotation=0
SET sliceSize=%2
IF "%~2"=="" ( SET sliceSize=2 )
IF "%~2"=="0" ( SET sliceSize=2 )
IF "%~2"=="1" ( SET sliceSize=2 )
@echo Slice Thickness: %sliceSize% Pixels

ffprobe -v error -select_streams v:0 -show_entries stream=width -of csv=s=x:p=0 %1 > tmpFile.txt 
set /p theWidth= < tmpFile.txt 
del tmpFile.txt 

ffprobe -v error -select_streams v:0 -show_entries stream=height -of csv=s=x:p=0 %1 > tmpFile.txt 
set /p theHeight= < tmpFile.txt 
del tmpFile.txt 

ffprobe -loglevel error -select_streams v:0 -show_entries stream_tags=rotate -of default=nw=1:nk=1 -i %1 > tmpFile.txt 
set /p theRotation= < tmpFile.txt 
del tmpFile.txt 

SET /A ySlicePos =  %theHeight% / 2
SET /A xSlicePos =  %theWidth% / 2

IF %theWidth% gtr %theHeight% (
 @echo Landscape Width=%theWidth%, Height=%theHeight%
REM you still need to account for a 270 degree rotation.
 IF %theRotation% EQU 90 (
  @echo Original file is rotated 90 degrees
  @echo Treating as if a Portrait Width=%theHeight%, Height=%theWidth%
  @echo Slicing vertically at X Position: %ySlicePos%
  @echo Will transpose with Counterclockwise Rotation and Vertical flip.
  ffmpeg -i %inputFile% -vf "crop=%sliceSize%:%theWidth%:%ySlicePos%:0,transpose=0" -an %tempVideo%
 ) ELSE (
  IF %theRotation% EQU 270 (
   @echo Original file is rotated 270 degrees
   @echo Treating as if a Portrait Width=%theHeight%, Height=%theWidth%
   @echo Slicing vertically at X Position: %ySlicePos%
   @echo Will transpose with Counterclockwise Rotation and Vertical flip.
   ffmpeg -i %inputFile% -vf "crop=%sliceSize%:%theWidth%:%ySlicePos%:0,transpose=0" -an %tempVideo%
  ) ELSE (
  @echo Slicing horizontally at Y Position: %ySlicePos%
  ffmpeg -i %inputFile% -vf "crop=%theWidth%:%sliceSize%:0:%ySlicePos%" -an %tempVideo%
  ) 
 )
 @echo Smushing %tempVideo% into %outputFile%
 magick convert %tempVideo% -smush 0 -rotate 90 %outputFile% 
)	


IF %theHeight% gtr %theWidth% (
 @echo Portrait Width=%theWidth%, Height=%theHeight%
 IF %theRotation% EQU 90 (
  @echo Unexpected rotation issues. You do not normally have a natively vertical video with 90 degrees rotation. wtf.
 ) ELSE (
  @echo Slicing vertically at X Position: %xSlicePos%
  ffmpeg -i %inputFile% -vf "crop=2:%theHeight%:%xSlicePos%:0" -an %tempVideo%
  @echo Smushing %tempVideo% into %outputFile%
  magick convert %tempVideo% +smush 0 %outputFile%
 )
)

del %tempVideo%
@echo Finished.
