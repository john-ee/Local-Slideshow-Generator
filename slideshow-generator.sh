#!/bin/bash
THREADS=2
MUSIC_VOL=0.3
FADE_DUR=2
TMP_DIR="./tmp_segments"
SORTED_DIR="./sorted_media"
TMP_LIST="concat.txt"

IMG_DIR="./media"
FINAL_OUTPUT="final_slideshow.mp4"
MUSIC_FILE="music.mp3"
RESOLUTION="1280:720"
YOUTUBE_URL=""
DURATION_PER_IMAGE=3

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

for cmd in ffmpeg ffprobe exiftool bc; do
 command -v $cmd >/dev/null 2>&1 || { echo "❌ $cmd is not installed"; exit 1; }
done
if [[ -n "$YOUTUBE_URL" ]]; then
 command -v yt-dlp >/dev/null 2>&1 || { echo "❌ yt-dlp is required"; exit 1; }
fi

if [[ -n "$YOUTUBE_URL" ]]; then
 yt-dlp -x --audio-format mp3 -o "$MUSIC_FILE" "$YOUTUBE_URL" || exit 1
fi

mkdir -p "$SORTED_DIR" "$TMP_DIR"
> "$TMP_LIST"

exiftool '-FileName<DateTimeOriginal' -d "%Y%m%d_%H%M%S%%-c.%%e" -o "$SORTED_DIR" "$IMG_DIR" || cp "$IMG_DIR"/* "$SORTED_DIR"

echo "Processing media..."
for file in $(find "$SORTED_DIR" -type f \( -iname "*.jpg" -o -iname "*.mp4" \) | sort); do
  base_name=$(basename "$file" | sed 's/\.[^.]*$//')
  seg="$TMP_DIR/${base_name}.mp4"

  if [[ "$file" == *.jpg ]]; then
    # Image → MP4 with silent audio
    ffmpeg -threads $THREADS -y \
      -f lavfi -i anullsrc=channel_layout=stereo:sample_rate=44100 \
      -loop 1 -t $DURATION_PER_IMAGE -i "$file" \
      -vf "scale=$RESOLUTION:force_original_aspect_ratio=decrease,pad=$RESOLUTION:(ow-iw)/2:(oh-ih)/2:black" \
      -r 30 -c:v libx264 -pix_fmt yuv420p -c:a aac -shortest "$seg" || exit 1
  else
    # MP4 → normalized with audio preserved
    ffmpeg -threads $THREADS -y -i "$file" \
      -vf "scale=$RESOLUTION:force_original_aspect_ratio=decrease,pad=$RESOLUTION:(ow-iw)/2:(oh-ih)/2:black" \
      -r 30 -c:v libx264 -pix_fmt yuv420p -c:a aac -ar 44100 "$seg" || exit 1
  fi

  echo "file '$seg'" >> "$TMP_LIST"
done

if [[ ! -s "$TMP_LIST" ]]; then
 echo "❌ No media files found"
 exit 1
fi

echo "Creating combined video..."
INPUTS=$(awk -F"'" '{print "-i " $2}' "$TMP_LIST")
SEG_COUNT=$(wc -l < "$TMP_LIST")

ffmpeg -threads $THREADS -y $INPUTS \
-filter_complex "concat=n=$SEG_COUNT:v=1:a=1" \
-c:v libx264 -pix_fmt yuv420p -r 30 -c:a aac combined.mp4 || exit 1

DURATION=$(ffprobe -v error -show_entries format=duration -of csv=p=0 combined.mp4)
VIDEO_FADE_OUT_START=$(echo "$DURATION - $FADE_DUR" | bc)

echo "Adding music and fades..."
FILTER="[0:v]fade=t=in:st=0:d=$FADE_DUR,fade=t=out:st=$VIDEO_FADE_OUT_START:d=$FADE_DUR[v]; \
[0:a]volume=1.0[a0]; \
[1:a]volume=$MUSIC_VOL,afade=t=out:st=$VIDEO_FADE_OUT_START:d=$FADE_DUR[a1]; \
[a0][a1]amix=inputs=2:duration=longest[a]"
MAPS="-map [v] -map [a]"

ffmpeg -threads $THREADS -y -i combined.mp4 -i "$MUSIC_FILE" \
-filter_complex "$FILTER" $MAPS -c:v libx264 -c:a aac -t $DURATION "$FINAL_OUTPUT" || exit 1

rm -rf "$TMP_DIR" "$TMP_LIST" combined.mp4 "$SORTED_DIR"
if [[ -n "$YOUTUBE_URL" ]]; then rm -f "$MUSIC_FILE"; fi

echo "✅ Done! Final video: $FINAL_OUTPUT"
