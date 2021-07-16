@echo off
SETLOCAL enabledelayedexpansion

IF "%~1"=="" (
@echo ===========================================================
@echo  BATCH: run a script on more than one file at a time.
@echo ===========================================================
@echo USAGE: batch.bat scriptName fileType parameterOne parameterTwo
@echo - scriptName: another batch file presumed to be in the same folder. e.g. traverse.bat
@echo - fileType: the file extension of input files to look for ... eg. mp4 
@echo - parameterOne, parameterTwo, etc. : parameters passed along to other batch scripts
@echo ------------------------
@echo OUTPUT: depends on which scriptName is invoked. 
exit /b
)
SET scriptName=%1
SET fileType=%2
SET paramOne=%3
SET paramTwo=%4

(for %%i in (*.%2) do start cmd /k %1 %%i %3 %4)

@echo Opened %1 in a new window for all %2 files in this folder
@echo The following parameters were used
@echo Parameter one: %3
@echo Parameter two: %4


