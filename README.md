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
http://www.svp-team.com/files/gpl/svpflow-4.2.0.142.zip  
https://www.spirton.com/interframe/  
https://mediaarea.net/en/MediaInfo/Download/Windows  
  
# Notes about video frame interpolation on windows.  
I found that I could increase the frame rate on videos to generate smoother motion. This in turn allows for cross sections to also be smoother: i.e devoid of "jaggies" (jagged edges due to strips misaligning). I think I could probably apply this to already high-framerate videos, such that 120fps becomes 240 or even higher (havent tested the limits of this).

# AviSynth+   
I found the latest version here:  https://www.videohelp.com/software/AviSynth-Plus  
Note that the version on http://www.avs-plus.net/ is outdated  
AviSynth+ is a "frame server" that lets you write scripts (.avs files) that programmatically generates frames (e.g. by performing some actions on existing videos). These .avs files can then be loaded by other software (e.g. media players, converters, etc.). In a media player you might use the avs file a bit like a guitar pedal, in realtime. In a converter it lets you save the transformations applied into a new video file.   
  
# ffms2(FFmpegsource 2)  
https://github.com/FFMS/ffms2/releases  
This can be used as a plugin that allows avisynth to open .mp4 files.  
Just dump the x86/64 versions of the ffms2.dll into the AviSynth plugins folders  
C:\Program Files (x86)\AviSynth+\plugins  
C:\Program Files (x86)\AviSynth+\plugins64  
You can then do something like this in an .avs file:  
FFmpegsource2("video.mp4")  
  
# SVPFlow  
There are some DLLs from the smooth video project (SVP) that you need to do interpolation.  
svpflow1.dll: a motion vectors search plugin  
svpflow2.dll: A closed-source frame rendering plugin.  
Get information here: https://www.svp-team.com/wiki/Download#libs  
Get a direct Download here: http://www.svp-team.com/files/gpl/svpflow-4.2.0.142.zip  
In my case I used the 64 bit versions.  
These are named svpflow1_64.dll and svpflow2_64.dll and are included inside of the zip: in the folder lib-windows\avisynth\x64  
In my case I copied these to C:\Program Files (x86)\AviSynth+\plugins64  
  
# InterFrame   
InterFrame is an avs script to assist with increasing frame rates.  https://www.spirton.com/interframe/  
Documentation: https://www.spirton.com/uploads/InterFrame/InterFrame2.html  
Technically it is a Plugin for AVISynth. It's basically a function inside of an .avsi file.   
You have to put the .avsi file into the plugins folder as per these instructions: http://avisynth.nl/index.php/AVSI  
This makes the function available to any AVS script  
In my case I placed the InterFrame2.avsi inside of C:\Program Files (x86)\AviSynth+\plugins64  
You also need to copy the SVPFlow DLLS (already mentioned above). for convenience, it comes packaged with them.   
However, Since these are not 64bit version, so I used the ones from SVP instead.  
  
# Media Player Classic  
A good tool for testing out avs files.  
https://mpc-hc.org/  
  
# Syntax Hilighting.  
You can get Atom Syntax Hilighting for AVS files to make it easier to work on avs scripts.  
https://atom.io/packages/language-avisynth  
  
# Internet Friendly Media Encoder  
This is a media encoder that allows you to import .avs files (AviSynth files) and export them.  
https://x265.github.io/  
  
# Example .avs Script for AviSynth+ to convert frame rate up to 120 (store in same folder as video)  
Video="caution.mp4"  
Core=4  
NewNum=120  
NewDen=1  
Preset="ultrafast"  
Tuning="Film"  
UseGPU=true  
FFmpegsource2(Video).ConvertToYV12()  
InterFrame(Cores=Core, Preset=Preset, Tuning=Tuning, NewNum=NewNum, NewDen=NewDen, GPU=UseGPU)  
  
# Note about .avs files and apparent Cropping Limits  
You apparently need at least 80px on the short side of any video clip in order for avs to work on it.   
Examples:   
1920x80 works fine but 1920x79 does not  
848x80 works fine but 848x79 does not  
Any less, and the .avs file reports a width and height of 1px to ffprobe  
I don't know if this is an interframe or an avs limitation.   
  
# FFMpeg Preset parameter notes:  
I've read various things about this parameter and have not thoroughly tested it, so the following may be incorrect. From what I gather, however, the default preset is "medium". The preset determines how fast the encoding process will be – at the expense of compression efficiency. Put differently, if you choose ultrafast, the encoding process is going to run fast, but the file size will be larger when compared to medium. The visual quality will be the same. Valid presets are Medium Fast Faster Fastest.   


