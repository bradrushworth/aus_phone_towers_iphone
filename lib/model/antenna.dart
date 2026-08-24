class Antenna {
  // Zero, not `late`, and deliberately so. GetAntenna publishes the Antenna into antennaCache
  // before its HTTP fetch resolves, and the fetch is not awaited, so every one of these fields
  // can legitimately be read before it is assigned — and on the paths where the licence has no
  // antenna record, never assigned at all. `late` turned that ordinary case into a
  // LateInitializationError thrown from getPowerAtBearing(), which abandoned the whole device's
  // polygon. Java's Antenna uses bare primitives, so it reads the same zeros instead of throwing;
  // matching that keeps the two apps identical. A zero beamwidth also fails the
  // `beamwidth > 0 && beamwidth < 360` test in getPowerAtBearing(), so an unpopulated antenna
  // simply contributes no directional gain rather than a wrong one.
  double gain = 0;
  double frontToBack = 0;
  double horizontalBeamwidth = 0;
}
