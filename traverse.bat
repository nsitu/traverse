@echo off
SETLOCAL enabledelayedexpansion

IF "%~1"=="" (
@echo ===========================================================
@echo  TRAVERSE: generate a panoramic cross section from a video
@echo ===========================================================
@echo - All frames are cropped to 2px slices: e.g. 1920x2 pixels.
@echo - Slices are re-assembled with 1px overlap in sequence
@echo - Optional: set output panorama length in pixels
@echo - Video is then 'stretched' to fit length via frame interpolation
@echo - Output is saved as a panorama_envelope.tiff
@echo ------------------------
@echo USAGE: traverse.bat filename [length] [envelope]
@echo - filename: an mp4, or mkv video
@echo - length: desired pixel count for panorama, integer
@echo - envelope: slice crop options: ###|linear|wobble|ramp
@echo ------------------------
@echo OUTPUT: a TIFF image file is generated in the same folder
@echo - The output file name will match that of the input file:
@echo - The envelope settings will be appended
@echo - e.g. 'content.mp4' results in 'content_envelope.tiff'
exit /b
)

REM TODO
REM use input file length to automate a ramp/envelope equation

SET inputFile=%1

IF "%~2" == "" ( SET /A panSize=0 ) ELSE ( SET panSize=%2 )
IF "%~3" == "" ( SET /A cropEnv=0 ) ELSE ( SET cropEnv=%3 )

SET "panSizeTest="&for /f "delims=0123456789" %%i in ("%2") do set panSizeTest=%%i
IF defined panSizeTest ( SET /A panSizeIsNumeric = 0 ) ELSE ( SET /A panSizeIsNumeric = 1  )

SET "cropEnvTest="&for /f "delims=0123456789" %%k in ("%3") do set cropEnvTest=%%k
IF defined cropEnvTest ( SET /A cropEnvIsNumeric = 0 ) ELSE ( SET /A cropEnvIsNumeric = 1  )



REM Check if inputs are numeric



if %cropEnvIsNumeric% EQU 1 (
  REM it is useful to mark the output file with an Id number corresponding to numeric slice position input
  REM it is especially useful to do this with predictable padding of zeroes.
  REM in this way we can further process a series of images as numbered frames in a new video.
  REM for example: ffmpeg -i img%08d.tiff output.mp4
  REM Add a bunch of zeroes for padding
  REM only keep the final 8 digits ... should be plenty
  SET /A fileID = !cropEnv!
  SET fileID=0000000!fileID!
  SET fileID=!fileID:~-8!
) else (
  REM set default in case it is blank.
  IF [!cropEnv!] EQU [] ( SET cropEnv=linear )
  REM if we dont have numeric input it remains useful to mark output with the string cropEnv
  SET fileID = !cropEnv!
)

FOR /F %%i in ("%1") do @SET baseName=%%~ni
SET avsFile=!baseName!_!fileID!.avs
SET outputFile=!baseName!_!fileID!.tiff
SET tempVideo=!baseName!_!fileID!.avi
SET tempFolder=!baseName!_!fileID!_slices
SET ffindexFile=!inputFile!_!fileID!.ffindex
SET vbsFile=!inputFile!_!fileID!_eval.vbs
SET theWidth=1
SET theHeight=1
SET theRotation=0
SET cropEquation=
SET cropOption=
SET tileOption=
SET rotateOption=
SET theOutputWidth=

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
  goto :duration
)
:duration
for /f "tokens=2 delims=: " %%j in ( 'mediainfo -f !inputFile! ^|find "Duration"' ) do (
  SET /A theDuration=%%j
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
@echo !theDuration! milliseconds (duration)
@echo !theRotation! degrees (rotation)
@echo !theHeight! px (height)
@echo !theWidth! px (width)
@echo !thePixelAspectRatio! (pixel aspect ratio)
@echo !theDisplayAspectRatio! (display aspect ratio)


REM given the limits of PHotoshop, if there are more than 300,000 frames  we might impose a limit.

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
       REM avs files dont have rotation
       SET theRotation=0

    )

) ELSE (
  @echo Paramater not supplied for panorama size.
  @echo Panorama size set to match frame count: !theFrameCount! frames
  SET /A panSize=%theFrameCount%
)


REM we assume that the avs file has the same width height and rotation as the original.




