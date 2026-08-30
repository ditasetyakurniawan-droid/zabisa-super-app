# ADR-005: ARM64-only Android Compilation for Local Physical-device Development

Status: Accepted

## Context

The development laptop has limited memory relative to React Native New Architecture CMake builds. Compiling arm64-v8a, armeabi-v7a, x86 and x86_64 caused excessive resource usage, while the selected physical Android development device uses ARM64.

## Decision

`mobile-device.sh` passes `-PreactNativeArchitectures=arm64-v8a` only for local debug rebuilds.

## Consequences

- Local debug native builds are faster and use less memory.
- Release build configuration remains multi-ABI/App-Bundle capable.
- Emulator x86/x86_64 builds must explicitly override the architecture when needed.
