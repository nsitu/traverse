@echo off
SETLOCAL enabledelayedexpansion

IF "%~1"=="" (
@echo ===========================================================
@echo  STITCH: recombine slices from a shredded video
@echo ===========================================================
@echo - Input the folder produced by a shred operation, i.e. shred.bat
@echo - Contents include subfolders for each frame of a video
@echo - Each subfolder contains numbered lengthwise slices
@echo - Here we reassemble these slices to form TIFFs
@echo - Each tiff will have as length the slice length
@echo - Each tiff will have as width the slice count
@echo ------------------------
@echo USAGE: shred.bat foldername
@echo - foldername: a folder containing the output of shred.bat
@echo ------------------------
@echo OUTPUT: a series of TIFF images joining/tiling slices
@echo - The output file name derives from the folder name
@echo - The output file name also includes the slice number, e.g. 0-1080
@echo - e.g. 'content/' at slice 2 results in 'content_2.tiff'
exit /b
)

SET shredFolder=%1


REM open the first folder and test how many slices there are
set frameCount=0
@echo 'cd !shredFolder!^&dir /ad /b * ^|find /c /v ""'
for /f %%i in ('cd !shredFolder!^&dir /ad /b * ^|find /c /v ""') do @call set frameCount=%%i
@echo Found %frameCount% frames

set sliceCount=0
for /f %%i in ('cd !shredFolder!\00000001^&dir /b *.tiff ^|find /c /v ""') do @call set sliceCount=%%i
@echo Found %sliceCount% slices per frame

@echo 'mediainfo -f !shredFolder!\00000001\1.tiff ^|find "Height"'
REM discover dimension of slices.

:sliceHeight
for /f "tokens=2 delims=: " %%j in (
  'mediainfo -f !shredFolder!\00000001\1.tiff ^|find "Height"'
) do (
  SET /A sliceHeight=%%j
  goto :sliceWidth
)
:sliceWidth
for /f "tokens=2 delims=: " %%j in (
  'mediainfo -f !shredFolder!\00000001\1.tiff ^|find "Width"'
) do (
  SET /A sliceWidth=%%j
  goto :setOrientation
)
:setOrientation
IF %sliceWidth% gtr %sliceHeight% (
  @echo Slices are horizontally orientated
  @echo Slices are !sliceWidth!px long
  @echo tileOption = tile=1x%frameCount%
  SET tileOption=tile=1x%frameCount%
) ELSE (
  @echo Slices are verticaly oriented
  @echo Slices are !sliceHeight!px tall
  @echo tileOption = tile=%frameCount%x1
  SET tileOption=tile=%frameCount%x1
)

@echo Tile Option is !tileOption!

FOR /L %%G IN (0,1,%sliceCount%) DO (
  @echo =================================
  @echo Stitching row %%G of %sliceCount%
  @echo start /MIN /W cmd /C ffmpeg -i !shredFolder!/%%08d/%%G.tiff -filter_complex !tileOption! !shredFolder!_%%G.tiff
  start /MIN /W cmd /C ffmpeg -i !shredFolder!/%%08d/%%G.tiff -filter_complex !tileOption! !shredFolder!_%%G.tiff
  @echo stitching complete for row %%G

)


REM delete temporary TIFFs
FOR /L %%G IN (0,1,%frameCount%) DO (
  @echo Removing temporary TIFF slices for frame %%G
  IF EXIST !shredFolder!\%frameCount% DEL /F /Q !shredFolder!\%frameCount%
  @echo %sliceCount% slice TIFFs deleted.
  @echo Removing temporary slice folder !shredFolder!\%frameCount%
  IF EXIST !shredFolder!\%frameCount% RMDIR /S /Q !shredFolder!\%frameCount%
  @echo Deleted !shredFolder!\%frameCount%
  exit /b
)


@echo Finished.
