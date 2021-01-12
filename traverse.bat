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
SET panoramaSize=%2

REM cropEnvelope may be numeric ###, or otherwise it may be "ramp" or "wobble" or "linear"
REM when it is numeric, we interpret the number as a linear position.
REM TODO: run tests to confirm that ramp is working.
REM TODO: adapt the RAMP to work in inverse (eg from 1080>0 instead of 0>1080)

IF "%~3" NEQ "" (
  SET cropEnvelope=%3
) ELSE (
  SET cropEnvelope=linear
)

echo("!cropEnvelope!"|findstr "^[\"][-][1-9][0-9]*[\"]$ ^[\"][1-9][0-9]*[\"]$ ^[\"]0[\"]$">nul&&set /A isNum=1||set /A isNum=0


IF !isNum! gtr 0 (
  REM it is useful to mark the output file with an Id number corresponding to numeric slice position input
  REM it is especially useful to do this with predictable padding of zeroes.
  REM in this way we can further process a series of images as numbered frames in a new video.
  REM for example: ffmpeg -i img%08d.tiff output.mp4

  SET /A fileID = !cropEnvelope!
  REM Add a bunch of zeroes for padding
  SET fileID=0000000!fileID!
  REM only keep the final 8 digits ... should be plenty
  SET fileID=!fileID:~-8!
) else (
  REM if we dont have numeric input it remains useful to mark output with the string cropEnvelope
  SET fileID = !cropEnvelope!
)

FOR /F %%i in ("%1") do @SET baseName=%%~ni
SET avsFile=!baseName!_!fileID!.avs
SET outputFile=!baseName!_!fileID!.tiff
SET tempVideo=!baseName!_!fileID!.avi
SET tempTxt=!inputFile!_!fileID!_tmp.txt
SET ffindexFile=!inputFile!_!fileID!.ffindex
SET vbsFile=!inputFile!_!fileID!_eval.vbs
SET theWidth=1
SET theHeight=1
SET theRotation=0
SET theOptimalRotation=0
SET cropEquation=
SET cropOption=
SET smushOption=
SET rotateOption=
SET theOutputWidth=


REM if a desired panorama size is given, calculate the necessary framerate
REM and frame-interpolate the Video on the fly by generating an .avs script
REM a panoramaSize of 0 is interpreted as "match the frame count"
IF "%~2" NEQ "" (


    if !panoramaSize! EQU 0 (
      @echo Default Panorama size requested via zero parameter. Frame count will be used.
    ) else (
      @echo Requested panorama size: !panoramaSize!
    )


    REM we will need vbscript to do floating point math.
    REM therefore step 1 is to create a vbs script
    REM start with a clean slate

    DEL !vbsFile! >nul 2>&1
    @ECHO WScript.Echo Eval^(WScript.Arguments^(0^)^) > "!vbsFile!"

    REM get duration and framerate info from the input file using mediainfo
    mediainfo --Inform="Video;%%Duration%%" !inputFile! > DUR!tempTxt!
    SET /p theDuration=<DUR!tempTxt!
    DEL DUR!tempTxt!
    mediainfo --Inform="Video;%%FrameRate%%" !inputFile! > FR!tempTxt!
    SET /p theFrameRate=<FR!tempTxt!
    DEL FR!tempTxt!

    REM derive (approximate) frame count from duration and frame rate
    FOR /f %%n in ('cscript //nologo !vbsFile! "CInt((!theDuration!/1000)*!theFrameRate!)"') do ( SET theFrameCount=%%n )

    REM output calculated values
    @echo Duration: !theDuration! milliseconds ^(via mediainfo^)
    @echo FrameRate: !theFrameRate! frames per second ^(via mediainfo^)
    @echo Frame Count: !theFrameCount! frames ^(calculated^)

    REM if 0 is given for panoramaSize, we will use the frameCount.
    if !panoramaSize! EQU 0 (
        @echo Panorama size set to !theFrameCount!
        SET panoramaSize=!theFrameCount!
    )

    REM if the framecount is already large enough
    REM (i.e. if the framecount meets or exceeds the desired panorama size)
    REM then we dont need to do any interpolation
    FOR /f %%n in ('cscript //nologo !vbsFile! "!panoramaSize!>!theFrameCount!"') do (
      SET doInterpolation=%%n
    )

    IF !doInterpolation! EQU 0 (
      @echo Frame count !theFrameCount! already meets or exeeds the desired panorama size !panoramaSize!
      @echo No need for any frame interpolation.
    ) ELSE (
      @ECHO Framecount !theFrameCount! is less than the desired panorama size !panoramaSize!
      @ECHO Therefore we will do some frame interpolation.
      REM calculate framerate for interpolation to achieve desired panorama size
      FOR /f %%n in ('cscript //nologo !vbsFile! "CInt((!panoramaSize!/!theFrameCount!)*!theFrameRate!)"') do (  SET theNewFrameRate=%%n  )
       REM output the calculated values

       @echo Desired Panorama Size: !panoramaSize! ^(via input^)
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
    )
)

REM calcuate width of input file
ffprobe -v error -select_streams v:0 -show_entries stream=width -of csv=s=x:p=0 !inputFile! > !tempTxt!
set /p theWidth= < !tempTxt!
@echo video width for !inputFile! is !theWidth!px ^(via ffprobe^)
del !tempTxt!

REM calcuate height of input file
ffprobe -v error -select_streams v:0 -show_entries stream=height -of csv=s=x:p=0 !inputFile! > !tempTxt!
set /p theHeight= < !tempTxt!
@echo video height for !inputFile! is !theHeight!px ^(via ffprobe^)
del !tempTxt!

REM calcuate rotation of input file
ffprobe -loglevel error -select_streams v:0 -show_entries stream_tags=rotate -of default=nw=1:nk=1 -i !inputFile! > !tempTxt!
set /p theRotation= < !tempTxt!
@echo video rotation for !inputFile! is !theRotation! degrees ^(via ffprobe^)
del !tempTxt!


REM If we have a numeric value for the cross section slice Position, use it.
REM Otherwise default to a cross section are taken in the middle of the video
REM this position is either half the width, or half the height




IF !isNum! gtr 0 (
  @echo Provided numeric slice position !cropEnvelope! will inform location of cross section where applicable.
  REM GEQ means greater than or equal to

  IF !cropEnvelope! GEQ !theHeight! (
    @echo Input !cropEnvelope! matches or exceeds video height !theHeight!
    @echo Affected slices will be positioned at !theHeight! instead of !cropEnvelope!
    SET /A ySlicePos =  !theHeight!
  ) ELSE (
    @echo Input !cropEnvelope! falls within the bounds of video height !theHeight!
    @echo Affected slices will be positioned at !cropEnvelope!
    SET /A ySlicePos =  !cropEnvelope!
  )

  REM we should test whether you can actually do a slice or not on the 1st and final pixel.
  REM if not you may need to +1 or -1 as appropriate.
  IF !cropEnvelope! GEQ !theWidth! (
    @echo Input !cropEnvelope! matches or exceeds video width !theWidth!
    @echo Affected slices will be positioned at !theWidth! instead of !cropEnvelope!
    SET /A xSlicePos = !theWidth!
  ) ELSE (
    @echo Input !cropEnvelope! falls within the bounds of video width !theWidth!
    @echo Affected slices will be positioned at !cropEnvelope!
    SET /A xSlicePos = !cropEnvelope!
  )

) ELSE (

  REM if no numeric input is given default to a cross section taken in the middle of the video
  SET /A ySlicePos =  !theHeight! / 2
  SET /A xSlicePos =  !theWidth! / 2
  @echo No numeric input has been given to specify the position of any cross section
  @echo Slicing will proceed with a centeral position
  @echo Horizontal slices will assume !ySlicePos! or half of !theHeight!
  @echo Vertical slices will assume !xSlicePos! or half of !theWidth!
)


REM calculate rotation needed for optimal hypotenuse section.
REM "Atn(height/width)*180/(4*Atn(1))"
FOR /f %%n in ('cscript //nologo !vbsFile! "Atn(!theHeight!/!theWidth!)*180/(4*Atn(1))"') do ( SET theOptimalRotation=%%n )
@echo Optimal Rotation is TAN-1(!theHeight!/!theWidth!)*180/PI: !theOptimalRotation!


IF !theWidth! gtr !theHeight! (


 @echo Landscape Width=!theWidth!, Height=!theHeight!
 @echo Original file is rotated !theRotation! degrees
 IF !theRotation! EQU 90 (
  @echo Treating as if a Portrait Width=!theHeight!, Height=!theWidth!
  @echo Will transpose with Counterclockwise Rotation and Vertical flip.
  IF "!cropEnvelope!" EQU "wobble" (
    SET cropEquation=^(iw^-ow^)^/^2^+^(^(iw^-ow^)^/^2^)^*sin^(^t^)
    @echo Slicing via Dynamic Wobble: !cropEquation!
  ) ELSE (
    IF "!cropEnvelope!" EQU "ramp" (
      SET cropEquation=!theHeight!^*t^*1000^/!theDuration!
      @echo Slicing via Dynamic Ramp: !cropEquation!
    ) ELSE (
      SET cropEquation=!ySlicePos!

      @echo Slicing vertically via fixed X Position: !ySlicePos!
    )
  )
  SET cropOption=crop^=^2^:!theWidth!^:!cropEquation!^:^0^,^transpose^=^0
 ) ELSE (
  IF !theRotation! EQU 270 (
    @echo Treating as if a Portrait Width=!theHeight!, Height=!theWidth!
    @echo Slicing vertically at X Position: !ySlicePos!
    @echo Will transpose with Counterclockwise Rotation and Vertical flip.
    IF "!cropEnvelope!" EQU "wobble" (
      SET cropEquation=^(iw^-ow^)^/^2^+^(^(iw^-ow^)^/^2^)^*sin^(^t^)
      @echo Slicing via Dynamic Wobble: !cropEquation!
    ) ELSE (
      IF "!cropEnvelope!" EQU "ramp" (
        SET cropEquation=!theHeight!^*t^*1000^/!theDuration!
        @echo Slicing via Dynamic Ramp: !cropEquation!
      ) ELSE (
        SET cropEquation=!ySlicePos!
        @echo Slicing horizontally via fixed Y Position: !ySlicePos!
      )
    )
    SET cropOption=crop^=^2^:!theWidth!^:!cropEquation!^:^0^,^transpose^=^0
  ) ELSE (
    REM if we got here then there is no rotation (video is standard)
    IF "!cropEnvelope!" EQU "wobble" (
      SET cropEquation=^(ih^-oh^)^/^2^+^(^(ih^-oh^)^/^2^)^*sin^(^t^)
      @echo Slicing via Dynamic Wobble: !cropEquation!
    ) ELSE (
      IF "!cropEnvelope!" EQU "ramp" (
        SET cropEquation=!theHeight!^*t^*1000^/!theDuration!
        @echo Slicing via Dynamic Ramp: !cropEquation!
      ) ELSE (
        @echo Slicing horizontally via fixed Y Position: !ySlicePos!
        SET cropEquation=!ySlicePos!
      )
    )
    SET cropOption=crop^=!theWidth!^:2^:^0^:!cropEquation!
  )
 )
 SET smushOption=^-smush^ ^-^1
 SET rotateOption=^-rotate^ ^9^0
)
IF !theHeight! gtr !theWidth! (
 @echo Portrait Width=!theWidth!, Height=!theHeight!
 IF !theRotation! EQU 90 (
  @echo Unexpected rotation issues. You do not normally have a natively vertical video with 90 degrees rotation. wtf?
 ) ELSE (
   IF "!cropEnvelope!" EQU "wobble" (
     SET cropEquation=^(iw^-ow^)^/^2^+^(^(iw^-ow^)^/^2^)^*sin^(^t^)
     @echo Slicing via Dynamic Wobble: !cropEquation!
   ) ELSE (
     IF "!cropEnvelope!" EQU "ramp" (
       SET cropEquation=!theWidth!^*t^*1000^/!theDuration!
       @echo Slicing via Dynamic Ramp: !cropEquation!
     ) ELSE (
       @echo Slicing vertically via fixed X Position: !xSlicePos!
       SET cropEquation=!xSlicePos!
     )
   )
   SET cropOption=crop^=!theWidth!^:2^:!cropEquation!^:0
 )
 SET smushOption=^+smush^ ^-1
)
@echo Crop Envelope: !cropEnvelope!
@echo Crop Option: !cropOption!
@echo Cropping Video ffmpeg -i !inputFile! -vf !cropOption! -an !tempVideo!
 ffmpeg -i !inputFile! -vf !cropOption! -an -vcodec rawvideo -y !tempVideo!
 REM ffmpeg -i !inputFile! -vf !cropOption! -an !tempVideo!
rem ffmpeg -i !inputFile! -vf !cropOption! -an %%05d.ppm
REM ffmpeg -i !tempVideo!
@echo Smushing !tempVideo! into !outputFile! using !smushOption!
rem magick convert *.ppm !smushOption! !rotateOption! !outputFile!
 magick convert !tempVideo! !smushOption! !rotateOption! !outputFile!

rem del *.ppm

mediainfo --Inform="Image;%%Width%%" !outputFile! > TIFFWidth!tempTxt!
SET /p theOutputWidth=<TIFFWidth!tempTxt!
DEL TIFFWidth!tempTxt!
mediainfo --Inform="Image;%%Height%%" !outputFile! > TIFFHeight!tempTxt!
SET /p theOutputHeight=<TIFFHeight!tempTxt!
DEL TIFFHeight!tempTxt!

@echo Output File Generated: !outputFile!
@echo TIFF Width: !theOutputWidth!px
@echo TIFF Height: !theOutputHeight!px
IF EXIST !tempVideo! DEL /F !tempVideo!
IF EXIST !avsFile! DEL /F !avsFile!
IF EXIST !tempTxt! DEL /F !tempTxt!
IF EXIST !ffindexFile! DEL /F !ffindexFile!
IF EXIST !vbsFile! DEL /F !vbsFile!

@echo Finished.