REM If we have a numeric value for the cross section slice Position, use it.
REM Otherwise default to a cross section are taken in the middle of the video
REM this position is either half the width, or half the height
@echo.
@echo ==========================
@echo Slicing
@echo ==========================
if %cropEnvIsNumeric% EQU 1 (

  @echo Provided numeric slice position !cropEnv! will inform location of cross section where applicable.
  REM GEQ means greater than or equal to

  IF !cropEnv! GEQ !theHeight! (
    @echo Input !cropEnv! matches or exceeds video height !theHeight!
    @echo Affected slices will be positioned at !theHeight! instead of !cropEnv!
    SET /A ySlicePos =  !theHeight!
  ) ELSE (
    @echo Input !cropEnv! falls within the bounds of video height !theHeight!
    @echo Affected slices will be positioned at !cropEnv!
    SET /A ySlicePos =  !cropEnv!
  )

  REM we should test whether you can actually do a slice or not on the 1st and final pixel.
  REM if not you may need to +1 or -1 as appropriate.
  IF !cropEnv! GEQ !theWidth! (
    @echo Input !cropEnv! matches or exceeds video width !theWidth!
    @echo Affected slices will be positioned at !theWidth! instead of !cropEnv!
    SET /A xSlicePos = !theWidth!
  ) ELSE (
    @echo Input !cropEnv! falls within the bounds of video width !theWidth!
    @echo Affected slices will be positioned at !cropEnv!
    SET /A xSlicePos = !cropEnv!
  )

) ELSE (

  REM if no numeric input is given default to a cross section taken in the middle of the video
  SET /A ySlicePos =  !theHeight! / 2
  SET /A xSlicePos =  !theWidth! / 2
  @echo No numeric input has been given to specify the position of any cross section
  @echo Slicing will proceed with a central position
  @echo Horizontal slices will assume !ySlicePos! or half of !theHeight!
  @echo Vertical slices will assume !xSlicePos! or half of !theWidth!
)

REM TODO calculate rotation needed for optimal hypotenuse section.
REM "Atn(height/width)*180/(4*Atn(1))"
REM FOR /f %%n in ('cscript //nologo !vbsFile! "Atn(!theHeight!/!theWidth!)*180/(4*Atn(1))"') do ( SET theOptimalRotation=%%n )
REM @echo Optimal Rotation is TAN-1(!theHeight!/!theWidth!)*180/PI: !theOptimalRotation!

IF !theWidth! gtr !theHeight! (

 @echo Landscape Width=!theWidth!, Height=!theHeight!
 @echo Original file is rotated !theRotation! degrees
 IF !theRotation! EQU 90 (
  @echo Treating as if a Portrait Width=!theHeight!, Height=!theWidth!
  @echo Will transpose with Counterclockwise Rotation and Vertical flip.
  IF "!cropEnv!" EQU "wobble" (
    SET cropEquation=^(iw^-ow^)^/^2^+^(^(iw^-ow^)^/^2^)^*sin^(^t^)
    @echo Slicing via Dynamic Wobble: !cropEquation!
  ) ELSE (
    IF "!cropEnv!" EQU "ramp" (
      SET cropEquation=!theHeight!^*t^*1000^/!theDuration!
      @echo Slicing via Dynamic Ramp: !cropEquation!
    ) ELSE (
      SET cropEquation=!ySlicePos!

      @echo Slicing vertically via fixed X Position: !ySlicePos!
    )
  )
  SET cropOption=crop^=^1^:!theWidth!^:!cropEquation!^:^0^:exact^=1,^transpose^=^0

 ) ELSE (
  IF !theRotation! EQU 270 (
    @echo Treating as if a Portrait Width=!theHeight!, Height=!theWidth!
    @echo Slicing vertically at X Position: !ySlicePos!
    @echo Will transpose with Counterclockwise Rotation and Vertical flip.
    IF "!cropEnv!" EQU "wobble" (
      SET cropEquation=^(iw^-ow^)^/^2^+^(^(iw^-ow^)^/^2^)^*sin^(^t^)
      @echo Slicing via Dynamic Wobble: !cropEquation!
    ) ELSE (
      IF "!cropEnv!" EQU "ramp" (
        SET cropEquation=!theHeight!^*t^*1000^/!theDuration!
        @echo Slicing via Dynamic Ramp: !cropEquation!
      ) ELSE (
        SET cropEquation=!ySlicePos!
        @echo Slicing horizontally via fixed Y Position: !ySlicePos!
      )
    )
    SET cropOption=crop^=^1^:!theWidth!^:!cropEquation!^:^0^:exact^=1,^transpose^=^0
  ) ELSE (
    REM if we got here then there is no rotation (video is standard)
    IF "!cropEnv!" EQU "wobble" (
      SET cropEquation=^(ih^-oh^)^/^2^+^(^(ih^-oh^)^/^2^)^*sin^(^t^)
      @echo Slicing via Dynamic Wobble: !cropEquation!
    ) ELSE (
      IF "!cropEnv!" EQU "ramp" (
        SET cropEquation=!theHeight!^*t^*1000^/!theDuration!
        @echo Slicing via Dynamic Ramp: !cropEquation!
      ) ELSE (
        @echo Slicing horizontally via fixed Y Position: !ySlicePos!
        SET cropEquation=!ySlicePos!
      )
    )
    SET cropOption=crop^=!theWidth!^:1^:^0^:!cropEquation!^:exact^=1
  )
 )
 SET tileOption=tile=1x!panSize!
 SET rotateOption=^-rotate^ ^9^0
)
IF !theHeight! gtr !theWidth! (
 @echo Portrait Width=!theWidth!, Height=!theHeight!
 IF !theRotation! EQU 90 (
  @echo Unexpected rotation issues. You do not normally have a natively vertical video with 90 degrees rotation. wtf?
 ) ELSE (
   IF "!cropEnv!" EQU "wobble" (
     SET cropEquation=^(iw^-ow^)^/^2^+^(^(iw^-ow^)^/^2^)^*sin^(^t^)
     @echo Slicing via Dynamic Wobble: !cropEquation!
   ) ELSE (
     IF "!cropEnv!" EQU "ramp" (
       SET cropEquation=!theWidth!^*t^*1000^/!theDuration!
       @echo Slicing via Dynamic Ramp: !cropEquation!
     ) ELSE (
       @echo Slicing vertically via fixed X Position: !xSlicePos!
       SET cropEquation=!xSlicePos!
     )
   )
   REM SET cropOption=crop^=!theWidth!^:1^:!cropEquation!^:0:exact=1
   SET cropOption=crop^=1^:!theHeight!^:!cropEquation!^:0:exact=1
 )
 SET tileOption=tile=!panSize!x1
)

