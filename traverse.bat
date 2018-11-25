@echo off

IF "%~1"=="" (
@echo ===========================================================
@echo  TRAVERSE: a tool to generate a cross section from a video
@echo ===========================================================
@echo - All frames are centre-cropped to thin slices: e.g. 1920x2 pixels.
@echo - Slices are re-assembled in sequence and saved as a panorama.
@echo ------------------------
@echo USAGE: traverse.bat [string inputFile] [int sliceThickness] [boolean doFlip]
@echo - inputFile: an mp4, or mkv video, or an avs script
@echo - sliceThickness: width in pixels of rectangular slice to be derived from each frame
@echo - doFlip: whether or not to flip slices. May help correct directional jaggedness
@echo ------------------------
@echo OUTPUT: a TIFF image file is generated in the same folder
@echo - The output file name will match that of the input file:
@echo - e.g. 'content.mp4' results in 'content.tiff'
exit /b
)

SET inputFile=%1
SET outputFile=%inputFile:.mp4=.tiff%
SET outputFile=%outputFile:.mkv=.tiff%
SET outputFile=%outputFile:.avs=.tiff%
SET tempVideo=%inputFile:.mp4=_tmp.mp4%
SET tempVideo=%tempVideo:.mkv=_tmp.mkv%
SET tempVideo=%tempVideo:.avs=_tmp.mp4%
SET theWidth=1
SET theHeight=1
SET theRotation=0
SET sliceSize=%2
IF "%~2"=="" ( SET sliceSize=2 )
IF "%~2"=="0" ( SET sliceSize=2 )
IF "%~2"=="1" ( SET sliceSize=2 )
SET doFlip=
IF "%~3"=="1" ( SET doFlip="-flip" )

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
 @echo Smushing %tempVideo% into %outputFile% using %doFlip% -smush
 magick convert %tempVideo% %doFlip% -smush -1 -rotate 90 %outputFile%
)


IF %theHeight% gtr %theWidth% (
 @echo Portrait Width=%theWidth%, Height=%theHeight%
 IF %theRotation% EQU 90 (
  @echo Unexpected rotation issues. You do not normally have a natively vertical video with 90 degrees rotation. wtf.
 ) ELSE (
  @echo Slicing vertically at X Position: %xSlicePos%
  ffmpeg -i %inputFile% -vf "crop=2:%theHeight%:%xSlicePos%:0" -an %tempVideo%
  @echo Smushing %tempVideo% into %outputFile% using %doFlip% +smush
  magick convert %tempVideo% %doFlip% +smush -1 %outputFile%
 )
)

del %tempVideo%
IF EXIST "doFlip" DEL /F "doFlip"
IF EXIST "sliceThickness" DEL /F "sliceThickness"
IF EXIST "inputFile" DEL /F "inputFile"
@echo Finished.
