# AGENTS.md

## Project
AstroPilot — Flutter GoTo telescope tracker. Mobile app (Flutter/Dart) connects via BLE to an ESP32 that drives an equatorial/altazimuth mount.

## Critical Architecture Facts
- **No database.** Deep-sky objects and calibration stars load from `assets/data/celestial_catalog.json` (epoch J2000). Sun/Moon/planets computed in real-time via VSOP87 in `geoengine`.
- **Precession correction is mandatory.** Catalog coords are J2000 — must apply precession + nutation to convert to JNow (Equator-of-Date) before any other calculation. Skipping this causes >21 arcmin pointing error.
- **Coordinate pipeline:** J2000 catalog → precession → JNow → horizontal (Alt/Az) using user lat/lon + UTC time → atmospheric refraction correction (Meeus formula).

## Developer Workflow
- **Spec-Driven Development (SDD) is mandatory.** Never write Dart/Flutter implementation code without first producing a `spec_[modulo].md` containing: User Story, Business Rules, Happy Paths, Sad Paths (BLE timeout, GPS off, etc.), Clarification Questions. Wait for user confirmation before coding.
- Act as Technical Product Manager when receiving requirements.

## BLE Command Protocol
Commands sent to ESP32: `GOTO:alt,az`, `TRACK:alt,az`, `SYNC`, `STATUS`, `STOP`.

## Safety
- **Solar coordinates are never displayed or computed for the user.** No button, no coordinate retrieval, no exception. This is a hard safety block to prevent ocular damage.

## Tech Stack
- Flutter / Dart
- `geoengine` (local plugin, Astronomy Engine / Don Cross — IAU 2006/VSOP87)
- `flutter_blue_plus` (BLE — migrating from Bluetooth Classic)
- `geolocator` (Chile-focused geolocation)
