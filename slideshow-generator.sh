#!/bin/bash

# =========================
# Internal configuration
# =========================
THREADS=2           # Limit FFmpeg threads
PRESET="fast"       # Encoding preset
MUSIC_VOL=0.3       # Music volume (0.0 to 1.0)
FADE_DUR=2          # Fade duration in seconds
TMP_DIR="./tmp_segments"
SORTED_DIR="./sorted_media"
TMP_LIST="concat.txt"

# =========================
# Default CLI values
# =========================
IMG_DIR="./media"
FINAL_OUTPUT="final_slideshow.mp4"
MUSIC_FILE="music.mp3"
RESOLUTION="1280:720"
YOUTUBE_URL=""
DURATION_PER_IMAGE=3

# =========================
# Parse CLI options
# =========================
while getopts d:f:m:r:y:t: flag; do
    case "${flag}" in
        d) IMG_DIR="${OPTARG}" ;;
        f) FINAL_OUTPUT="${OPTARG}" ;;
        m) MUSIC_FILE="${OPTARG}" ;;
        r) RESOLUTION="${OPTARG}" ;;
        y) YOUTUBE_URL="${OPTARG}" ;;
        t) DURATION_PER_IMAGE="${OPTARG}" ;;
        *) echo "Usage: $0 [-d media_dir] [-f final_output] [-m music_file] [-r resolution] [-y youtube_url] [-t image_duration]" && exit 1 ;;
    esac
done

# Validate dependencies
for cmd in ffmpeg ffprobe exiftool bc; do
    command -v $cmd >/dev/null 2>&1 || { echo "❌ $cmd is not installed"; exit 1; }
done
if [[ -n "$YOUTUBE_URL" ]]; then
    command -v yt-dlp >/dev/null 2>&1 || { echo "❌ yt-dlp is required for YouTube download"; exit 1; }
fi

# Download audio if YouTube URL provided
if [[ -n "$YOUTUBE_URL" ]]; then
    echo "Downloading audio from YouTube..."
    yt-dlp -x --audio-format mp3 -o "$MUSIC_FILE" "$YOUTUBE_URL" || { echo "❌ yt-dlp failed"; exit 1; }
fi

mkdir -p "$SORTED_DIR" "$TMP_DIR"
> "$TMP_LIST"

# Sort media by EXIF date (fallback to file order)
echo "Sorting media..."
exiftool '-FileName<DateTimeOriginal' -d "%Y%m%d_%H%M%S%%-c.%%e" -o "$SORTED_DIR" "$IMG_DIR" || cp "$IMG_DIR"/* "$SORTED_DIR"

# Process all files in chronological order
echo "Processing media..."
for file in $(ls "$SORTED_DIR"/*.{jpg,mp4} 2>/dev/null | sort); do
    seg="$TMP_DIR/$(basename "$file" .jpg).mp4"
    if [[ "$file" == *.jpg ]]; then
        # Convert image to MP4 with silent audio
        ffmpeg -threads $THREADS -y -loop 1 -t $DURATION_PER_IMAGE -i "$file" \
        -vf "scale=$RESOLUTION:force_original_aspect_ratio=decrease,pad=$RESOLUTION:(ow-iw)/2:(oh-ih)/2:black" \
        -r 30 -c:v libx264 -pix_fmt yuv420p -c:a aac -af "anullsrc=channel_layout=stereo:sample_rate=44100" "$seg" || exit 1
    else
        # Normalize MP4 video (keep audio)
        ffmpeg -threads $THREADS -y -i "$file" \
        -vf "scale=$RESOLUTION:force_original_aspect_ratio=decrease,pad=$RESOLUTION:(ow-iw)/2:(oh-ih)/2:black" \
        -r 30 -c:v libx264 -pix_fmt yuv420p -c:a aac "$seg" || exit 1
    fi
    echo "file '$seg'" >> "$TMP_LIST"
done

if [[ ! -s "$TMP_LIST" ]]; then
    echo "❌ No media files found in $IMG_DIR"
    exit 1
fi

# Concatenate all segments (re-encode for fades)
echo "Creating combined video..."
ffmpeg -threads $THREADS -y -f concat -safe 0 -i "$TMP_LIST" \
-c:v libx264 -pix_fmt yuv420p -r 30 -c:a aac combined.mp4 || exit 1

# Get duration
DURATION=$(ffprobe -v error -show_entries format=duration -of csv=p=0 combined.mp4)
VIDEO_FADE_OUT_START=$(echo "$DURATION - $FADE_DUR" | bc)

# Detect audio
HAS_AUDIO=$(ffprobe -v error -select_streams a -show_entries stream=codec_type -of csv=p=0 combined.mp4)

if [[ -z "$HAS_AUDIO" ]]; then
    FILTER="[0:v]fade=t=in:st=0:d=$FADE_DUR,fade=t=out:st=$VIDEO_FADE_OUT_START:d=$FADE_DUR[v]; [1:a]volume=1.0[a]"
    MAPS="-map [v] -map [a]"
else
    FILTER="[0:v]fade=t=in:st=0:d=$FADE_DUR,fade=t=out:st=$VIDEO_FADE_OUT_START:d=$FADE_DUR[v]; \
[0:a]volume=1.0[a0]; [1:a]volume=$MUSIC_VOL[a1]; [a0][a1]amix=inputs=2:duration=longest[a]"
    MAPS="-map [v] -map [a]"
fi

# Apply fades and mix audio
echo "Adding music and fades..."
ffmpeg -threads $THREADS -y -i combined.mp4 -i "$MUSIC_FILE" \
-filter_complex "$FILTER" $MAPS -c:v libx264 -c:a aac -t $DURATION "$FINAL_OUTPUT" || exit 1

# Cleanup
rm -rf "$TMP_DIR" "$TMP_LIST" combined.mp4 "$SORTED_DIR"
if [[ -n "$YOUTUBE_URL" ]]; then
    rm -f "$MUSIC_FILE"
    echo "Deleted downloaded music file: $MUSIC_FILE"
fi
echo "✅ Done! Final video: $FINAL_OUTPUT"
