#pragma once
#include <math.h>

inline double wrappedAzimuth(double degrees) {
  double value = fmod(degrees, 360.0);
  return value < 0.0 ? value + 360.0 : value;
}

// Keep the unwrapped motor position; only celestial coordinates wrap at north.
inline long nearestAzimuthSteps(long currentSteps, double targetDegrees, long stepsPerRev) {
  const double currentDegrees = currentSteps * 360.0 / stepsPerRev;
  double delta = wrappedAzimuth(targetDegrees - currentDegrees + 180.0) - 180.0;
  return currentSteps + lround(delta * stepsPerRev / 360.0);
}

inline long relativeAzimuthSteps(long currentSteps, double deltaDegrees, long stepsPerRev) {
  return currentSteps + lround(deltaDegrees * stepsPerRev / 360.0);
}
