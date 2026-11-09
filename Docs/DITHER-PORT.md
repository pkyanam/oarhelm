# Native dither surfaces

References: https://dithercn.dev/docs/engine/dither-engine and https://dithercn.dev/docs/theming.

Oarhelm reimplements the tone-versus-threshold idea in SwiftUI Canvas using a 4 by 4 Bayer matrix. Sparse brass dots follow a background falloff or panel edge light. A single batched path and adaptive cell size bound rendering work. There is no animation timer, React runtime, shader dependency, or copied upstream source.

VikingTheme integrates the surface beneath actual Liquid Glass panels, subtle action rows, and the app backdrop. Text and external webpages are not filtered. Reduce Transparency disables the texture and selects solid theme surfaces.
