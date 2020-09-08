@echo off
SETLOCAL enabledelayedexpansion

IF "%~1"=="" (
@echo ===========================================================
@echo  CONCAT: use ffmpeg to combine multiple videos into one.
@echo ===========================================================
@echo USAGE: concat.bat extension
@echo - extension: a file extension, e.g. mp4, or mkv, mts
@echo - note: file extension is not case-sensitive
@echo ------------------------
@echo OUTPUT: a video file is generated in the same folder
@echo - The order of concatenation is to sort the files by name
@echo - The output file extension will match the provided extension
@echo - e.g. if 'mp4' is specified, the result will be 'output.mp4'
exit /b
)

SET fileType=%1

(for %%i in (*.%1) do @echo file '%%i') > mylist.txt

ffmpeg -f concat -safe 0 -i mylist.txt -c copy output.%1

DEL /F mylist.txt


@echo Finished concatenating all %1 files. See output.%1

