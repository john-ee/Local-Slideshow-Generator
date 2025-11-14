# Local Slideshow Generator

I built the script with the help of Copilot to generate slideshows from my picture gallery hosted on my NAS.

## Why ?
I'm perfectly satisfied with a network share to access my picture gallery. I tried a Digikam Container and the interface is heavy for my use case.
Paired with a Discord bot I have that runs command, I can easily generate slideshows with this script.

## Features
* Sorts file with metadata via Exiftool. Falls back to file order if some files are missing metadata.
* Downloads the music file from Youtube or uses a local file depending on the options you use
* Watermarks the video with the Youtube URL if you use one.
* Music and video fades in and out at the beginning and the end.
* Music volume is lower throughout the whole video if there are mp4 videos with audio.

## How to use ?
>./slideshow-generator.sh [-d media_dir] [-f final_output] [-m music_file] [-r resolution] [-y youtube_url] [-t image_duration]

* -d : your media file with pictures and videos
* -f : your target output for the final video
* -m : your music file location. If used with -y, it will download the file on that location an overwrite existing file. Optional if you use -y
* -r : Target resolution
* -t : The duration an picture stays on screen.
* -y : A youtube link to a video

## Requirements
* ffmpeg
* ffprobe
* yt-dlp (optional if you use local files)
* exiftool
* bc
* jq

## What's missing ? 
* No transitions between pictures.
* The music volume is not dynamic

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
