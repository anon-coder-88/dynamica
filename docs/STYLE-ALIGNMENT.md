# Site-wide style alignment

The landing page is the visual reference for all routes. Shared tokens now define its graphite canvas (#0d1212), quiet panel surface (#141c1b), warm white text (#f0f3e9), secondary text (#b2beb6), borders (#35423b), and citron accent (#d6ef98). The landing palette aliases these tokens.

The previous blue gradient refinement layer was replaced rather than retained beneath another override layer. Public content pages have an explicit content-page scope, coordinated header/footer, lighter editorial headings, numbered ecosystem modules, ruled document cards, and comfortable article spacing. Public navigation marks the current route.

All app workspaces share flat surfaces, compact corners, restrained borders, and consistent button, input, table, dialog, and empty-state treatments. The dashboard's old decorative sculpture background was removed. Semantic live, testnet, warning, and error colors remain distinct. The floating motion/sound controls also use the shared palette. Existing page transitions, reduced-motion behavior, and financial workflows remain intact.

## Checks

- Production build and TypeScript passed.
- Static smoke: 6 routes and 192 local asset/route references.
- Four public content routes export the scoped page wrapper and expected active navigation.
- Source diff whitespace check passed.
- Calculated text contrast: primary text 16.81:1, secondary text on panels 9.02:1, primary buttons 13.87:1, outline/ghost hover 12.25:1, disabled controls 7.24:1. Semantic badges range from 9.05:1 to 10.72:1. Input borders against the input background: 4.51:1.
- Responsive rules were inspected for public grids, headings, app sidebar, workspace spacing, and controls at desktop, tablet, and mobile breakpoints.
- Browser-rendered visual, interaction, and zoom checks were unavailable and are not claimed.
