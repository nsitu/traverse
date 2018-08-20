# traverse
A windows batch script using ffmpeg and image magick to make cross sections of videos, flattening them into panoramic tiffs

Parameter 1: a video file. I use mp4
Parameter 2: a number, indicating the width of the slice to use per frame. default is 2. 

# Example
The following command will result in a tiff file of 2x framecount pixels:

C:\>traverse.bat video.mp4 2
