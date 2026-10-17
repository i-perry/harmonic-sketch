# REA evidence checklist

These notes capture static observations from the installed Klimper 2.4 ARM64 binary. They support evidence-led investigation; they do not establish 1:1 runtime parity.

- [Project model](PROJECT-MODEL.md): serialized project, section and clip shapes recovered; timing units, scale semantics, coordinate scope, editing transforms, and instrument behavior remain partial or unknown.
- [Section transforms](SECTION-TRANSFORMS.md): serialization, path traversal, a nested-length max update, and one section-append path are recovered. Move/resize/wrap/duplicate operations and descendant offset rules remain unknown.
- [Harmony](HARMONY.md): Flow, Contrast, Match Notes, and both Tonal callback branches are implemented with derived-vector tests. Flow/Contrast, Tonal, and Match Notes feed the palette through an explicit reconstruction mapping. The indirect invocation site, user-facing argument roles, exact score-to-visual mapping, palette ordering, and voicing generation remain partial or unknown.
- [Playback](PLAYBACK.md): integer-tick scheduler, event windows, loop-boundary note cleanup, and the ChordPreviewPlayer high-resolution timer path are partially recovered. Preview strum spacing, velocity mapping, loop-field initialization, and MIDI export detail remain unknown; the current native runtime smoke is incomplete because the UI stalled at the Play action.

All completed claims should cite their REA Evidence IDs, name their evidence type, and state coverage limits. A feature name or persisted field alone is not proof of its user-visible behavior. Keep unresolved claims marked unknown until new static or controlled runtime evidence supports them.
