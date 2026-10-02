# Hero loading and material update

- Removed the image from the 3D hero's initial and failure states. No image is used as a loading substitute.
- Added an indeterminate six-segment assembly animation with actual initialization-stage labels, not simulated percentages or artificial wait time.
- The loader completes after shader compilation and the first render. A 30-second initialization timeout or a context failure presents a clear message with a Retry control; the rest of the page stays usable.
- Both the loading animation and the 3D presentation respect reduced motion and the existing Motion switch.
- Replaced near-neutral full-metal materials with pigmented, clear-coated layers progressing from deep teal through jade to citron. Side surfaces are darker; the independent permission checkpoint remains luminous citron. Reduced exposure, light intensity, metalness, and environment reflections to retain surface color.

Verification: TypeScript and static production build pass. Static HTML checks confirm zero images inside the 3D hero, six loader segments, and an accessible busy/status message. The six-route reference smoke check passes. Browser rendering, real GPU startup and the retry interaction remain unverified because a permitted browser-control context is unavailable.
