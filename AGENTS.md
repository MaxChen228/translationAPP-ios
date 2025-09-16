# Repository Guidelines

These guidelines help contributors and automation agents work consistently in this SwiftUI iOS app.

## Project Structure & Module Organization
- App code: `translation/` (e.g., `translationApp.swift`, `ContentView.swift`, `Assets.xcassets`).
- Unit tests: `translationTests/` (Swift Testing framework).
- UI tests: `translationUITests/` (XCTest UI tests).
- Xcode project: `translation.xcodeproj` (single app target and scheme: `translation`).

## Build, Test, and Development Commands
- Open project: `open translation.xcodeproj` (or open in Xcode and press Cmd+R to run).
- Build (Debug): `xcodebuild -scheme translation -configuration Debug build`.
- Run unit + UI tests (simulator):
  - `xcodebuild test -scheme translation -destination 'platform=iOS Simulator,name=iPhone 15'`.
- Swift tools are managed by Xcode; prefer running from Xcode for day‑to‑day dev (Cmd+U to test).

## Coding Style & Naming Conventions
- Language: Swift (SwiftUI). Indentation: 4 spaces, trim trailing whitespace.
- Types and protocols: UpperCamelCase (`ContentView`). Methods, vars, files: lowerCamelCase / type‑named files.
- Keep views small and composable; extract subviews when >150 lines.
- Prefer `struct` for views and value types; mark view state with `@State`, `@Binding`, etc.
- Use explicit access control (`internal`/`private`) where meaningful.

## Testing Guidelines
- Unit tests: Swift Testing (`import Testing`), colocate helpers in `translationTests/`.
- UI tests: XCTest in `translationUITests/`.
- Name tests descriptively; one behavior per test. Aim for basic coverage of view logic and app launch.
- Run: Cmd+U in Xcode or the `xcodebuild test` command above.

## Commit & Pull Request Guidelines
- Current history is minimal; adopt Conventional Commits (e.g., `feat:`, `fix:`, `test:`) for clarity.
- PRs must include: concise summary, rationale, screenshots/video for UI changes, and linked issues.
- Keep PRs focused and small; include test updates.

## Security & Configuration Tips
- Do not commit secrets or API keys. Prefer `.xcconfig` or environment variables for local settings.
- Keep dependencies to Xcode defaults; discuss adding third‑party libraries in a PR first.

## Agent-Specific Instructions
- Respect this file’s scope for the whole repo. Match existing style and file layout.
- When editing Swift files, maintain the scheme name `translation` and do not rename targets without discussion.
