# macOS Audio, Camera and Microphone Diagnostics

A read-only Bash toolkit for collecting audio device, microphone, camera, CoreAudio, conferencing-process, privacy-permission, and recent media-service evidence.

## Usage

```bash
chmod +x src/media_device_diagnostics.sh
./src/media_device_diagnostics.sh --hours 24
```

## Checks performed

- Audio input and output devices
- CoreAudio process and service state
- Camera and USB video device indicators
- Conferencing applications using media services
- TCC database metadata for camera and microphone permissions
- Recent CoreAudio, camera, microphone, and media-service events
- Text, CSV, and JSON reports

## Safety

The script does not record audio or video, reset CoreAudio, change privacy permissions, restart applications, or modify device settings.

## Author

Dewald Pretorius — L2 IT Support Engineer
