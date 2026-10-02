# Page loading and navigation transitions

The local 3D loading animation has been removed. Initial document loads now use a full-screen Dynamica introduction: the canonical D mark traces in, the permission checkpoint settles into place, the wordmark rises letter by letter, and three graphite panels reveal the page. Citron provides the visual accent.

The introduction coordinates with the hero's actual renderer state. Other pages release after a brief entrance. The initial wait is bounded at 3.2 seconds, followed by a 650 ms reveal, so the 3D renderer cannot block the page indefinitely. Skip intro releases it sooner. There is no invented loading percentage. Renderer errors retain an inline retry action; the colored 3D materials remain unchanged.

Public-page links close the panels over 420 ms before normal document navigation. A short-lived session marker gives the next page a shorter arrival. Native external links, downloads, hash links, new-tab requests, and modified clicks bypass interception. Persisted browser-history restores dismiss stale transition state. App workspace changes use a 340 ms entrance and keep existing state/navigation handling synchronous.

Reduced-motion preferences and the existing Motion off setting bypass page animations. Background content is inert during the cover; Skip intro moves focus to main content when used. An independent pre-paint timer releases the initial cover if hydration fails; without JavaScript the page remains visible.

## Verification

- Production static build completed for all six public/app routes.
- TypeScript passed.
- Five focused tests cover eligible routes, native link behavior, preferences, arrival markers, and the hydration-failure release.
- Static smoke passed for six routes and 192 local asset/route references.
- Exported markup includes exactly one page overlay and content wrapper per route, includes the inline startup script, and contains no local 3D loader.
- Browser visual, keyboard interaction, and GPU verification were unavailable in this environment and are not claimed.
