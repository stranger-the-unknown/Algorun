# Branding

The app icon is Grok's variation 4 (`grok-variation-4.jpg`, picked by the user
on 2026-09-30): two graphite code blocks and a sage-green block that ends in a
play arrow — "algorithm + run". Grok's JPG is portrait, noisy and not square,
so its shapes were measured and redrawn as clean geometry. The drawing is
unchanged; only the edges and colours are exact.

`algorun_icon.svg` is the master (1024 px, full bleed, symbol 62 % of the
height). Every platform icon was generated from the same geometry:

| Platform | Files | Symbol height |
|---|---|---|
| Android 8+ | `res/mipmap-anydpi-v26/ic_launcher*.xml` → vector `drawable/ic_launcher_foreground.xml`, `ic_launcher_monochrome.xml` (Android 13 themed icons), ground `@color/ic_launcher_background` | 46 dp of 108 dp (inside the 66 dp safe circle) |
| Android 7 | `mipmap-*/ic_launcher.png` (rounded square), `ic_launcher_round.png` | 60 % |
| iOS | `AppIcon.appiconset/*.png`, full bleed, no alpha | 62 % |
| Web | `favicon.png` (32 px), `icons/Icon-192/512.png` (rounded), `icons/Icon-maskable-*.png` (full bleed, inside the 40 % safe radius), `icons/apple-touch-icon.png` | 70 / 60 / 56 / 62 % |

Colours: ground `#F4F4F5`, blocks `#373B44` (stripe `#30353B`), arrow block
`#729577` (stripe `#5B7D62`).
