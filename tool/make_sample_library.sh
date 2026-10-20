#!/usr/bin/env bash
# Generates a small fake anime library of synthetic test clips (ffmpeg test
# patterns, no real content) for trying the scanner, metadata matching,
# subtitles, resume and danmaku.
#
#   tool/make_sample_library.sh [output-dir]
#
# Default output: "/Volumes/Seagate_ddx/07 Anime/_Yume sample" (keeps the Mac's
# drive free); falls back to ./sample_library when that disk isn't mounted.
set -euo pipefail

DEFAULT="/Volumes/Seagate_ddx/07 Anime/_Yume sample"
if [[ $# -ge 1 ]]; then OUT="$1"
elif [[ -d "/Volumes/Seagate_ddx" ]]; then OUT="$DEFAULT"
else OUT="$(pwd)/sample_library"; fi

command -v ffmpeg >/dev/null || { echo "ffmpeg is required (brew install ffmpeg)"; exit 1; }
mkdir -p "$OUT"
echo "Writing sample library to: $OUT"

DUR=${DUR:-150}   # seconds per clip

clip() { # path label hue
  local path="$1" label="$2" hue="$3"
  [[ -f "$path" ]] && return
  mkdir -p "$(dirname "$path")"
  ffmpeg -loglevel error -y \
    -f lavfi -i "testsrc2=size=1280x720:rate=24,hue=h=${hue}" \
    -f lavfi -i "sine=frequency=440:sample_rate=48000" \
    -t "$DUR" \
    -vf "drawtext=text='${label}':fontcolor=white:fontsize=48:box=1:boxcolor=black@0.5:x=(w-text_w)/2:y=h-120,drawtext=text='%{pts\\:hms}':fontcolor=white:fontsize=36:x=40:y=40" \
    -c:v libx264 -preset veryfast -crf 30 -c:a aac -b:a 64k "$path"
  echo "  $path"
}

ass() { # path episode
  cat > "$1" <<EOF
[Script Info]
ScriptType: v4.00+
PlayResX: 1280
PlayResY: 720

[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
Style: Default,Arial,48,&H00FFFFFF,&H000000FF,&H00000000,&H64000000,0,0,0,0,100,100,0,0,1,3,1,2,40,40,40,1

[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
Dialogue: 0,0:00:01.00,0:00:06.00,Default,,0,0,0,,Sample subtitle — episode $2
Dialogue: 0,0:00:06.50,0:00:12.00,Default,,0,0,0,,{\\i1}ASS styling works{\\i0} (external .ass)
Dialogue: 0,0:00:30.00,0:00:40.00,Default,,0,0,0,,Thirty seconds in.
EOF
}

danmaku_xml() { # path episode
  {
    echo '<?xml version="1.0" encoding="UTF-8"?><i>'
    local colors=(16777215 16777215 16777215 16711680 65280 16776960 3394815)
    for i in $(seq 0 399); do
      local t=$(( (i * 37) % (DUR * 10) ))
      local mode=1; (( i % 17 == 0 )) && mode=5; (( i % 23 == 0 )) && mode=4
      local c=${colors[$(( i % ${#colors[@]} ))]}
      printf '<d p="%d.%d,%d,25,%d,0,0,0,%d">弹幕测试 #%d ep%s ～ danmaku test</d>\n' \
        $(( t / 10 )) $(( t % 10 )) $mode $c $i $i "$2"
    done
    echo '</i>'
  } > "$1"
}

# Show 1: release-group style names, flat in a show folder, with sidecar subs + danmaku.
S1="$OUT/Sousou no Frieren"
for ep in 01 02 03; do
  f="$S1/[Sample] Sousou no Frieren - $ep (720p).mp4"
  clip "$f" "Frieren EP$ep (sample)" 0
  ass "${f%.mp4}.ass" "$ep"
  danmaku_xml "${f%.mp4}.xml" "$ep"
done

# Show 2: scene-style names.
for ep in 01 02; do
  clip "$OUT/Bocchi the Rock/Bocchi.the.Rock.S01E${ep}.720p.mp4" "Bocchi S01E$ep (sample)" 120
done

# Show 3: generic episode names inside a folder named after the show.
for ep in 01 02; do
  clip "$OUT/Kusuriya no Hitorigoto/Episode $ep.mp4" "Kusuriya EP$ep (sample)" 240
done

echo "Done. Add \"$OUT\" (or its parent) as a library folder in Yume → Settings."
