#!/bin/bash
set -u

HOURS=24
OUTPUT_DIR=""

usage() {
  echo "Usage: media_device_diagnostics.sh [--hours N] [--output DIR]"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --hours) HOURS="${2:-24}"; shift 2 ;;
    --output) OUTPUT_DIR="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 2 ;;
  esac
done

case "$HOURS" in ''|*[!0-9]*) echo "--hours must be numeric" >&2; exit 2 ;; esac
[ "$(uname -s)" = "Darwin" ] || { echo "This tool must run on macOS." >&2; exit 1; }

STAMP="$(date +%Y%m%d_%H%M%S)"
OUTPUT_DIR="${OUTPUT_DIR:-./media-diagnostics-$STAMP}"
mkdir -p "$OUTPUT_DIR"
REPORT="$OUTPUT_DIR/media-report.txt"
CSV="$OUTPUT_DIR/devices.csv"
JSON="$OUTPUT_DIR/summary.json"
ERRORS="$OUTPUT_DIR/command-errors.log"
: > "$REPORT"
: > "$ERRORS"
echo 'category,name,manufacturer,transport' > "$CSV"

section() {
  title="$1"
  shift
  { printf '\n===== %s =====\n' "$title"; "$@"; } >> "$REPORT" 2>> "$ERRORS" || true
}

section "Collection metadata" /bin/bash -c 'date -u +%Y-%m-%dT%H:%M:%SZ; hostname; sw_vers; id'
section "Audio device inventory" /usr/sbin/system_profiler SPAudioDataType
section "Camera inventory" /usr/sbin/system_profiler SPCameraDataType
section "USB inventory" /usr/sbin/system_profiler SPUSBDataType
section "CoreAudio and media processes" /bin/bash -c 'ps -Ao pid,user,etime,comm,args | grep -Ei "coreaudiod|VDCAssistant|AppleCameraAssistant|avconferenced|Teams|zoom|Webex|FaceTime" | grep -v grep || true'
section "CoreAudio launchd state" /bin/launchctl print system/com.apple.audio.coreaudiod
section "Privacy database metadata" /bin/bash -c 'for db in "$HOME/Library/Application Support/com.apple.TCC/TCC.db" /Library/Application\ Support/com.apple.TCC/TCC.db; do [[ -e "$db" ]] && ls -lh "$db"; done'
section "Recent media events" /bin/bash -c "/usr/bin/log show --last ${HOURS}h --style compact --predicate '(process == \"coreaudiod\") OR (process == \"VDCAssistant\") OR (process == \"AppleCameraAssistant\") OR (process == \"avconferenced\") OR (eventMessage CONTAINS[c] \"microphone\") OR (eventMessage CONTAINS[c] \"camera\")' 2>/dev/null | tail -n 4000"

/usr/sbin/system_profiler SPAudioDataType 2>/dev/null | awk -F: '/^[[:space:]]{8}[^ ].*:$/ {gsub(/^[[:space:]]+|:$/,"",$1); print "audio\t"$1}' | while IFS=$'\t' read -r category name; do
  printf '"%s","%s","%s","%s"\n' "$category" "$name" "unknown" "unknown" >> "$CSV"
done
/usr/sbin/system_profiler SPCameraDataType 2>/dev/null | awk -F: '/^[[:space:]]{8}[^ ].*:$/ {gsub(/^[[:space:]]+|:$/,"",$1); print "camera\t"$1}' | while IFS=$'\t' read -r category name; do
  printf '"%s","%s","%s","%s"\n' "$category" "$name" "unknown" "unknown" >> "$CSV"
done

COREAUDIO_RUNNING=false
pgrep -x coreaudiod >/dev/null 2>&1 && COREAUDIO_RUNNING=true
CAMERA_PROCESS_RUNNING=false
pgrep -x VDCAssistant >/dev/null 2>&1 && CAMERA_PROCESS_RUNNING=true
AUDIO_DEVICE_COUNT="$(grep -c '^"audio"' "$CSV" || true)"
CAMERA_DEVICE_COUNT="$(grep -c '^"camera"' "$CSV" || true)"
OVERALL="Healthy"
if ! $COREAUDIO_RUNNING || [ "$AUDIO_DEVICE_COUNT" -eq 0 ]; then OVERALL="Attention required"; fi

cat > "$JSON" <<EOF
{
  "collected_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "hostname": "$(hostname)",
  "coreaudio_running": $COREAUDIO_RUNNING,
  "camera_service_running": $CAMERA_PROCESS_RUNNING,
  "audio_devices": $AUDIO_DEVICE_COUNT,
  "camera_devices": $CAMERA_DEVICE_COUNT,
  "overall_status": "$OVERALL"
}
EOF

printf '\nMedia diagnostics completed: %s\n' "$OUTPUT_DIR" | tee -a "$REPORT"
