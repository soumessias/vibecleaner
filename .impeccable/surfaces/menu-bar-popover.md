# Menu bar popover

## Mode

Operate. A developer opens the menu bar item, checks real reclaimable space, filters the scan, selects cleanup candidates, and confirms the exact paths.

## Approved visual direction

Use the user's latest supplied Liquid Glass screenshot as a visual reference, then adapt it to a slim macOS menu bar popover capped around 440 × 520 points on a notebook. Keep the supplied glossy VibeCleaner logo visibly loaded from the app bundle. Use a measured space summary, delicate icon-and-label filter pills, compact grouped rows that scroll, and a clear fixed translucent blue Clean button with the broom logo and selected total. Keep the footer legible with the last scan, soumessias link, and Quit control.

Use native translucent material for the popover, summary, and rows, with restrained outlines and readable semantic text. Keep small controls light and delicate. The Clean button has an explicit custom label and short press response; while cleanup runs, the broom swings and light sweeps across the button. Respect Reduce Motion and Reduce Transparency.

## User path

Open the menu bar item → read the measured safe total → choose a category or the review queue → select rows → review the exact paths in the existing confirmation → clean.

## Quality bar

- The measured development storage total and safe/review/managed breakdown are live values from `CleanerStore`; don't copy illustrative amounts or counts from the image.
- Managed simulator, test-device, archive, device-support, and Android SDK storage is inspectable but never selected for cleanup.
- A short explanation from the managed total makes clear these files are more than logs and never cleaned by VibeCleaner.
- Filters, review shortcut, Settings, Scan, Finder, confirmation, last-scan time, attribution link, and Quit remain functional.
- Disabled, scanning, warning, no-results, and empty states remain clear.
- Long paths and row descriptions truncate safely; rows remain readable at the narrowest supported popover width.
- Preserve semantic text contrast, light/dark appearances, accessibility labels, and the macOS 13 fallback.
