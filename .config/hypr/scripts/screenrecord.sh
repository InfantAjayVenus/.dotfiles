#!/bin/bash

# Start and stop a screen recording, saved to ~/Videos by default.
# Alternative location via SCREENRECORD_DIR or XDG_VIDEOS_DIR envs.
# Resolution is capped to 4K for monitors above 4K, native otherwise.
# Override via --resolution= (e.g. --resolution=1920x1080, --resolution=0x0 for native).

[[ -f ~/.config/user-dirs.dirs ]] && source ~/.config/user-dirs.dirs
OUTPUT_DIR="${SCREENRECORD_DIR:-${XDG_VIDEOS_DIR:-$HOME/Videos}}"

if [[ ! -d $OUTPUT_DIR ]]; then
  notify-send "Screen recording directory does not exist: $OUTPUT_DIR" -u critical -t 3000
  exit 1
fi

DESKTOP_AUDIO="false"
MICROPHONE_AUDIO="false"
RESOLUTION=""
RECORDING_FILE="/tmp/screenrecord-filename"

for arg in "$@"; do
  case "$arg" in
  --with-desktop-audio) DESKTOP_AUDIO="true" ;;
  --with-microphone-audio) MICROPHONE_AUDIO="true" ;;
  --resolution=*) RESOLUTION="${arg#*=}" ;;
  esac
done

default_resolution() {
  local width height
  read -r width height < <(hyprctl monitors -j | jq -r '.[] | select(.focused == true) | "\(.width) \(.height)"')
  if ((width > 3840 || height > 2160)); then
    echo "3840x2160"
  else
    echo "0x0"
  fi
}

start_screenrecording() {
  local filename="$OUTPUT_DIR/screenrecording-$(date +'%Y-%m-%d_%H-%M-%S').mp4"
  local audio_devices=""
  local audio_args=()

  [[ $DESKTOP_AUDIO == "true" ]] && audio_devices+="default_output"

  if [[ $MICROPHONE_AUDIO == "true" ]]; then
    [[ -n $audio_devices ]] && audio_devices+="|"
    audio_devices+="default_input"
  fi

  [[ -n $audio_devices ]] && audio_args+=(-a "$audio_devices" -ac aac)

  local resolution="${RESOLUTION:-$(default_resolution)}"

  gpu-screen-recorder -w portal -k auto -s "$resolution" -f 60 -fm cfr -fallback-cpu-encoding yes -o "$filename" "${audio_args[@]}" &
  local pid=$!

  # Wait for recording to start (file appears after portal selection)
  while kill -0 $pid 2>/dev/null && [[ ! -f $filename ]]; do
    sleep 0.2
  done

  if kill -0 $pid 2>/dev/null; then
    echo "$filename" >"$RECORDING_FILE"
    notify-send "Screen recording started" "Press Alt+Print to stop" -t 3000
  fi
}

stop_screenrecording() {
  pkill -SIGINT -f "^gpu-screen-recorder"

  # Wait up to 5 seconds before force-killing
  local count=0
  while pgrep -f "^gpu-screen-recorder" >/dev/null && ((count < 50)); do
    sleep 0.1
    count=$((count + 1))
  done

  if pgrep -f "^gpu-screen-recorder" >/dev/null; then
    pkill -9 -f "^gpu-screen-recorder"
    notify-send "Screen recording error" "Process had to be force-killed. Video may be corrupted." -u critical -t 5000
  else
    trim_first_frame
    local filename=$(cat "$RECORDING_FILE" 2>/dev/null)
    local preview="${filename%.mp4}-preview.png"

    ffmpeg -y -i "$filename" -ss 00:00:00.1 -vframes 1 -q:v 2 "$preview" -loglevel quiet 2>/dev/null

    (
      ACTION=$(notify-send "Screen recording saved" "Click to open in mpv" \
        -t 10000 -i "${preview:-$filename}" -A "default=open")
      [[ $ACTION == "default" ]] && mpv "$filename"
      rm -f "$preview"
    ) &
  fi

  rm -f "$RECORDING_FILE"
}

trim_first_frame() {
  local latest
  latest=$(cat "$RECORDING_FILE" 2>/dev/null)

  if [[ -n $latest && -f $latest ]]; then
    local trimmed="${latest%.mp4}-trimmed.mp4"
    if ffmpeg -y -ss 0.1 -i "$latest" -c copy "$trimmed" -loglevel quiet 2>/dev/null; then
      mv "$trimmed" "$latest"
    else
      rm -f "$trimmed"
    fi
  fi
}

screenrecording_active() {
  pgrep -f "^gpu-screen-recorder" >/dev/null
}

if screenrecording_active; then
  stop_screenrecording
else
  start_screenrecording
fi
