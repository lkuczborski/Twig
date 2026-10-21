# Twig identity

The Twig mark combines an organic twig with a Git-like branching silhouette. Its pale green branches sit on a deep green rounded-square plate. The small menu-bar symbol stays a monochrome system branch for legibility.

## Assets

- `Resources/Brand/Twig.png`: selected generated master, with original alpha preserved.
- `Resources/AppIcon.png`: 1024 × 1024 PNG export, used by the README.
- `Resources/AppIcon.icns`: native macOS icon with standard 1× and 2× representations.

Run `./script/make_icons.sh` to rebuild the exports. This only resizes and packages the selected master; it does not regenerate the artwork. Both development and release bundles use the same icon.

## Generation

Created with the built-in imagegen tool, followed by a cleanup edit through the same tool. No API key or fallback CLI was used. The original generated images remain in Codex's image output; the project owns copies of its selected asset. These assets are distributed under the repository's MIT license.

### Initial prompt

```text
Use case: logo-brand
Asset type: production macOS application icon and GitHub README logo for Twig.
Primary request: Design a beautiful, distinctive, exceptionally minimal logo for Twig, a lightweight native macOS menu-bar app that finds Git worktrees and opens projects in the right IDE.
Subject: a confident sculptural twig/branch symbol, one stem dividing into a few clean branches, subtly evoking Git branches and the letter T. Strong instantly recognizable silhouette and balanced negative space.
Style/medium: polished contemporary macOS app icon, precise geometry softened by organic curves, restrained dimensionality and finely controlled light; tasteful rather than ornate.
Composition/framing: one centered icon on a square 1024-by-1024 canvas, generous consistent padding; a macOS rounded-square plate with transparent pixels outside it. No presentation sheet, no mockup, no extra variants.
Color: a restrained coherent palette chosen to suit this small focused developer utility; clear contrast between branch mark and plate, recognizable at small icon sizes.
Constraints: no text, letters, wordmark, tiny details, foliage, botanical illustration, generic sparkle, photographic scenery, watermark, or extra objects. The branch symbol must remain readable at 32px. Finished production asset, not a collage.
```

### Cleanup prompt

```text
Use case: precise-object-edit
Asset type: final production Twig macOS app icon.
Input image: edit target, the generated Twig icon.
Primary request: Clean the transparent cutout only. Remove every stray white/green speck, detached pixel, halo, or fragment outside the rounded-square app-icon plate, especially the artifacts along its upper edge. All pixels outside the icon must be genuinely transparent, with one clean antialiased perimeter.
Constraints: preserve the exact branch symbol, its three rounded tips, silhouette, scale, position, colors, material, lighting, deep green rounded-square plate, composition, and padding. Do not redesign or add any objects or text. No shadow or noise beyond the clean silhouette.
```
