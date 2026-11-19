# Changelog

All notable changes to TotemDistance. Newest first.

## 1.4.0

### Changed
- Totems now always count as despawned once you are more than 100 yards away. The despawn distance is no longer a setting, and `/tdist despawnat` was removed. How early you are warned is still adjustable.

### Removed
- The chat message that appeared when a totem vanished early while you were far away.

## 1.3.0

### New
- Despawn warning: an orange "...is about to despawn!" warning appears before a totem despawns because you moved too far away, and the totem's bar counts down the yards left. Adjustable warning distance (15 yards before despawn by default), with separate on/off switches for the warning and its sound.
- Tracked totems checklist: a "Tracked totems" settings page lists every totem by element. Unchecked totems don't appear in the tracker or trigger warnings. All totems are tracked by default. Includes Track all and Track none buttons.
- Customizable warnings: turn the leaving range warning and its sound on or off separately, and adjust the text size (12 to 48, default 28) and how long warnings stay on screen (1 to 10 seconds, default 3). New Preview warnings button.
- Commands: `/tdist size`, `/tdist duration`, `/tdist despawn`, `/tdist despawnsound`, `/tdist despawnwarn`, `/tdist track`, `/tdist preview`.

### Changed
- Element colors moved to the Tracked totems page.
- The per-element on/off checkboxes were replaced by the per-totem checklist. Elements that were turned off are tracked again.

## 1.2.0

### Changed
- Totem positions follow how the game places totems: about 2.5 yards from you, Fire front-left, Earth front-right, Water back-right, Air back-left, based on the way you face when casting. If the game does not report your facing, totems are assumed to be at your feet.
- Totemic Call and `/tdist here` re-place totems in that same pattern around you.
- Added a README to the addon folder.

## 1.1.0

### New
- Totemic Call (formerly Totemic Projection) is detected, and your totems' recorded positions move with them.
- `/tdist here` resets your active totems' positions around you.

## 1.0.0

- First release as a standalone addon, split out of TotemRange.
- Tracker with one row per active totem: icon, name, and a bar of range left, green, yellow near the edge, red when out of range.
- Leaving range warning: flashing on-screen message and sound when you step out of a totem's range.
- Movable, lockable tracker, test mode with pretend totems, editable element colors, range overrides, and debug output.
