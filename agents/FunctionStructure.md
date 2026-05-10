# Function Structure

## SwiftUI
- Keep view bodies shallow; move logic into helpers.
- Use dedicated view types for complex sections.
- Favor `@State` for view‑local state and `@Environment` for shared app state.

## Services
- Service methods should be async and side‑effect conscious.
- Return typed results; avoid stringly‑typed control flow.
- Keep parsing logic in services, not views.

## AppModel
- Keep AppModel as the coordinator for app state.
- Avoid direct file system access in views; route through AppModel.
