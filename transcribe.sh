#!/bin/bash
set -euo pipefail

CHANNEL_URL="https://www.youtube.com/@0xGoodMorning-u7n/videos"
AUDIO_DIR="./audio"
TRANSCRIPT_DIR="./transcripts"
WHISPER_MODEL="medium"  # good balance of speed/accuracy for French

mkdir -p "$AUDIO_DIR" "$TRANSCRIPT_DIR"

echo "=== Fetching video list ==="
VIDEO_IDS=$(yt-dlp --flat-playlist --print "%(id)s" "$CHANNEL_URL" 2>/dev/null)
TOTAL=$(echo "$VIDEO_IDS" | wc -l | tr -d ' ')
echo "Found $TOTAL videos"

COUNT=0
for VIDEO_ID in $VIDEO_IDS; do
    COUNT=$((COUNT + 1))

    # Get video title for the filename
    TITLE=$(yt-dlp --print "%(title)s" "https://www.youtube.com/watch?v=$VIDEO_ID" 2>/dev/null)
    # Sanitize title for filename
    SAFE_TITLE=$(echo "$TITLE" | sed 's/[^a-zA-Z0-9àâäéèêëïîôùûüÿçÀÂÄÉÈÊËÏÎÔÙÛÜŸÇ_ -]//g' | sed 's/  */ /g' | head -c 100)

    AUDIO_FILE="$AUDIO_DIR/${VIDEO_ID}.mp3"
    TRANSCRIPT_FILE="$TRANSCRIPT_DIR/${VIDEO_ID}.txt"

    echo ""
    echo "=== [$COUNT/$TOTAL] $SAFE_TITLE ==="

    # Skip if transcript already exists
    if [ -f "$TRANSCRIPT_FILE" ]; then
        echo "  Transcript already exists, skipping."
        continue
    fi

    # Download audio
    if [ ! -f "$AUDIO_FILE" ]; then
        echo "  Downloading audio..."
        yt-dlp -x --audio-format mp3 --audio-quality 5 \
            -o "$AUDIO_FILE" \
            "https://www.youtube.com/watch?v=$VIDEO_ID" 2>/dev/null
    else
        echo "  Audio already downloaded."
    fi

    # Transcribe with whisper
    echo "  Transcribing with whisper ($WHISPER_MODEL model)..."
    python3 -c "
import whisper
import sys

model = whisper.load_model('$WHISPER_MODEL')
result = model.transcribe('$AUDIO_FILE', language='fr')

with open('$TRANSCRIPT_FILE', 'w') as f:
    f.write('# $SAFE_TITLE\n')
    f.write('# https://www.youtube.com/watch?v=$VIDEO_ID\n\n')
    f.write(result['text'])
print('  Done.')
"

    # Remove audio file to save space
    rm -f "$AUDIO_FILE"

    echo "  Transcript saved to $TRANSCRIPT_FILE"
done

echo ""
echo "=== All done! $TOTAL videos transcribed ==="
