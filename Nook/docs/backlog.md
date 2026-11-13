# Nook backlog — November 10, 2026

Completed in 0.9.0: remembered toolbar collapse, right-click/More options shape changes, shared palette/custom color picker with recents and contrast feedback, searchable colored icons replacing the Idea creation tool, optional alignment guides/snapping, position locks. Existing Idea cards remain editable.

Completed in 0.10.0: free drawing with custom ink, brush size, smooth paths, one-stroke undo/redo, shared live previews, normal stroke grouping/manipulation, and drawing-specific resource limits.

Completed in 0.10.1: hold-to-straighten with adjustable endpoint, optional shape cleanup with sketch-restoring Undo, automatic enclosed-stroke grouping through Draw's Group strokes option, and the shared 60-color standard palette alongside custom colors.

Implemented in 0.11.0: Google sign-in, Google-only account screens without SMTP, initial production traffic and aggregate-board size limits, and Render/Neon release preparation. A separate free cloud database has been provisioned; no local boards were uploaded.

Still pending: a later visual polish pass, real Google credential setup, source repository hookup, capacity/staging checks, and publication. Nook is not publicly live yet.

## Navigation review after 0.9.3

- Automatically leave Hand when choosing a creation tool (confirmed editing conflict).
- Preview/highlight overlap-list targets so similar labels can be distinguished.
- Avoid neighboring canvas content when positioning item controls; consider reducing controls while typing/dragging.

These are review recommendations for a later pass, not implemented changes.

## Owner decision and completion — 0.9.4, November 11

The Hand/creation conflict and overlap-target highlighting are fixed. The owner excluded the neighbor-avoidance recommendation: selection controls must remain centered above their item/group and clearly visible. Do not add neighbor-avoidance movement to the bar without a new request.

## Dragging revision — 0.9.5

The owner now prefers full-body dragging for icons and text boxes, including empty interiors. This supersedes icon/plain-text click-through behavior. Hover shape/icon choices and double-click empty-canvas text creation are implemented. Centered item controls and Select underneath remain.

## Reveal revision — 0.9.6

The owner replaced the overlap list/hover-preview model with direct canvas outlines and temporary local hiding of covers. It remains hidden while editing/moving until explicit restoration. Side movement grips are removed; blank-space body dragging is the movement model. Centered selection controls remain.

## Reveal lifetime correction — 0.9.7

Hidden covers remain hidden only while the chosen item/group stays selected; deselection restores them automatically. Editor blur, drag and saves do not end selection. This supersedes the manual-only lifetime in 0.9.6.