@echo Crop Envelope: !cropEnv!
@echo Crop Option: !cropOption!

REM in ffmpeg you can disable audio with the -an flag
REM in ffmpeg you can overwrite output file with the -y flag

REM ffmpeg -i video.webm -ss 00:00:10 -vframes 1 thumbnail.png
REM ffmpeg -i video.webm -vf fps=!theFrameRate!

@echo Creating temporary folder !tempFolder! to hold slices
if not exist "!tempFolder!" mkdir "!tempFolder!%"

REM Its possible that saving to TIFF files per-frame has a lower fps than saving slices to RAW video.
REM however it allows us to use ffmpeg for tiling the files rather than using  imagemagick.

@echo Extracting One-pixel-wide TIFF slices from video.
@echo start /W cmd /C ffmpeg -i !inputFile! -vf !cropOption! -an -y -compression_algo raw -pix_fmt rgb24 !tempFolder!/img-^%^%08d.tiff
start /W cmd /C ffmpeg -i !inputFile! -vf !cropOption! -an -y -compression_algo raw -pix_fmt rgb24 !tempFolder!/img-%%08d.tiff

@echo.
@echo ==================
@echo Tiling
@echo ==================
@echo Assembling !panSize! TIFFs into a single image.
@echo start /W cmd /C ffmpeg -i !tempFolder!/img-^%^%08d.tiff -filter_complex !tileOption! !outputFile!
REM for less verbose output use ffmpeg  -hide_banner -loglevel panic

start /W cmd /C ffmpeg -i !tempFolder!/img-%%08d.tiff -filter_complex !tileOption! !outputFile!

REM magick convert !tempVideo! !smushOption! !rotateOption! !outputFile!
@echo.
@echo ==================
@echo Cleanup
@echo ==================
@echo Removing temporary TIFF slices.
IF EXIST !tempFolder! DEL /F /Q !tempFolder!
@echo Removing temporary slice folder !tempFolder!
IF EXIST !tempFolder! RMDIR /S /Q !tempFolder!

:tiffWidth
for /f "tokens=2 delims=: " %%j in ( 'mediainfo -f !outputFile! ^|find "Width"' ) do (
  SET  theOutputWidth=%%j
  goto:tiffHeight
)
:tiffHeight
for /f "tokens=2 delims=: " %%j in ( 'mediainfo -f !outputFile! ^|find "Height"' ) do (
  SET theOutputHeight=%%j
  goto:conclude
)
:conclude

IF EXIST !avsFile! DEL /F !avsFile!
IF EXIST !ffindexFile! DEL /F !ffindexFile!
IF EXIST !vbsFile! DEL /F !vbsFile!

@echo Output File Generated: !outputFile!
@echo TIFF Width: !theOutputWidth!px
@echo TIFF Height: !theOutputHeight!px
@echo Finished.
