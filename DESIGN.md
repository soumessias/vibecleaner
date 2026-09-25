# VibeCleaner design system

## Visual language

Follow the latest supplied Liquid Glass reference: a floating, translucent macOS menu bar surface with soft blue and cyan accents, confident system typography, rounded controls, and clear depth between navigation and content. Use the supplied VibeCleaner broom logo and keep the soumessias creator credit.

Keep the menu bar popover slim (about 440 × 520 points at most on a notebook) and let results scroll between a fixed header and action footer. Use an ultra-thin material shell and content surfaces, with restrained tint and semantic text for legibility over changing desktop backgrounds. Honor Reduce Transparency with an opaque window background. On macOS 26 and later, native Liquid Glass remains available for secondary controls; earlier systems use native materials.

## Main menu bar popover

- Lead with the VibeCleaner name, supplied logo, a short friendly tagline, Settings, and Scan.
- Put total measured development storage in a compact summary surface, with separate safe-to-clean, review-before-cleaning, and developer-tool-managed amounts. The review amount opens the review queue. Neither the total nor managed amount is presented as immediately reclaimable.
- Offer category filters for All, Xcode, Android, Package Managers, Temporary, and Others.
- Group real scan candidates by tool. Each row shows its actual size, safety, useful detail, and full path for discovered locations. Old, shut down XCTest clones and project Derived Data require individual review. Regular simulators, recent or active test devices, archives, device support, Android SDKs and AI models remain visible but cannot be selected.
- Keep a persistent, clearly labeled primary button for cleaning the selected items. Make it large enough to read and press, show the exact selected total, and keep the existing confirmation step. Animate the broom and a single light sweep only while cleanup is running; a press has a short tactile response. Honor Reduce Motion.
- Keep the last-scan time, soumessias link, and Quit action findable in the footer.

## Material and color

Use quiet, compact translucent circles for header controls and short icon-and-label filter pills. The selected pill is blue with a restrained glow. The main action uses a custom translucent blue/cyan surface, explicit white label, supplied broom logo, and trailing arrow so its content cannot disappear inside a system button style. Summary and candidate rows use ultra-thin system material, subtle outlines, and semantic text.

Cyan identifies VibeCleaner, selected filters, and safe cleanup. The primary action blends macOS blue and cyan. Review states use the system warning color. Text stays in semantic system colors so macOS can preserve legibility across wallpaper, appearance, and accessibility settings. Keep the app in light and dark appearances.

## Product truth and behavior

- Show only measured scan results; never use artwork values as live data.
- Keep safe cache totals separate from review-only candidates.
- Keep monitored-but-managed storage separate from both. It includes more than logs: regular simulator data, recent or active test devices, device support, archives, Android SDKs, emulators, and AI models. It is never selectable or passed to cleanup; explain this from the summary.
- Allow old, shut down XCTest clones only as unchecked review candidates. Revalidate with `simctl` at cleanup and use `simctl delete`, so Xcode controls removal. Preserve the last 24 hours of test devices.
- Discover generated Derived Data directly under project `.build` folders in Documents, without sweeping entire `.build` folders or touching adjacent `.xcarchive` releases.
- Leave review candidates unchecked by default. Keep their path visible before cleanup.
- Preserve archives, active simulators, user documents, and unknown locations.
- Preserve selection, filtering, scanning, cleanup confirmation, warnings, empty states, Settings, and Quit.
- Follow the Mac's preferred language, with English, Portuguese, and Brazilian Portuguese resources.

## Accessibility and compatibility

Keep standard SwiftUI controls and keyboard behavior, label icon-only controls, and preserve readable content on translucent surfaces. Respect Reduce Transparency and Reduce Motion. Support the existing macOS 13 deployment target with native material fallbacks.
