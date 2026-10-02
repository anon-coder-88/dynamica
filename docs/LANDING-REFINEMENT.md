# Landing refinement — October 2, 2026

## Reference provenance

The attached `Dynamica-Website-PRD(2).docx` was read again for this revision. Its three design reference URLs were opened through the web retrieval tool on October 2, 2026; all three returned an accessibility error. No new rendered or interactive inspection is claimed.

| Reference | PRD-recorded observation | Adaptation in this revision |
| --- | --- | --- |
| https://shillora.fun/ | Large split hero, dark theme, distinctive galaxy visual | Split hero with an original, brand-derived interactive 3D centerpiece; no copied assets |
| https://gained-pad.xyz/ | Monochrome dark presentation, particle visual, motion control | Continuous graphite palette, restrained motion, explicit pause, concise numbered structure |
| https://foretell-market.xyz/ | Structured discovery, sidebar/filter organization, market cards | Clear module selection and structured six-strategy catalog |

These are PRD-recorded visual observations, not current-site verification or evidence of conversion performance. No assertion is made that the references won an award or that this design reproduces their animations.

## Visual and motion design

The home page now uses graphite #0D1212, warm white #F0F3E9, muted sage-gray #B2BEB6 and restrained citron #D6EF98. Section separation comes from spacing, hairlines, and content hierarchy; large light/bright section backgrounds have been removed from the landing page.

The hero uses real Three.js WebGL geometry extruded from the existing canonical Dynamica SVG mark. Six layered bodies represent the six whitepaper strategy classes; the independent luminous square expresses the permission checkpoint. This is a proposed brand metaphor, not a tokenomics claim. No native ticker, supply, or economic value is invented. The visitor can separate and assemble the layers; pointer response and subtle drift are optional presentation effects.

Motion consists of clipped headline reveals, staged content entrances, module-icon transitions, layer assembly, native-scroll-linked cycle emphasis, and understated catalog interactions. Native scrolling is preserved. The existing Motion control stops continuous effects, system reduced-motion is honored, and sound remains off by default.

## Implementation safeguards

- Three.js is dynamically imported only by the landing-page object component.
- The optimized existing sculpture remains visible before initialization and when WebGL fails.
- Renderer resolution is capped at 1.25 device pixels on narrow screens and 1.7 otherwise.
- Continuous rendering pauses when the object is offscreen, the document is hidden, or motion is disabled.
- Geometries, materials, the environment map, observers and rendering resources are disposed on unmount.
- Module choices and 3D layer assembly use actual buttons with expanded/pressed states; app navigation remains normal links.
- App financial workflows and action policies are unchanged.

## Verification boundaries

TypeScript checks and static production export pass. The route smoke check passes for six routes and their local asset references. Source palette checks are recorded in `landing-contrast.json`; these do not constitute computed browser contrast checks or an accessibility certification.

A permitted browser-control context is still unavailable. Actual WebGL appearance, animation timing, mobile reflow, sound output, and keyboard interaction remain unverified in a running browser. The fallback image and native content are retained to avoid making access dependent on the 3D renderer. No browser screenshot, runtime interaction result, or performance metric is claimed.
