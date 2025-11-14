# Local Slideshow Generator

I built the script with the help of Copilot to generate slideshows from my picture Gallery hosted on my NAS.

## Why ?
I'm perfectly satisfied with a network share to access my picture gallery. I tried a Digikam Container but it's heavy on my system, I have to access it via a browser, and the interface is not easy to use.

## Features
* The script sorts the files using exiftool and falls back to the filename order if the metadata is missing.
* Downloads the music file from Youtube or uses a local file depending on the options you use
* Music and video fades in at the beginning.

## How to use ?
>./slideshow-generator.sh [-d media_dir] [-f final_output] [-m music_file] [-r resolution] [-y youtube_url] [-t image_duration]

* -d : your media file with pictures and videos
* -f : your target output for the final video
* -m : your music file location. If used with -y, it will download the file on that location an overwrite existing file. Optional if you use -y
* -r : Target resolution
* -t : The duration an picture stays on screen.

## Requirements
* ffmpeg
* ffprobe
* yt-dlp (optional if you use local files)
* exiftool
* bc

## What's missing ? 
* The audio in  a video file seems to be overwritten, I haven't figured that out.
* The fade out is missing
* No transitions between pictures. I have no plan to add it as the complexity of the script will shoot up.

## Sources
According to Copilot, here is what it used to generate this script : 

### FFmpeg Documentation
* https://ffmpeg.org/ffmpeg-filters.html (for fade, amix, volume, scale, pad)
* https://ffmpeg.org/ffmpeg-formats.html#concat (for combining segments)
* https://ffmpeg.org/ffmpeg-filters.html#Audio-Filters (for anullsrc and volume)

### FFprobe Usage
* https://ffmpeg.org/ffprobe.html (for extracting duration and stream info)

### yt-dlp Documentation
* https://github.com/yt-dlp/yt-dlp (for downloading audio from YouTube)

### ExifTool Documentation
* https://exiftool.org/ (for renaming files by DateTimeOriginal)

### Shell Scripting Best Practices
* Using getopts for CLI options
* Error handling with || exit 1
* Sorting files with ls | sort for chronological order
### Community Examples
* https://stackoverflow.com/questions/tagged/ffmpeg
* https://trac.ffmpeg.org/wiki/Concatenate
