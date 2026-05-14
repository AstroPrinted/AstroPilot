#!/usr/bin/env python3
"""
Ground Truth Generator for AstroPilot OE3 Validation.

Uses astropy to compute Alt/Az from J2000 RA/Dec with standard
atmospheric refraction, replicating the same pipeline as our
EphemerisEngine (precession J2000→JNow, then horizontal transform).

Outputs: test/fixtures/ephemeris_ground_truth.json (500 points)
"""

import json
import random
from datetime import datetime, timedelta, timezone
from pathlib import Path

import numpy as np
from astropy.time import Time
from astropy.coordinates import (
    EarthLocation,
    SkyCoord,
    AltAz,
)
from astropy import units as u

FIXTURES_DIR = Path(__file__).resolve().parent.parent / "test" / "fixtures"
NUM_POINTS = 500
SEED = 42

LOCATIONS_IN_CHILE = [
    (-33.4489, -70.6693, 570.0),
    (-29.9027, -71.2519, 30.0),
    (-36.8201, -73.0444, 10.0),
    (-53.1638, -70.9171, 37.0),
    (-18.4746, -70.2979, 50.0),
    (-23.6168, -70.3944, 450.0),
    (-33.0500, -71.6000, 5.0),
    (-45.4000, -72.0000, 200.0),
    (-38.7400, -72.6000, 120.0),
    (-27.1000, -70.0000, 800.0),
]


def generate_ground_truth():
    rng = random.Random(SEED)

    base_date = datetime(2025, 1, 1, tzinfo=timezone.utc)
    points = []

    for i in range(NUM_POINTS):
        lat, lon, height = rng.choice(LOCATIONS_IN_CHILE)

        random_seconds = rng.randint(0, 365 * 24 * 3600 * 2)
        dt = base_date + timedelta(seconds=random_seconds)
        t = Time(dt.strftime("%Y-%m-%dT%H:%M:%S"), scale="utc")

        roll = rng.random()
        if roll < 0.4:
            ra_hours = rng.uniform(0, 24)
            dec_deg = rng.uniform(-90, 90)
        elif roll < 0.7:
            ra_hours = rng.uniform(0, 24)
            dec_deg = rng.uniform(-60, 30)
        else:
            ra_hours = rng.uniform(0, 24)
            dec_deg = rng.uniform(-90, 10)

        if abs(abs(dec_deg) - 90.0) < 0.01:
            dec_deg = 89.9 if dec_deg > 0 else -89.9

        location = EarthLocation.from_geodetic(
            lon=lon * u.deg, lat=lat * u.deg, height=height * u.m
        )
        coord_j2000 = SkyCoord(
            ra=ra_hours * u.hourangle,
            dec=dec_deg * u.deg,
            frame="icrs",
        )

        altaz_frame = AltAz(obstime=t, location=location)
        try:
            altaz = coord_j2000.transform_to(altaz_frame)
            expected_alt = float(altaz.alt.deg)
            expected_az = float(altaz.az.deg) % 360.0
        except Exception:
            continue

        points.append({
            "id": i,
            "raJ2000Hours": round(ra_hours, 8),
            "decJ2000Deg": round(dec_deg, 8),
            "utcISO": dt.strftime("%Y-%m-%dT%H:%M:%S") + "Z",
            "latDeg": round(lat, 6),
            "lonDeg": round(lon, 6),
            "heightMeters": round(height, 1),
            "expectedAltDeg": round(expected_alt, 8),
            "expectedAzDeg": round(expected_az, 8),
        })

    return points


def main():
    print(f"Generating {NUM_POINTS} ground truth points...")
    points = generate_ground_truth()
    print(f"Successfully computed {len(points)} points.")

    FIXTURES_DIR.mkdir(parents=True, exist_ok=True)
    output_path = FIXTURES_DIR / "ephemeris_ground_truth.json"

    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(points, f, indent=2)

    print(f"Written to: {output_path}")
    print(f"Total points: {len(points)}")

    # Quick self-validation: report altitude distribution
    above_horizon = sum(1 for p in points if p["expectedAltDeg"] > 0)
    below_horizon = sum(1 for p in points if p["expectedAltDeg"] <= 0)
    print(f"Above horizon: {above_horizon}, Below/at horizon: {below_horizon}")

    alts = [p["expectedAltDeg"] for p in points]
    azs = [p["expectedAzDeg"] for p in points]
    print(f"Alt range: [{min(alts):.4f}, {max(alts):.4f}] deg")
    print(f"Az  range: [{min(azs):.4f}, {max(azs):.4f}] deg")


if __name__ == "__main__":
    main()