# Hey Cousin!

A World of Warcraft Forever addon that finds the players who share your surname.

WoW Forever has no realms. Every character has a first name and a surname, so many players share
a surname, like a family. Hey Cousin! finds your relatives and makes the family visible.

**In development.** WoW Forever opens on November 4, 2026.

## What it does

- **Finds your cousins**: players with your surname near you (your target, the mouse, nameplates,
  your group), in chat, and in your guild.
- **"A cousin is near!"**: a pop-up with their face, a sound, and a click to target them. A cousin
  on the other side of the war is the family's black sheep, with a pop-up of their own.
- **Your crest**: at the start of a relative's chat lines, in their tooltip, on the minimap.
- **The family window**: everyone you met, who is near you now, the family's stats, and a card for
  each cousin with Whisper, Invite and **Join their layer**.
- **The setup**: make your crest (shape, pattern, colors, a symbol, or roll the dice), write a
  motto, and pick your alerts and your look.
- **Two looks**: Pixel (chunky and cartoonish) and Smooth (dark and gold).
- **Test mode on Retail**: a made-up family, so you can try everything before WoW Forever opens.

## Commands

- `/cousin` (or `/heycousin`): your family
- `/cousin setup`: your crest, alerts and look
- `/cousin test`: a pop-up to try
- `/cousin theme`: the next look
- `/cousin status`: what the game tells the addon about you
- `/cousin debug`: the errors the addon caught, in chat

## Tests

Offline checks on WoW's own Lua, with the whole addon running on a small mock game: see
[tests/kit/README.md](tests/kit/README.md).
