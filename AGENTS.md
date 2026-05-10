# AGENTS

This repository supports agent‑assisted development. The files in `agents/` define conventions and workflows.

## Priorities
- Keep SwiftUI code modular and predictable.
- Prefer async/await over Combine.
- Avoid force unwraps and side‑effects in view bodies.
- Keep UI changes scoped to the requested task.

## Files
- `agents/FunctionStructure.md`
- `agents/Naming.md`
- `agents/Workflow.md`

## How Agents Should Work
- Read the relevant agent guidance file before making changes.
- Keep changes minimal and aligned to the active request.
- Surface risks and incomplete areas when work is done.
