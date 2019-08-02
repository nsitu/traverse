@echo off
SETLOCAL enabledelayedexpansion

IF "%~1"=="" (
@echo ===========================================================
@echo  PAN: generate a video by panning the length of an image
@echo ===========================================================
@echo - Video height will match input image
@echo - Video width calculated from height via 16:9 proportion
@echo - User specifies a pan rate, default is 30 pixels per second
@echo - Video duration is calculated from pan rate.
@echo ------------------------
@echo USAGE: pan.bat filename [panRate] [vScale]
@echo - filename: [string] an image e.g. tiff, jpeg, etc.
@echo - panRate: [int] number pixels per second to pan
@echo - vScale: default is 1080 ; 0 will use source height
@echo ------------------------
@echo OUTPUT: an MP4 video is generated in the same folder
@echo - The output file name will match that of the input file:
@echo - e.g. 'content.tiff' results in 'content.mp4'
exit /b
)

REM if the inputHeight is 1920 but we only want 1080p
REM it will be faster to first scale down the input image.
REM however for future consideration, consider that full resolution
REM allows for more effects (such as Ken Burns, zoom/pan, etc.)

SET inputFile=%1

REM default panRate is 30 pixels per second
IF "%~2" NEQ "" (
  SET  panRate=%2
) ELSE (
  SET  panRate=30
)

IF "%~3" NEQ "" (
  SET  vScale=%3
) ELSE (
  SET  vScale=1080
)

FOR /F %%i in ("%1") do @SET baseName=%%~ni

IF !vScale! EQU "0" (
  REM just use the original file without scaling
  REM i.e. do nothing
  SET outputFile=!baseName!.mp4
  @echo Input is being used directly without any scaling

) ELSE (
  SET scaledFile=!baseName!_!vScale!.tiff
  ffmpeg -i !inputFile! -vf scale=-1:!vScale! !scaledFile!
  @echo Input has been scaled proportionally with height !vScale!px
  SET inputFile=!scaledFile!
  SET outputFile=!baseName!_!vScale!.mp4
)

SET tempTxt=!inputFile!_tmp.txt
SET inputWidth=
SET inputHeight=
SET outputWidth=
SET outputHeight=
SET panLimit=
SET theDuration=

REM create a vb script to handle math
DEL "eval.vbs" >nul 2>&1
@ECHO WScript.Echo Eval^(WScript.Arguments^(0^)^) > "eval.vbs"

REM calcuate width of input file
ffprobe -v error -select_streams v:0 -show_entries stream=width -of csv=s=x:p=0 !inputFile! > !tempTxt!
set /p inputWidth= < !tempTxt!
@echo Image width for !inputFile! is !inputWidth!px ^(via ffprobe^)
del !tempTxt!

REM calcuate height of input file
ffprobe -v error -select_streams v:0 -show_entries stream=height -of csv=s=x:p=0 !inputFile! > !tempTxt!
set /p inputHeight= < !tempTxt!
@echo Image height for !inputFile! is !inputHeight!px ^(via ffprobe^)
del !tempTxt!

REM Calculate video dimensions
FOR /f %%n in ('cscript //nologo eval.vbs "(!inputHeight!*16/9)"') do ( SET outputWidth=%%n)
SET outputHeight=!inputHeight!
@echo Calculate video dimensions assuming 16:9 proportion
@echo Output height: !outputHeight!px (match source)
@echo Output width: !outputWidth!px (!inputHeight!*16/9)

REM Calcuate "panLimit" - i.e. the maximum valid x-position for a rolling crop
REM beyond this limit we would exceed the bounds of the image.
REM we have to subtract the outputWIdth from the input Width
REM because the pan position doesn't actually go all the way to the end.
FOR /f %%n in ('cscript //nologo eval.vbs "(!inputWidth!-!outputWidth!)"') do ( SET panLimit=%%n)

REM calculate duration
FOR /f %%n in ('cscript //nologo eval.vbs "(!panLimit!/!panRate!)"') do ( SET theDuration=%%n)

ffmpeg -loop 1 -i !inputFile! -vf crop=!outputWidth!:!outputHeight!:'min(!panRate!*t,!panLimit!)':0 -t !theDuration! -r 30 !outputFile!
