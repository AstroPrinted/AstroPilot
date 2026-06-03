---
name: astropilot-phase2-mvp
description: Use when porting AstroPilot Phase 2/Fase 2 MVP to another repo: visible celestial objects, astronomical GoTo, saved pointing correction, and BLE GOTO integration while preserving manual OE4 behavior.
---

# AstroPilot Phase 2 MVP

Use this skill to implement or port the AstroPilot Phase 2 MVP flow:

```txt
Catalog / visible objects
-> select celestial object
-> show detail
-> compute current Alt/Az
-> load saved pointing correction
-> apply correction only for astronomical GoTo
-> send existing GOTO over BLE
```

## Non-Negotiables

- Do not modify firmware.
- Do not add new ESP32 commands.
- Do not modify manual OE4 behavior.
- Do not apply pointing correction inside `Oe4ControlController.sendGoto`.
- Do not apply pointing correction inside `MotorCommandService`.
- Do not apply correction to HOME, STOP, manual GOTO, tests, nudges, or raw motor controls.
- Keep astronomical GoTo as a separate flow that starts from selecting a celestial object.
- Do not touch unrelated validation/evidence folders unless explicitly requested.

## Codebase Audit

Before coding, verify whether the target repo already has these pieces:

- Catalog data, usually `assets/celestial_catalog.json`.
- Celestial object models: stars, deep sky objects, solar system bodies.
- Catalog repository/service.
- Ephemeris engine/service capable of computing Alt/Az.
- Observer/location/time provider.
- Saved calibration/correction storage, usually `SharedPreferences`.
- `PointingCorrectionService.applyCorrection` or equivalent.
- BLE service/controller that already sends an existing `GOTO` command.
- Existing manual motor/OE4 screen that must remain raw and uncorrected.

## Recommended Files

Create or adapt these files:

- `lib/features/catalog/domain/models/visible_celestial_object.dart`
- `lib/features/catalog/application/visible_objects_service.dart`
- `lib/features/catalog/application/astronomical_goto_service.dart`

Modify these only when relevant:

- Catalog screen/list UI.
- Celestial detail screen.
- Calibration screen CTA after saved correction.
- Catalog list tile/badge widgets.

Avoid modifying low-level BLE command services unless the repo lacks any reusable GOTO sender.

## Visible Objects Service

Implement a service that:

- Loads catalog objects by category and optional query.
- Reads observer latitude, longitude, height, and UTC from the existing observer/settings service.
- Computes Alt/Az for each object using the existing ephemeris/astronomy engine.
- Treats an object as visible when `altitudeDeg >= 0.0`.
- Marks objects from `0.0` to `< 5.0` degrees as near horizon.
- Sorts visible objects by altitude descending.
- Keeps solar safety behavior from the existing codebase.

Do not reuse calibration's stricter star threshold for the catalog. Calibration may use 15 degrees; catalog visibility uses the horizon.

## Astronomical GoTo Service

Implement a service that:

- Recomputes Alt/Az at the exact time of pressing the GoTo/Apuntar button.
- Blocks solar GoTo if the app already blocks solar coordinates.
- Blocks objects below the horizon.
- Loads saved calibration/correction from the existing repository/storage.
- Applies `PointingCorrectionService.applyCorrection` only when saved correction exists.
- Normalizes final azimuth to `0..360`.
- Clamps final altitude to the firmware-supported range already used by the app.
- Sends using the existing BLE GOTO pathway.

Add debug logs with a clear prefix, for example:

```txt
[AstronomicalGoTo] Object: M42
[AstronomicalGoTo] Raw Alt/Az: ...
[AstronomicalGoTo] Calibration found: true/false
[AstronomicalGoTo] Offset Alt/Az: ...
[AstronomicalGoTo] Corrected Alt/Az: ...
[AstronomicalGoTo] Sending GOTO...
```

## UI Requirements

In the catalog:

- Add a `Visible objects` mode or tab.
- Show current observer location/time used for visibility.
- Provide a refresh/recalculate action.
- Show altitude, azimuth, and near-horizon warning.

In the detail screen:

- Show current Alt/Az.
- Show whether saved correction is available.
- If available, show altitude and azimuth offsets.
- Show final command values.
- Disable send while BLE is disconnected, object is blocked, or send is already in progress.
- After send, show whether the command was sent with or without correction.

In calibration:

- After saving correction, add a CTA such as `View visible objects`.
- The CTA should open the catalog directly in visible-objects mode if possible.

## Tests

Add small service tests when practical:

- Visible filtering keeps `altitude >= 0` and excludes below-horizon objects in visible-only mode.
- Near horizon is marked for `0 <= altitude < 5`.
- Astronomical GoTo sends raw Alt/Az when no correction exists.
- Astronomical GoTo applies saved correction and normalizes azimuth.
- Below-horizon objects are blocked.
- Solar GoTo is blocked.

Run:

```txt
flutter analyze
flutter test
```

## Commit Strategy

Use small commits:

1. Add visible objects model/service/tests.
2. Add catalog visible mode UI.
3. Add astronomical GoTo service/tests.
4. Wire detail screen GoTo and calibration CTA.

Keep each commit focused and avoid unrelated file churn.
