# macOS Audio, Camera and Microphone Diagnostics

A macOS support toolkit for diagnosing and repairing common audio, camera and microphone problems.

## Diagnostic script

```bash
chmod +x src/media_device_diagnostics.sh
./src/media_device_diagnostics.sh --hours 24
```

The diagnostic script collects audio and camera inventories, CoreAudio and media-service state, conferencing processes, privacy database metadata and recent media events.

## Repair script

Preview the repair:

```bash
chmod +x src/media_device_repair.sh
./src/media_device_repair.sh --repair --dry-run
```

Apply the repair:

```bash
./src/media_device_repair.sh --repair
```

Reset one app's camera permission:

```bash
./src/media_device_repair.sh \
  --reset-permission Camera \
  --bundle-id us.zoom.xos
```

Reset one app's microphone permission:

```bash
./src/media_device_repair.sh \
  --reset-permission Microphone \
  --bundle-id com.microsoft.teams2
```

## What the repair does

- Restarts the CoreAudio launch service.
- Restarts camera and conferencing helper processes when they are running.
- Can reset Camera or Microphone permission for a specific application bundle ID.
- Supports dry-run and confirmation controls.
- Writes a repair log and a post-repair verification report.
- Returns exit code `0` for success, `1` for completed-with-warnings and `2` for invalid arguments.

## Safety and limitations

The tool does not record audio or video. Permission resets are targeted to the specified bundle ID and cause the app to request permission again. Hardware faults, damaged cables, unsupported devices and third-party driver problems may still require manual intervention.

## Author

Dewald Pretorius — L2 IT Support Engineer
