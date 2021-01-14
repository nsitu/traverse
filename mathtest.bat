<!-- :

@echo off
SETLOCAL enabledelayedexpansion

REM This is a Batch File / VBScript Hybrid.
REM VB Script is located at the end of this file.
REM VB Script is invoked to help with Math.
REM See also: https://stackoverflow.com/questions/9074476/

@echo testing VBScript
cscript //nologo "%~f0?.wsf"  50000 240 //job:VBS
exit /b

--->
<package>
  <job id="VBS">
    <script language="VBScript">
      WScript.Echo CLng((WScript.Arguments(0)/1000)*WScript.Arguments(1))
    </script>
  </job>
</package>
