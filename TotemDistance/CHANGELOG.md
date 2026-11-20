# Changelog

All notable changes to TotemDistance. Newest first.

## 1.5.1

### Fixed
- A totem recast after its previous copy expired, for example Searing Totem after a Totemic Call, sometimes got no bar. The game can briefly report the new totem with the old totem's start time, which made it look already expired. A successful totem cast now always gets a fresh bar, timed from the cast.

### Changed
- `/totemdistance debug` also shows what the game reports for each totem slot: the totem's name, when it started, and how long it lasts.

## 1.5.0

### New
- Casting Totemic Recall clears every tracker bar immediately. This also happens when the cast fails, for example when no totems are down or you are out of mana: pressing the button, a macro, or `/cast Totemic Recall` is enough. Totems you drop afterwards get new bars as usual.

## 1.4.2

### Fixed
- Tracker bars stayed on screen after their totem despawned. A totem's bar now goes away when its timer runs out, when you are more than 100 yards from it, or when the game stops listing it, even if the game never announces the change.
- Tracker bars sometimes vanished while their totem was still up. A single empty or hidden reading from the game, which can happen in combat, no longer removes a bar; the totem has to be missing for half a second.

### New
- `/totemdistance debug` lists the last few totems that left the tracker and why: timer ran out, more than 100 yards away, or the game reports it gone.

## 1.4.1

### Fixed
- The settings pages showed every checkbox unchecked and every slider at its lowest value the first time you opened them, even though the settings were on. They now show your actual settings, which are all on by default.

### Changed
- "Lock tracker position" is now called "Lock Interface In Place".

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
