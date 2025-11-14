#!/bin/bash

# =========================
# Internal configuration
# =========================
THREADS=2           # Limit FFmpeg threads
PRESET="fast"       # Encoding preset (ultrafast, superfast, veryfast, fast, medium, slow)
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

# =========================
# Validate dependencies
# =========================
for cmd in ffmpeg ffprobe exiftool bc; do
    command -v $cmd >/dev/null 2>&1 || { echo "❌ $cmd is not installed"; exit 1; }
done
if [[ -n "$YOUTUBE_URL" ]]; then
    command -v yt-dlp >/dev/null 2>&1 || { echo "❌ yt-dlp is required for YouTube download"; exit 1; }
fi

# =========================
# Pre Cleanup in case of previous error
# =========================
rm -rf "$TMP_DIR" "$TMP_LIST" combined.mp4


# =========================
# Download audio if YouTube URL provided
# =========================
if [[ -n "$YOUTUBE_URL" ]]; then
    echo "Downloading audio from YouTube..."
    yt-dlp -x --audio-format mp3 -o "$MUSIC_FILE" "$YOUTUBE_URL" || { echo "❌ yt-dlp failed"; exit 1; }
fi

# =========================
# Prepare folders
# =========================
mkdir -p "$SORTED_DIR" "$TMP_DIR"
> "$TMP_LIST"

# =========================
# Sort media by EXIF date (fallback to file order)
# =========================
echo "Sorting media..."
exiftool '-FileName<DateTimeOriginal' -d "%Y%m%d_%H%M%S%%-c.%%e" -o "$SORTED_DIR" "$IMG_DIR" || cp "$IMG_DIR"/* "$SORTED_DIR"

# =========================
# Convert images to MP4 segments
# =========================
echo "Processing images..."
for img in $(ls "$SORTED_DIR"/*.jpg 2>/dev/null | sort); do
    seg="$TMP_DIR/$(basename "$img" .jpg).mp4"
    ffmpeg -threads $THREADS -y -loop 1 -t $DURATION_PER_IMAGE -i "$img" \
    -vf "scale=$RESOLUTION:force_original_aspect_ratio=decrease,pad=$RESOLUTION:(ow-iw)/2:(oh-ih)/2:black" \
    -r 30 -c:v libx264 -pix_fmt yuv420p "$seg" || { echo "❌ Failed to process $img"; exit 1; }
    echo "file '$seg'" >> "$TMP_LIST"
done

# =========================
# Normalize MP4 videos and add to concat list
# =========================
echo "Processing videos..."
for vid in $(ls "$SORTED_DIR"/*.mp4 2>/dev/null | sort); do
    seg="$TMP_DIR/$(basename "$vid")"
    ffmpeg -threads $THREADS -y -i "$vid" \
    -vf "scale=$RESOLUTION:force_original_aspect_ratio=decrease,pad=$RESOLUTION:(ow-iw)/2:(oh-ih)/2:black" \
    -r 30 -c:v libx264 -pix_fmt yuv420p -c:a aac "$seg" || { echo "❌ Failed to process $vid"; exit 1; }
    echo "file '$seg'" >> "$TMP_LIST"
done

# =========================
# Check if we have segments
# =========================
if [[ ! -s "$TMP_LIST" ]]; then
    echo "❌ No media files found in $IMG_DIR"
    exit 1
fi

# =========================
# Concatenate all segments
# =========================
echo "Creating combined video..."
ffmpeg -threads $THREADS -y -f concat -safe 0 -i "$TMP_LIST" -c copy combined.mp4 || { echo "❌ Failed to create combined video"; exit 1; }

# =========================
# Get video duration
# =========================
DURATION=$(ffprobe -v error -show_entries format=duration -of csv=p=0 combined.mp4)
if [[ -z "$DURATION" ]]; then
    echo "❌ Could not determine video duration"
    exit 1
fi

VIDEO_FADE_OUT_START=$(echo "$DURATION - 2" | bc)
AUDIO_FADE_OUT_START=$(echo "$DURATION - 3" | bc)

# =========================
# Detect if combined video has audio
# =========================
HAS_AUDIO=$(ffprobe -v error -select_streams a -show_entries stream=codec_type -of csv=p=0 combined.mp4)

if [[ -z "$HAS_AUDIO" ]]; then
    echo "No original audio detected, using music only..."
    FILTER="[0:v]fade=t=in:st=0:d=2,fade=t=out:st=$VIDEO_FADE_OUT_START:d=2[v]; [1:a]volume=1.0[a]"
    MAPS="-map [v] -map [a]"
else
    echo "Original audio detected, mixing with music..."
    FILTER="[0:v]fade=t=in:st=0:d=2,fade=t=out:st=$VIDEO_FADE_OUT_START:d=2[v]; \
[0:a]volume=1.0[a0]; [1:a]volume=0.3[a1]; [a0][a1]amix=inputs=2:duration=longest[a]"
    MAPS="-map [v] -map [a]"
fi

# =========================
# Add fades and audio mix
# =========================
echo "Adding music and fades..."
ffmpeg -threads $THREADS -y -i combined.mp4 -i "$MUSIC_FILE" \
-filter_complex "$FILTER" $MAPS -c:v libx264 -c:a aac -t $DURATION "$FINAL_OUTPUT" || { echo "❌ Failed to apply fades and audio"; exit 1; }

# =========================
# Cleanup
# =========================
rm -rf "$TMP_DIR" "$TMP_LIST" "$SORTED_DIR" combined.mp4
echo "✅ Done! Final video: $FINAL_OUTPUT"
