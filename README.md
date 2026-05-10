# Source by Sfxx

A cross‑platform Git management app for iOS, iPadOS, and macOS. Source focuses on fast status insight, real‑time repository updates, and a clean Git workflow for day‑to‑day operations.

## What It Does
- Manage repositories with secure bookmarks
- Live activity feed and status updates
- Branch management (create, delete, checkout)
- Staging and unstaging with file‑level diffs
- Commit creation with amend and signing
- Auto‑fetch with configurable intervals

## Platform Notes
- Git execution currently uses the system git binary on macOS.
- Background fetch is available on macOS using system‑scheduled activity.
- iOS and iPadOS currently run Git commands only when the app is active.

## Development
- SwiftUI + Observation
- Async/await for all Git operations
- File watching on macOS to drive real‑time updates

## Roadmap
- Rich diff UI with syntax highlighting
- Background fetch on iOS (if permitted by policy)
- Repository insights and analytics

## Contributing
PRs are welcome but require approval. See LICENSE and AGENTS.md for contributor guidelines.
