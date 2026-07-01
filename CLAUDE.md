# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project state

This is a freshly generated Xcode SwiftUI iOS app (default template) — a single `MemoriaSwiftUI` target with no test target, no third-party dependencies, and no custom architecture yet. `ContentView.swift` and `MemoriaSwiftUIApp.swift` are still the stock boilerplate.

- Bundle identifier: `Giorgi.MemoriaSwiftUI`
- iOS deployment target: 26.5
- Swift version: 5.0
- SDK: iphoneos (iOS app, universal iPhone/iPad)

## Commands

Build and run from Xcode (`MemoriaSwiftUI.xcodeproj`), or via CLI:

```bash
# Build for a simulator
xcodebuild -project MemoriaSwiftUI.xcodeproj -scheme MemoriaSwiftUI -destination 'platform=iOS Simulator,name=iPhone 16' build

# List available schemes/targets
xcodebuild -list -project MemoriaSwiftUI.xcodeproj
```

There is no test target yet — `xcodebuild test` will not work until one is added (e.g. via Xcode's "Add Test Target" or by creating a new `XCTest`/Swift Testing target in the project).

## Architecture

The project currently has no architecture beyond the default SwiftUI app lifecycle:

- `MemoriaSwiftUIApp.swift` — `@main` entry point, declares the single `WindowGroup` scene wrapping `ContentView`.
- `ContentView.swift` — the sole view, currently placeholder "Hello, world!" content.

As the app grows, prefer keeping this file updated with the real architecture (e.g. navigation structure, data/persistence layer, dependency injection approach) once those decisions are made — there is nothing beyond the template to document yet.
