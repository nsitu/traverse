# traverse
A windows batch script to make cross sections of videos, flattening them into panoramic tiffs.

uses ffmpeg, image magick, mediainfo, ffprobe, and AviSynth

employs vbscript to do floating point math.

generates .avs files for frame interpolation.

Parameter 1: a video file. I use mp4

Parameter 2: desired length of panorama

# Example
The following command will result in a tiff file 20000 pixels wide. The height of the tiff will match the longest dimension of the original video.

C:\>traverse.bat video.mp4 20000

# Installing ffmpeg and image magick
https://www.wikihow.com/Install-FFmpeg-on-Windows
https://imagemagick.org/script/download.php
