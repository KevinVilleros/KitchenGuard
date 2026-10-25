# ADR 0005 — Archive the YOLO backend under `yolo/`

## Status
Accepted

## Context

After adopting the Flutter app as the main technology (ADR 0001), the Python
backend occupied the repository root (`cocinap/`, `tests/`, `installer/`,
`scripts/`, `main.py`, builds, `models/`, docs), mixing with the active product
and making navigation harder.

## Decision

Reorganize the Python/YOLO backend under the **`yolo/`** folder, preserving git
history (using `git mv` so git detects it as a rename), and rewrite the root
`README.md` with a Flutter-first focus.

## Consequences

**Positive**
- Clean root centered on the mobile app.
- Clear separation between active product and archived backend.
- Python CI points to `working-directory: yolo`.

**Negative**
- Paths in scripts and documentation must be updated.

**Neutral**
- The backend remains functional and optional.
