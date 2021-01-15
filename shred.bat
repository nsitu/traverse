@echo off
SETLOCAL enabledelayedexpansion

IF "%~1"=="" (
@echo ===========================================================
@echo  SHRED: split video into a bajillion little slices
@echo ===========================================================
@echo - Extract each video frame as a TIFF image
@echo - Split each TIFF image into tiny slices  e.g. 1x1920 pixels
@echo - Each Slice is made lengthwise as follows:
@echo - Long edge of video equals slice length, e.g. 1920
@echo - Short edge of video is divided per-pixel e.g. 1080 x 1px
@echo - Pixel count on short edge equals output slice count
@echo - Slices follow a naming convention as follows:
@echo - slice_frame#_index#.tiff
@echo - NOTE
@echo - You can optionally provide a new frameCount to increase FPS
@echo - This uses VaporSynth and .avs to timestretch interpolate frames
@echo - ALSO NOTE
@echo - Shredded slices may later be reassembled according to some logic
@echo - but that is another matter
@echo ------------------------
@echo USAGE: shred.bat filename [length]
@echo - filename: an mp4, or mkv video
@echo - length: desired frame count for frame interpolation
@echo ------------------------
@echo OUTPUT: a series of strips saved as numbered TIFF images
@echo - The output file name derives from the input file:
@echo - e.g. 'content.mp4' results in 'content_0_0.tiff'
exit /b
)

REM TODO
REM use input file length to automate a ramp/envelope equation

SET inputFile=%1

IF "%~2" == "" ( SET /A panSize=0 ) ELSE ( SET panSize=%2 )

SET "panSizeTest="&for /f "delims=0123456789" %%i in ("%2") do set panSizeTest=%%i
IF defined panSizeTest ( SET /A panSizeIsNumeric = 0 ) ELSE ( SET /A panSizeIsNumeric = 1  )


FOR /F %%i in ("%1") do @SET baseName=%%~ni
SET avsFile=!baseName!.avs
REM SET outputFile=!baseName!_!fileID!.tiff
SET outputFolder=!baseName!_slices
SET ffindexFile=!inputFile!.ffindex
SET vbsFile=!inputFile!_eval.vbs
SET theWidth=1
SET theHeight=1
SET theRotation=0
SET theOrientation=
SET theFilter=
SET sliceSize=x

:frameRate
for /f "tokens=3 delims=:. " %%j in ( 'mediainfo -f !inputFile! ^|find "Frame rate"' ) do (
  SET /A theFrameRate=%%j
  goto:frameRateMode
)
:frameRateMode
for /f "tokens=4 skip=1 delims=: " %%j in ( 'mediainfo -f !inputFile! ^|find "Frame rate mode"' ) do (
  SET theFrameRateMode=%%j
  goto:frameCount
)
:frameCount
for /f "tokens=3 delims=: " %%j in ( 'mediainfo -f !inputFile! ^|find "Frame count"' ) do (
  SET /A theFrameCount=%%j
  goto :rotation
)
:rotation
for /f "tokens=2 delims=:. " %%j in ( 'mediainfo -f !inputFile! ^|find "Rotation"' ) do (
  SET theRotation=%%j
  goto :height
)
:height
for /f "tokens=2 delims=: " %%j in ( 'mediainfo -f !inputFile! ^|find "Height"' ) do (
  SET /A theHeight=%%j
  goto :width
)
:width
for /f "tokens=2 delims=: " %%j in ( 'mediainfo -f !inputFile! ^|find "Width"' ) do (
  SET /A theWidth=%%j
  goto :pixelAspectRatio
)
:pixelAspectRatio
for /f "tokens=4 delims=: " %%j in ( 'mediainfo -f !inputFile! ^|find "Pixel aspect ratio"' ) do (
  SET thePixelAspectRatio=%%j
  goto :displayAspectRatio
)
:displayAspectRatio
for /f "tokens=4 delims=: " %%j in ( 'mediainfo -f !inputFile! ^|find "Display aspect ratio"' ) do (
  SET theDisplayAspectRatio=%%j
  goto :continue
)
:continue

