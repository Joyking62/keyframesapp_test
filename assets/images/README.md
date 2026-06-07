# Brand assets

Drop your real brand files here so the app uses your exact logo:

- `keyframes_logo.png`  → full-color logo (transparent background, ideally 1024×1024)
- `keyframes_logo.svg`  → vector version (an approximation is already included)

The app's `BrandLogo` widget (see `lib/widgets/brand_logo.dart`) will automatically
prefer `keyframes_logo.png` if present, then fall back to the bundled SVG, and finally
to a hand-drawn `CustomPainter` version so the UI never looks empty.

To use the PNG, just add it here and uncomment the asset usage line inside
`brand_logo.dart` (instructions are in that file).
