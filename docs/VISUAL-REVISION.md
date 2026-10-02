# Visual revision — October 2, 2026

## Changes
- Corrected primary buttons rendered as anchors: the existing unlayered global anchor color rule took precedence over layered text-color utilities. Explicit component selectors now define default, hover, outline, secondary, destructive, focus and disabled states for both button and anchor elements.
- Increased text contrast across secondary copy, input placeholders, badges, navigation, panels and modal reviews. Disabled controls retain legible text instead of applying overall opacity.
- Reworked the landing composition: larger sculpture stage, gentle floating motion and pointer tilt, a permission plaque, varied card spans, elevated cycle panel, a light strategy section and a citron closing section.
- Refined application surfaces, card hierarchy, selected navigation, typography and spacing without changing financial logic.
- Added scroll entrances and restrained interaction transitions. A visible Motion control pauses effects; operating-system reduced-motion preferences are respected.
- Added a Sound control, off on each page load, with quiet synthesized interaction tones only after explicit activation. No music, network audio downloads, or autoplay.

## Verification
- 18 source-level foreground/background pairs checked using relative luminance. The lowest checked ratio is 7.20:1; the primary button pair is 15.51:1. These are explicit palette checks, not computed browser style or a full accessibility audit.
- TypeScript and static production export pass. The static-route smoke check verifies local references after export.
- Browser-based visual and interaction verification remains unavailable because the required control-browser capability is not available. Motion, pointer behavior, audio output, and layout still require in-browser review. No screenshot or browser-test result is fabricated.
