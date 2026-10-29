# Validation record

The native macOS source compiles with Swift 6.4 using the package's Swift 5 language mode. The automated suite passes 23 tests covering project validation and round-trip, older version-1 files without optional mix fields, static-schema Klimper import, Roman notation and chord membership, playback clock/content end, shared mute/solo policy, and parsing exported MIDI events to verify channels, tempo, key, pan and note timing/order.

Manual desktop QA on the baseline app confirmed launch, palette chord insertion with a section, note creation, note dragging, undo, transport play/stop, Save As, MIDI export and reopening a saved project. Generated JSON and MIDI headers were inspected independently. The updated channel-mixing release also requires the final desktop QA recorded in delivery.

The installed reference application could only be inspected at its activation screen. Its workflows were reconstructed from official manuals, read-only bundle metadata, strings and static data-schema analysis. Exact interaction, visual, sound and algorithm parity is not established. See [functional coverage](../PARITY.md) for remaining limitations.

Local QA data and the user's session snapshot are retained in the ignored `qa/` folder and are not part of Git history. Compiled app bundles are in ignored `dist/`. No remote repository has been configured.
