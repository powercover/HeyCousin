# Hey Cousin!

A World of Warcraft Forever addon that finds the players who share your surname.

WoW Forever has no realms. Every character has a first name and a surname, so many players share
a surname, like a family. Hey Cousin! finds your relatives and makes the family visible.

## What it does

- **Find my family**: one click searches the game's `/who` for your surname and lists everyone
  online with exactly that surname (of your faction), with their level, zone and guild, then
  Whisper, Invite and Join their layer. Each search is one click; when the game's list of 50 is
  full, the next clicks look through the levels.
- **Recruit**: the cousins known to have no guild, each with one Invite button and a ready welcome
  you can change. A whisper is never sent by itself: it opens in your chat box for you to send.
- **Finds your cousins by itself**: players with your surname near you (your target, the mouse,
  nameplates, your group), in chat, and in your guild.
- **"A cousin is near!"**: the first time you meet, a pop-up with their face, a sound, and a click to
  target them (or every time, if you want). A cousin on the other side of the war is the family's
  black sheep, with a pop-up of their own.
- **Your crest**: at the start of a relative's chat lines, in their tooltip, on the minimap.
- **The family window**: everyone you met, who is near you now, the family's stats, and a page for
  each cousin: every time you met (where, when, how, both your levels, what they said, their gear
  when you were close), with Whisper, Invite and **Join their layer**.
- **Your other characters**: those with the same surname show under you in the family window, from
  the time each has logged in once. They aren't counted as cousins.
- **The eldest cousin**: a crown by who looks like the oldest character among the cousins you've seen
  and your own, guessed from the numbers in their character IDs.
- **The family tree**: your guild as a family, each rank a generation, the Elder on top. A guild
  where most share one surname is a family by itself; its guild master can give the family a word
  for each rank (Elder, Parent, Cousin, or their own) and a welcome line, and every member who
  runs Hey Cousin! gets them by themselves.
- **The family map**: the cousins who share where they are show as crests on the game's own world
  map, with their names, and on the minimap (at its edge when they're further away); a click opens
  their page. Sharing is off until you turn it on; then your
  guild and anyone with your surname who runs the addon can see you (your faction only, through a
  hidden family channel), every few seconds while you move, never in a fight or a dungeon. It works
  beside map addons that keep the game's map (Mapster, Leatrix Maps, TomTom, HandyNotes, Questie),
  and on OpenMap's stitched map, across all its zones.
- **Family chat, news and groups**: through the same hidden channel, cousins who have the addon are
  marked "(uses addon)" and see when each other come online. `/fam` talks to all of them, a line
  tells when one reaches a round level, and the **Groups** tab says what you're looking for: Join asks
  the one who posted, and the invite stays their click. It says nothing `/who` doesn't show, but that
  you run the addon. Each can be turned off, or all with one switch, and the game's ignore list counts.
- **"Hey cousin!"**: a button on the pop-up and on a near cousin's page: you wave and say "Hey cousin
  Mira!" out loud. Only ever from a click.
- **Crests on nameplates**: while the settings' Nameplates page is open, the real plates around you show
  the crest too, so you see where it goes. On the game's own plate frame, so they follow the plate under any nameplate
  addon. The settings draw a sample plate: drag the crest, scroll to resize it, and real plates follow.
- **The family race**: you and the cousins who have the addon, by level, with a line when one passes you.
- **Long time no see!**: a pop-up when you meet a cousin again after two weeks apart.
- **Family achievements**: eleven small things a family does, quiet on purpose: one line in chat when
  you earn one, no pop-up, no sound. The star on the Stats tab.
- **Backup and restore**: your whole family as one line of text to keep anywhere, and back after a new
  computer or a deleted WTF folder.
- **Family reunions**: two or more of your house in one group get a banner with their crests side by
  side, five or more a family raid. Only the ones in the group see it.
- **The family portrait**: your house on one card, made for a screenshot, with a button that takes it.
- **Look up a family**: who's online with any surname, by the same `/who` search. Nobody joins your
  family by it.
- **The settings**: every choice, grouped by what it's for, with a page in the game's Options > AddOns
  that leads to them. Your crest, and a guild master's words for their guild, are pages there. A click on
  the version number shows what's new.
- **The setup**: only what matters on day one, in two steps: make your crest (shape, pattern, colors, a
  symbol, or roll the dice) and pick your look; then your family: the pop-up, the map, the online line
  and whether cousins can see where you are. Everything else has a good default and is in the settings.
- **Three looks**: Pixel (chunky and cartoonish), Forever (the classic game's parchment pages in
  stone frames, red buttons) and Smooth (dark and gold).
- **12 languages**: English, German, French, Italian, Spanish (Spain and Latin America), Brazilian
  Portuguese, Russian, Ukrainian, Korean, and Chinese (simplified and traditional).
- **Test mode on Retail**: a made-up family, so you can try everything before WoW Forever opens.

## Commands

- `/cousin` (or `/heycousin`): your family
- `/cousin tree`: your guild as a family tree
- `/cousin recruit`: invite the cousins who have no guild
- `/cousin groups`: cousins looking for a group
- `/cousin race`: the family race, by level
- `/cousin portrait`: your house on one card, for a screenshot
- `/cousin achievements`: your family achievements
- `/cousin backup`: keep your family safe as a line of text, or bring it back
- `/cousin find Surname`: who's online with any surname
- `/fam your words`: talk to every cousin online who has the addon
- `/cousin settings`: every choice, by what it's for
- `/cousin setup`: your crest and the main choices
- `/cousin test`: a pop-up to try
- `/cousin test map`: made-up cousins on your map for two minutes, to try
- `/cousin test reunion`: a family reunion, to try
- `/cousin delete Name`: take a cousin off your list, with every meeting (seen again, they come back as new)
- `/cousin forget Name`: take a deleted character off your list
- `/cousin theme`: the next look
- `/cousin status`: what the game tells the addon about you, your character ID too
- `/cousin debug`: the errors the addon caught, in chat

## Tests

Offline checks on WoW's own Lua, with the whole addon running on a small mock game: see
[tests/kit/README.md](tests/kit/README.md).
