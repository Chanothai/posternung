Placeholder for SIT-specific Android resources. Add
`mipmap-{mdpi,hdpi,xhdpi,xxhdpi,xxxhdpi}/ic_launcher.png` here with
SIT-branded artwork — Gradle merges this source set on top of `main`, so
until these exist the `sit` flavor falls back to the default launcher icon
in `src/main/res/`. See `docs/environments-setup.md`.
