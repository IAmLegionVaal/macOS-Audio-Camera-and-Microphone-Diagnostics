#!/bin/bash
set -u

DO_REPAIR=false
DRY_RUN=false
ASSUME_YES=false
OUTPUT_DIR=""
RESET_SERVICE=""
BUNDLE_ID=""
FAILURES=0
ACTIONS=0

usage() {
  cat <<'EOF'
Usage: media_device_repair.sh [options]

  --repair                     Restart CoreAudio and media helper services.
  --reset-permission SERVICE   Reset Camera or Microphone permission for one app.
  --bundle-id ID               Bundle ID used with --reset-permission.
  --dry-run                    Show actions without changing the Mac.
  --yes                        Skip confirmation prompts.
  --output DIR                 Save logs and verification output in DIR.
  -h, --help                   Show help.

Examples:
  ./src/media_device_repair.sh --repair
  ./src/media_device_repair.sh --repair --dry-run
  ./src/media_device_repair.sh --reset-permission Camera --bundle-id us.zoom.xos
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --repair) DO_REPAIR=true; shift ;;
    --reset-permission) RESET_SERVICE="${2:-}"; DO_REPAIR=true; shift 2 ;;
    --bundle-id) BUNDLE_ID="${2:-}"; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    --yes) ASSUME_YES=true; shift ;;
    --output) OUTPUT_DIR="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 2 ;;
  esac
done

[ "$(uname -s)" = "Darwin" ] || { echo "This tool must run on macOS." >&2; exit 1; }

if [ -n "$RESET_SERVICE" ]; then
  case "$RESET_SERVICE" in Camera|Microphone) : ;; *) echo "SERVICE must be Camera or Microphone." >&2; exit 2 ;; esac
  [ -n "$BUNDLE_ID" ] || { echo "--bundle-id is required with --reset-permission." >&2; exit 2; }
fi

STAMP="$(date +%Y%m%d_%H%M%S)"
OUTPUT_DIR="${OUTPUT_DIR:-./media-repair-$STAMP}"
mkdir -p "$OUTPUT_DIR"
LOG="$OUTPUT_DIR/repair.log"
VERIFY="$OUTPUT_DIR/verification.txt"
: > "$LOG"

log() { printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" | tee -a "$LOG"; }
confirm() {
  $ASSUME_YES && return 0
  printf '%s [y/N]: ' "$1"
  read -r answer
  case "$answer" in y|Y|yes|YES) return 0 ;; *) return 1 ;; esac
}
run_action() {
  description="$1"; shift
  ACTIONS=$((ACTIONS + 1)); log "$description"
  if $DRY_RUN; then
    printf 'DRY-RUN:' >> "$LOG"; for arg in "$@"; do printf ' %q' "$arg" >> "$LOG"; done; printf '\n' >> "$LOG"; return 0
  fi
  if "$@" >> "$LOG" 2>&1; then log "SUCCESS: $description"; return 0; fi
  FAILURES=$((FAILURES + 1)); log "WARNING: $description failed"; return 1
}
run_admin() {
  description="$1"; shift
  if [ "$(id -u)" -eq 0 ]; then run_action "$description" "$@"; else run_action "$description" /usr/bin/sudo "$@"; fi
}
verify() {
  {
    echo "Collected: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "Host: $(hostname)"
    echo
    echo "CoreAudio and media processes:"
    ps -Ao pid,user,etime,comm,args | grep -Ei 'coreaudiod|VDCAssistant|AppleCameraAssistant|avconferenced' | grep -v grep || true
    echo
    echo "Audio devices:"
    /usr/sbin/system_profiler SPAudioDataType 2>/dev/null | head -n 300
    echo
    echo "Camera devices:"
    /usr/sbin/system_profiler SPCameraDataType 2>/dev/null | head -n 200
  } > "$VERIFY" 2>&1
}

verify
if ! $DO_REPAIR; then log "Verification-only mode completed. Use --repair to apply repairs."; exit 0; fi
if ! confirm "Apply audio, camera and microphone repairs?"; then log "Repair cancelled by user."; exit 0; fi

run_admin "Restarting CoreAudio service" /bin/launchctl kickstart -k system/com.apple.audio.coreaudiod || \
  run_admin "Requesting CoreAudio process restart" /usr/bin/killall coreaudiod || true

for process_name in VDCAssistant AppleCameraAssistant avconferenced; do
  if pgrep -x "$process_name" >/dev/null 2>&1; then run_action "Restarting $process_name" /usr/bin/killall "$process_name" || true; fi
done

if [ -n "$RESET_SERVICE" ]; then
  if confirm "Reset $RESET_SERVICE permission for $BUNDLE_ID? The app must request access again."; then
    run_action "Resetting $RESET_SERVICE permission for $BUNDLE_ID" /usr/bin/tccutil reset "$RESET_SERVICE" "$BUNDLE_ID" || true
    if pgrep -x tccd >/dev/null 2>&1; then run_action "Refreshing the user privacy service" /usr/bin/killall tccd || true; fi
  fi
fi

if ! $DRY_RUN; then sleep 5; fi
verify

COREAUDIO_OK=false
pgrep -x coreaudiod >/dev/null 2>&1 && COREAUDIO_OK=true
if ! $COREAUDIO_OK; then FAILURES=$((FAILURES + 1)); log "WARNING: CoreAudio is not running after repair."; fi

if [ "$FAILURES" -gt 0 ]; then log "Repair completed with $FAILURES warning(s)."; exit 1; fi
log "Repair completed successfully. Actions performed: $ACTIONS"
exit 0