@echo.
@echo ==========================
@echo Input file !inputFile!:
@echo ==========================
@echo !theFrameRate! frames per second
@echo !theFrameRateMode! frame rate mode
@echo !theFrameCount! frames
@echo !theRotation! degrees (rotation)
@echo !theHeight! px (height)
@echo !theWidth! px (width)
@echo !thePixelAspectRatio! (pixel aspect ratio)
@echo !theDisplayAspectRatio! (display aspect ratio)

REM if a desired panorama size is given, frame-interpolate the Video on the fly by generating an .avs script
REM a panSize of 0 is interpreted as "match the frame count"

@echo.
@echo ==========================
@echo Panorama
@echo ==========================
if %panSizeIsNumeric% EQU 1 (

    REM if 0 is given for panSize, we will use the frameCount.
    if %panSize% EQU 0 (
      @echo Default Panorama size requested via zero parameter.
      @echo Panorama size set to match frame count: !theFrameCount! frames
      SET /A panSize=%theFrameCount%
    ) else (
      @echo Requested panorama size: !panSize!
    )

    IF %theFrameCount% GTR %panSize% (
      @echo Frame count !theFrameCount! already meets or exeeds the desired panorama size !panSize!
      @echo No need for any frame interpolation.
    ) ELSE (
      @ECHO Framecount !theFrameCount! is less than the desired panorama size !panSize!
      @ECHO Therefore we will do some frame interpolation.
      REM calculate framerate for interpolation to achieve desired panorama size

      REM the /A flag auto resolves variables
      SET /A Result = panSize*theFrameRate
      SET /A theNewFrameRate = Result/theFrameCount

      REM FOR /f %%n in ('cscript //nologo !vbsFile! "CInt((!panSize!/!theFrameCount!)*!theFrameRate!)"') do (  SET theNewFrameRate=%%n  )
       REM output the calculated values

       @echo Desired Panorama Size: !panSize! ^(via input^)
       @echo New Frame Rate: !theNewFrameRate! ^(calculated^)

       REM Use AviSynth frame server for frame interpolation
       REM Generate .avs file that employs the InterFrame script
       REM TODO: Research which Preset is optimal:
       REM e.g. DOes "Fastest" come at the cost of filesize? or quality?
       REM (filesize would be fine but quality would  not be)
       REM AviSynth+ multithreading notes here: http://avisynth.nl/index.php/AviSynth+#MT_Notes
       REM might need to test how many cores are available

       @echo SetFilterMTMode^("DEFAULT_MT_MODE", 2^)> !avsFile!
       @echo FFmpegsource2^("!inputFile!"^)>> !avsFile!
       @echo InterFrame^(Cores=8, Preset="Fastest", Tuning="Film", NewNum=!theNewFrameRate!, NewDen=1, GPU=true^)>> !avsFile!
       @echo Prefetch^(8^)>> !avsFile!
       @echo created !avsFile! to support frame interpolation.
       @echo changing frame rate from !theFrameRate! to !theNewFrameRate!
       SET inputFile=!avsFile!

       REM dont assume that the avs file has the same width height and rotation as the original.
       REM I dont think avs files use rotation .
       REM TODO test thi further for a range of different videos.
       SET theRotation=0

    )

) ELSE (
  @echo Paramater not supplied for panorama size.
  @echo Panorama size set to match frame count: !theFrameCount! frames
  SET /A panSize=%theFrameCount%
)


REM iterate through frames
REM iterate through slices

@echo Creating folder !outputFolder! to hold TIFF frames
if not exist "!outputFolder!" mkdir "!outputFolder!%"

@echo Extract first frame to test output dimensions.
start /W cmd /C ffmpeg -i !inputFile!  -an -y -compression_algo raw -pix_fmt rgb24 -vframes 1 !outputFolder!/test.tiff
@echo Created !outputFolder!/test.tiff


