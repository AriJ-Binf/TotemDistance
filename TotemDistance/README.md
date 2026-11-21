# TotemDistance

A World of Warcraft: Forever addon (interface `16001`) that shows how far you are from each of your shaman totems and warns you when you walk out of a totem's range, or so far away that it is about to despawn.

## Install

Copy this `TotemDistance` folder (the one containing `TotemDistance.toc`) into:

`World of Warcraft\_forever_\Interface\AddOns\`

The result must be `...\AddOns\TotemDistance\TotemDistance.toc`. If you downloaded a zip, copy the inner `TotemDistance` folder, not the outer download folder. Then fully restart the game (not just `/reload`) and check that TotemDistance is enabled in the AddOns list on the character select screen.

The addon only reads and draws; it does not modify any game files.

## How it works

When you drop a totem, the game places it a couple of yards from you, in a spot that depends on its element and the way you are facing: Fire front-left, Earth front-right, Water back-right, Air back-left. TotemDistance records that spot from your position and facing at the moment you cast, then measures how far you have moved from it. If the game does not report your facing, the totem is assumed to be at your feet.

Each active totem gets a row with its icon and a bar showing how much of its range you have left:

- **Green**: well inside the range, for example `20 yd left`.
- **Yellow**: within the warning distance of the edge (5 yards by default).
- **Red, out of range**: the bar empties, the text reads `OUT by 4 yd`, the totem icon turns grey and its border flashes red.

When you step out of a totem's range, a large red `Out of Strength of Earth range!` warning flashes near the top of the screen, and a sound plays. You can turn the sound and the on-screen warning off separately, and change the text size and how long the warning stays on screen.

### Despawn warning

Totems despawn once you are more than 100 yards away from them. When you get within 15 yards of that (adjustable), an orange `Strength of Earth is about to despawn!` warning appears below the leaving range warning, with its own sound, and the totem's bar shows `despawn in 8 yd`. The warning fires again only after you come back closer than that. Once you are more than 100 yards away the totem counts as despawned and its bar goes away.

A bar also goes away when the totem's timer runs out or the game no longer lists the totem (destroyed, recalled, or replaced). `/totemdistance debug` shows the last few totems that left the tracker and why.

### Choosing which totems to track

All totems are tracked by default. Under game options, AddOns, TotemDistance, Tracked totems, uncheck the ones you don't care about; they no longer appear in the tracker or trigger warnings. That page also has each element's border color. `/totemdistance track` lists what is tracked, and `/totemdistance track windfury off` changes one.

Drag the tracker to move it, then turn on **Lock Interface In Place** in settings so it ignores the mouse and clicks pass through it to the game world. With no totems down it is hidden; use `/totemdistance test` to show it while you place it. Test mode drops four pretend totems where you stand, so you can walk away and watch the tracker and warnings react.

### Totemic Call and Totemic Recall

- **Totemic Call** (formerly Totemic Projection) moves your totems back around you, to the spots they would take if you recast them. The game does not report this as a totem change, so the addon watches for the cast and re-places every active totem the same way.
- **Totemic Recall** clears every bar the moment you try to cast it, whether or not the cast works (for example with no totems down). Pressing the button, a macro, or `/cast Totemic Recall` all count. Use it to clear a bar that got stuck.
- If a position ever drifts, `/totemdistance here` re-places all active totems around you as if you had just cast them.

## Settings

Open with `/totemdistance`, or in the game options under AddOns, TotemDistance. The main page has the tracker and warning settings; the Tracked totems page has the checklist and colors. Preview warnings shows both warnings with sample text so you can judge their size and timing.

| Command | Effect |
| --- | --- |
| `/totemdistance` | Open settings |
| `/totemdistance on` / `off` | Enable or disable |
| `/totemdistance lock` / `unlock` | Lock the interface in place or allow dragging it |
| `/totemdistance resetpos` | Move the tracker back to its default spot |
| `/totemdistance alert on` / `off` | Flashing on-screen warning when leaving range |
| `/totemdistance sound on` / `off` | Sound when leaving range |
| `/totemdistance warn <0-15>` | Yards from the edge where the bar turns yellow |
| `/totemdistance size <12-48>` | Warning text size (default 28) |
| `/totemdistance duration <1-10>` | Seconds a warning stays on screen (default 3) |
| `/totemdistance despawn on` / `off` | Despawn warning |
| `/totemdistance despawnsound on` / `off` | Sound with the despawn warning |
| `/totemdistance despawnwarn <5-40>` | Warn this many yards before despawn (default 15) |
| `/totemdistance track` | List tracked totems |
| `/totemdistance track <totem> on` / `off` | Track or stop tracking one totem |
| `/totemdistance preview` | Show both warnings with sample text |
| `/totemdistance color <1-4> <RRGGBB>` | Icon border color (1 Fire, 2 Earth, 3 Water, 4 Air) |
| `/totemdistance range <1-4> <yards\|auto>` | Override the range for a slot |
| `/totemdistance here` | Re-place all active totems around you as if just cast |
| `/totemdistance test` | Toggle pretend totems where you stand |
| `/totemdistance reset` | Reset all settings |
| `/totemdistance debug` | Print diagnostics, including why recent totems left the tracker |

`/tdist` works as a short alias.

## Known limits

- In dungeons and raids your position is hidden from addons, so there are no yards and no despawn warning. Bars show the totem's time left instead. Totems that put a buff on you while you're in range (Strength of Earth, Mana Spring, Grace of Air, Stoneskin, resistance totems and others) show `in range` or `OUT of range` from that buff, with the usual warning. The addon learns each totem's buff the first time it sees it. Totems without a buff (Searing, Magma, Earthbind, Tremor and others) show `range unknown here`. If the game hides buffs in combat, those totems also show `range unknown here` until it shows them again.
- In combat the game hides totem details from addons. Totems dropped in combat get a bar built from your cast, timed with the duration the game last reported for that totem. The first time you ever drop a totem in combat, before the addon has seen its duration, its bar has no timer until combat ends.
- Totem placement (2.5 yards, in the pattern above) follows the original game's behavior and may be off by a yard or so.
- Totem names are matched in English. On other locales, ranges come from the spell tooltip, which also expects English "yards" text. Use `/totemdistance range` to set them manually.
- Ranges marked `verified = false` in `Data.lua` come from Classic or are guesses. Compare them with the in-game tooltips.

## Files

- `TotemDistance.toc`: manifest, interface 16001, saved variable `TotemDistanceDB`.
- `Data.lua`: elements, default colors, range table with each totem's element, range lookup.
- `Core.lua`: totem tracking, totem placement, update loop.
- `Tracker.lua`: tracker rows, leaving range and despawn warnings, sounds.
- `Options.lua`: settings pages, slash commands, debug output.
