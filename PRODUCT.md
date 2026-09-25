# Product

<!-- impeccable:product-schema 1 -->

## Platform

Apple's macOS Human Interface Guidelines for a native menu bar utility; Liquid Glass controls and navigation on macOS 26+, with native material fallbacks on macOS 13–25.

## Stack

Swift and SwiftUI, as requested. The interface is a native menu bar extra with a Settings window.

## Users

- [Confirmed] Developers who use AI-assisted or “vibe coding” workflows on macOS, including iOS and Android development.
- [Inferred] Users who want a quick, low-friction way to understand and maintain development-generated disk usage without learning which folders are safe to remove.

## Product Purpose

- [Confirmed] VibeCleaner helps developers find and clean expendable development caches, build outputs, temporary build folders, and related residue.
- [Confirmed] It should be lightweight, friendly, native to macOS, available from the menu bar, and able to start at login.
- [Inferred] Success means users can see what is reclaimable, clean known-safe items confidently, and inspect risky or personal locations before taking action.

## Positioning

- [Inferred] A focused, open-source developer disk cleaner that distinguishes regenerable data from items that deserve review. It should never present all developer data as disposable.

## Operating Context

- [Confirmed] The primary interaction is opening a menu bar popover, reviewing disk use, and cleaning selected items.
- [Confirmed] Users need settings to choose observed folders and exclusions.
- [Inferred] Scans should cover only a known catalog of development locations, run on demand or at a modest interval, and leave the app idle between scans.

## Capabilities and Constraints

- [Confirmed] The application is for macOS and should use native Swift/SwiftUI.
- [Confirmed] The initial audience includes developers accumulating Xcode, Android, JavaScript, and temporary build data.
- [Inferred] Built-in cleaners should operate only on known paths. Safe caches may be preselected; ambiguous directories and custom locations require explicit review. Archives, active simulators, user documents, and broad system locations are preserved by default.
- [Inferred] The interface should use friendly Brazilian Portuguese and support English for an open-source audience.
- [Confirmed] Minimum supported macOS version: macOS 13. Public repository URL and release signing/notarization remain undecided.
- [Confirmed] Open-source license: Apache License 2.0.

## Brand Commitments

- [Confirmed] Product name: VibeCleaner.
- [Confirmed] The project is intended to be open source.
- [Confirmed] User-facing language should be friendly and approachable.
- [Inferred] The generated menu and settings concept at `docs/design/vibecleaner-concept.png` is the starting visual reference for this implementation.

## Evidence on Hand

- [Conversation evidence] A prior disk inspection found 78 GB in `/private/tmp` and 159 GB in `~/Library/Developer` on the user's Mac. These are historical findings from the referenced conversation, not a live scan performed by this app.
- [Confirmed] No product logo, repository URL, or license was supplied.

## Product Principles

1. Show what can be reclaimed separately from what should be reviewed.
2. Keep cleanup specific, transparent, and reversible where practical.
3. Do not require the user to learn filesystem internals to understand an action.
4. Stay quiet and idle between targeted scans.