:testHeight
for /f "tokens=2 delims=: " %%j in ( 'mediainfo -f !outputFolder!/test.tiff ^|find "Height"' ) do (
  SET /A testHeight=%%j
  @echo TIFF Height is !testHeight!
  goto :testWidth
)
:testWidth
for /f "tokens=2 delims=: " %%j in ( 'mediainfo -f !outputFolder!/test.tiff ^|find "Width"' ) do (
  SET /A testWidth=%%j
  @echo TIFF Width is !testWidth!
  goto :setOrientation
)
:setOrientation

IF %testWidth% gtr %testHeight% (
  @echo Orientation is Landscape
  @echo Shorter edge is !testHeight!
  @echo Longer edge is !testWidth!
  SET sliceSize=!testWidth!x1
  SET /A slicesPerFrame=%testHeight%
) ELSE (
  @echo Orientation is Portrait
  @echo Shorter edge is !testWidth!
  @echo Longer edge is !testHeight!
  SET sliceSize=1x!testHeight!
  SET /A slicesPerFrame=%testWidth%
)
@echo Slice size is !sliceSize!
@echo Slices Per Frame: !slicesPerFrame!

REM remove test file dont forget that windows folder separator is \ and not /
IF EXIST !outputFolder!\test.tiff DEL /F !outputFolder!\test.tiff
@echo Deleted temporary TIFF file !outputFolder!\test.tiff

REM all frames to TIFF files.
REM @echo Extracting %panSize% frames to output folder !outputFolder!/
REM start /W cmd /C ffmpeg -i !inputFile! -an -y -compression_algo raw -pix_fmt rgb24 !outputFolder!/%%08d.tiff


set tiffCount=0
for /f %%i in ('cd !outputFolder!^&dir /b *.tiff ^|find /c /v ""') do @call set tiffCount=%%i
@echo %tiffCount% TIFFs saved to !outputFolder!/
@echo Original estimate was %panSize%


REM Discover the scope of work.
SET /A totalSlices = tiffCount*slicesPerFrame
SET /A completedSlices = 0

@echo Scope of Work: !totalSlices! Slices


REM FOR /L %%param IN (start,step,end) DO command
FOR /L %%G IN (1,1,%tiffCount%) DO (

  SET fileID=0000000%%G
  SET fileID=!fileID:~-8!

  if not exist "!outputFolder!\!fileID!" mkdir "!outputFolder!\!fileID!"

  @echo.
  @echo ======================
  @echo Frame %%G of %tiffCount%
  @echo ======================
  @echo Created sub-folder !outputFolder!\!fileID! to hold slices for frame %%G
  @echo Dividing !outputFolder!\!fileID!.tiff into !slicesPerFrame! slices.
  @echo convert !outputFolder!\!fileID!.tiff -crop !sliceSize! !outputFolder!\!fileID!\%%d.tiff
  convert !outputFolder!\!fileID!.tiff -crop !sliceSize! !outputFolder!\!fileID!\%%d.tiff
  SET /A completedSlices+=%slicesPerFrame%
  @echo Created !slicesPerFrame! new slices.
  @echo Overall progress: !completedSlices! of !totalSlices! slices complete.

  REM to confirm success, maybe count the number of files in !outputFolder!/%%G
)

REM delete temporary TIFFs
FOR /L %%G IN (0,1,%tiffCount%) DO (
  SET fileID=0000000%%G
  SET fileID=!fileID:~-8!
  
  @echo Removing temporary TIFF frame %%G
  IF EXIST !outputFolder!\!fileID!.tiff DEL /F !outputFolder!\!fileID!.tiff
  @echo Deleted !outputFolder!\!fileID!.tiff
)

IF EXIST !avsFile! DEL /F !avsFile!
IF EXIST !ffindexFile! DEL /F !ffindexFile!

@echo Finished.
