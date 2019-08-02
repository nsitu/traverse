# TRAVERSE.BAT - generate a panoramic cross section from a video

All frames are cropped to 2px slices: e.g. 1920x2 pixels.

Slices are re-assembled with 1px overlap in sequence

Optional: set output panorama length in pixels

Video is then 'stretched' to fit length via frame interpolation

Output is saved as a panorama.

USAGE: traverse.bat filename [length] [envelope]

filename: an mp4, or mkv video

length: desired pixel count for panorama, integer

envelope: slice crop options: linear|wobble|ramp

OUTPUT: a TIFF image file is generated in the same folder

The output file name will match that of the input file:

e.g. 'content.mp4' results in 'content.tiff'

# PAN.BAT - generate a video by panning the length of an image

Video height will match input image

Video width calculated from height via 16:9 proportion

User specifies a pan rate, default is 30 pixels per second

Video duration is calculated from pan rate.

USAGE: pan.bat filename [panRate] [vScale]

filename: [string] an image e.g. tiff, jpeg, etc.

panRate: [int] number pixels per second to pan

vScale: default is 1080 ; 0 will use source height

OUTPUT: an MP4 video is generated in the same folder

The output file name will match that of the input file:

e.g. 'content.tiff' results in 'content.mp4'



# Installing ffmpeg, imagemagick, AviSynth-Plus, FFmpegsource 2, Interframe, MediaInfo

https://www.wikihow.com/Install-FFmpeg-on-Windows

https://imagemagick.org/script/download.php

https://www.videohelp.com/software/AviSynth-Plus

https://github.com/FFMS/ffms2/releases

https://www.spirton.com/interframe/

https://mediaarea.net/en/MediaInfo/Download/Windows


