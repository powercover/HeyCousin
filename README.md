# Hey Cousin!

A World of Warcraft Forever addon that finds the players who share your surname.

WoW Forever has no realms. Every character has a first name and a surname, so many players share
a surname, like a family. Hey Cousin! finds your relatives and makes the family visible.

**In development.** WoW Forever opens on November 4, 2026.

## What it does

- **Find my family**: one click searches the game's `/who` for your surname and lists everyone
  online with exactly that surname (of your faction), with their level, zone and guild, then
  Whisper, Invite and Join their layer. Each search is one click; when the game's list of 50 is
  full, the next clicks look through the levels.
- **Finds your cousins by itself**: players with your surname near you (your target, the mouse,
  nameplates, your group), in chat, and in your guild.
- **"A cousin is near!"**: a pop-up with their face, a sound, and a click to target them. A cousin
  on the other side of the war is the family's black sheep, with a pop-up of their own.
- **Your crest**: at the start of a relative's chat lines, in their tooltip, on the minimap.
- **The family window**: everyone you met, who is near you now, the family's stats, and a page for
  each cousin: every time you met (where, when, how, both your levels, what they said, their gear
  when you were close), with Whisper, Invite and **Join their layer**.
- **The family tree**: your guild as a family, each rank a generation, the Elder on top. A guild
  where most share one surname is a family by itself; its guild master can give the family a word
  for each rank (Elder, Parent, Cousin, or their own) and a welcome line, and every member who
  runs Hey Cousin! gets them by themselves.
- **The family map**: the cousins in your guild who share where they are show as crests on the
  game's own world map, with their names. Sharing is off until you turn it on; it goes only to your
  guild (one faction), every few seconds while you move, never in a fight or a dungeon. It works
  beside map addons that keep the game's map (Mapster, Leatrix Maps, TomTom, HandyNotes, Questie).
- **The setup**: make your crest (shape, pattern, colors, a symbol, or roll the dice), write a
  motto, pick your alerts, the family map and your look; a guild master makes their guild a family.
- **Three looks**: Forever (the classic game's parchment pages in stone frames, red buttons), Pixel
  (chunky and cartoonish) and Smooth (dark and gold).
- **12 languages**: English, German, French, Italian, Spanish (Spain and Latin America), Brazilian
  Portuguese, Russian, Ukrainian, Korean, and Chinese (simplified and traditional).
- **Test mode on Retail**: a made-up family, so you can try everything before WoW Forever opens.

## Commands

- `/cousin` (or `/heycousin`): your family
- `/cousin tree`: your guild as a family tree
- `/cousin setup`: your crest, alerts and look
- `/cousin test`: a pop-up to try
- `/cousin theme`: the next look
- `/cousin status`: what the game tells the addon about you
- `/cousin probe`: the name test: a short checklist that writes down how the game gives names to
  addons (for launch day)
- `/cousin debug`: the errors the addon caught, in chat

## Tests

Offline checks on WoW's own Lua, with the whole addon running on a small mock game: see
[tests/kit/README.md](tests/kit/README.md).
