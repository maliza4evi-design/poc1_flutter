# PoC-1A: Direct Encrypted Messaging via Google Nearby Connections

## Project Overview

This is a Proof of Concept (PoC-1A) for direct device-to-device messaging on Android using Google Nearby Connections API. The app demonstrates:

- Peer discovery and connection without internet
- Message exchange over local wireless (Wi-Fi Direct, BLE, WebRTC)
- Connection state management
- Basic logging and diagnostics

**Important**: This is PoC-1A (Transport Layer only). It uses the encryption provided by Nearby Connections but does **not** implement application-level E2EE with identity verification (that is PoC-1B).

## Prerequisites

- Android device with Google Play Services
- Android 10+ (API 29+), recommended Android 12+ (API 31+)
- Google Play Services installed and updated
- Two devices for testing
- Internet disabled (Airplane mode + Wi-Fi/BLE manually enabled)

## Building

### Option 1: GitHub Actions (Recommended - No Local Setup)

1. Fork this repository
2. Enable GitHub Actions in the fork
3. Push to main branch or trigger workflow manually
4. Download APK from Actions artifacts

### Option 2: Local Build

```bash
# Install Flutter 3.19+
# Install Java 17 (Eclipse Temurin)
# Install Android SDK (cmdline-tools, platform-34, build-tools-34.0.0)

cd poc1_flutter
flutter pub get
flutter build apk --debug --split-per-abi
# or
flutter build apk --release --split-per-abi
```

## Installation

1. Transfer APK to device (ADB, file transfer, etc.)
2. Install: `adb install app-arm64-v8a-debug.apk` (or appropriate ABI)
3. Grant all requested permissions on first launch

## Testing Procedure

### Pre-test Setup (Both Devices)

1. Enable **Airplane Mode**
2. Manually enable **Wi-Fi** and **Bluetooth** in quick settings
3. Disable mobile data completely
4. Verify no internet access (browser should fail)

### Test Steps

1. **Launch App** on both devices
2. **Enter Name** on each device (different names)
3. **Tap Initialize** - wait for "Status: Discovering..." / "Advertising"
4. **Wait for Discovery** - nearby device should appear in list (up to 30s)
5. **Tap Connect** on one device
6. **Verify Connection** - status should show "Connected"
7. **Send Messages** - type and send test messages
8. **Verify Delivery** - messages appear on both devices with timestamps
9. **Test Reconnection** - disable Wi-Fi on one device, re-enable, verify auto-reconnect

### Success Criteria

| Metric | Target |
|--------|--------|
| Discovery Time | ≤ 30 seconds |
| Connection Time | ≤ 15 seconds |
| Message Delivery | 100/100 messages |
| Reconnection | 9/10 attempts |
| No Crashes | 0 ANR/Crash |

## Known Limitations

1. **Google Play Services Required** - Won't work on devices without GMS
2. **No E2EE Identity Verification** - Transport encrypted but no MITM protection (PoC-1B)
3. **Background Discovery Limited** - Foreground service needed for background
4. **Device Compatibility** - Some OEMs restrict Wi-Fi Direct in airplane mode
5. **No Internet Fallback** - Pure offline only

## Security Notes

- Uses Nearby Connections built-in encryption (AES-256-GCM)
- **Does NOT verify peer identity** - Vulnerable to MITM
- Payloads encrypted in transit only
- No persistent key storage

## Architecture

```
lib/
├── main.dart                 # App entry point
├── models/
│   └── connection_models.dart # Data models (Peer, Message, Logs)
├── services/
│   └── nearby_service.dart   # Nearby Connections wrapper
├── ui/
│   └── main_screen.dart      # Main UI screen
└── utils/
    └── logger.dart           # Logging utility
```

## Test Evidence Required

For each test run, document:
- Device models and Android versions
- Airplane mode verification
- Discovery/connection timestamps
- Message send/receive logs
- Any errors or crashes
- Reconnection test results

## Next Steps (PoC-1B)

- Application-level E2EE with X25519 + Ed25519
- Out-of-band key verification (QR code / safety number)
- Forward secrecy with ephemeral keys
- MITM resistance testing

## License

MIT License - See LICENSE file