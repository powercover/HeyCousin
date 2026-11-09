# Hey Cousin! 1.1.4

- **Fixed:** an error when you changed the look without a reload: a crest's letter was cleared before it
  had a font.
- **Fixed:** in Russian and Ukrainian, boxes showed instead of the dots between parts of a line (the game's
  Cyrillic font has no middle dot). They're bullets there now.

## 1.1.3

- **Family achievements.** Eleven small things a family does: your first cousin, ten cousins, the black
  sheep, the eldest, a reunion, a family raid and more. Quiet on purpose: no pop-up and no sound, one line in
  chat when you earn one (one line for several, and a setting turns it off), and what you'd already done
  counts without a word. The star on the Stats tab, or `/cousin achievements`.
- **Backup and restore.** Your whole family (cousins, meetings, crest, motto, achievements, settings) as one
  line of text to keep anywhere, and back after a new computer or a deleted WTF folder. The settings' About
  page, or `/cousin backup`. It's read as data, never run as code.
- **Long time no see!** A pop-up when you meet a cousin again after two weeks apart, with how long and where
  you met last.
- **A hello in your first whisper.** "Hi cousin! We share the Ashbrook name :)" waits in your chat box,
  yours to send or change.
- **Safer in dungeons and raids:** the family channel waits there, out of combat too.

## 1.1.2

- **Family reunions.** When two or more of your house are in one group, everyone in it who has the addon
  gets a banner with your crests side by side; five or more, a family raid. Once a group, again when
  another cousin joins, never in a fight. Try `/cousin test reunion`; a switch in the settings, under
  Alerts.
- **The family portrait** counts the cousins online, puts the crown by the eldest, names the highest
  level, and has a **Take a picture** button: a screenshot without the card's buttons.
- **Mottos travel.** Cousins who have the addon see your motto on your page and your tooltip, and you
  see theirs.
- **Other houses on tooltips.** A player of another house shows how many of it you've met ("House
  Stone: met 3"), from two on. A switch in the settings, under In the game.
- **Look up a family** also finds players from other realms in your group: `/who` lists your own realm
  only.
- **Fixed:** an error in dungeon fights (the family channel now waits out combat, boss fights and keys),
  and the surnames you meet most, which counted a player again after each login. Those counts start
  over.

## 1.1.1

- **Guild invites, fixed.** The game lets only you send a guild invite: in 1.1.0, Invite showed a
  "blocked" window and sent nothing. Now it shows the line to copy into your chat box: Ctrl+C, Enter,
  Ctrl+V, Enter.
- **`/cousin delete Name`.** Takes a cousin off your list, with every meeting. Meet them again and they're
  new, first pop-up and all.
- **Crests on the minimap show their symbol.** They were too small to get one.
- **A crown on the nameplate.** Over the crest of the cousin who looks like the eldest.

## 1.1.0

- **Settings.** Every choice in one place, by what it's for: the gear, the minimap's right-click or
  `/cousin settings`, and a page in the game's Options > AddOns. A click on the version number shows
  what's new.
- **A shorter setup.** Two steps: your crest, then your family. The rest has good defaults and is in the
  settings, with your crest and your guild's family words on pages of their own.
- **"(uses addon)".** Cousins who run Hey Cousin! are marked, their own crests show, and a line tells
  you when they come online. It says nothing `/who` doesn't show, but that you run the addon.
- **Family chat.** `/fam` talks to every cousin online who has the addon, in any guild.
- **Family news.** A line in chat when a cousin reaches a round level.
- **Groups.** A new tab: say what you're looking for, and cousins can click Join. That asks you, and
  the invite stays your click.
- **"Hey cousin!"** A button on the pop-up and on a near cousin's page: you wave and say it out loud.
- **The family map, fixed, and on your minimap.** Sharing beyond a guild didn't reach anyone in 1.0.0:
  the game doesn't deliver addon messages on a channel. Now they go straight to each cousin, and
  cousins who share show on your minimap too.
- **Crests on nameplates.** Made to work with any nameplate addon, with a red crest for a black sheep.
  Drag and resize the crest in the settings: while that page is open, the real plates around you show it,
  so you see exactly where it goes.
- **The family race.** You and your cousins with the addon, by level, on the Stats tab.
- **The family portrait.** Your house on one card, made for a screenshot.
- **Recruit.** The cousins with no guild, each with an Invite button and a welcome you write.
- **Your other characters** show in your family, and a crown marks the eldest cousin we know.
- **Look up a family.** Who's online with any surname: `/cousin find Surname`, or the magnifier in the
  family window.

Chat, groups, news and the online line go straight to the cousins in your family channel. Each can be
turned off in the settings, or all with one switch, and the game's ignore list counts. Chat and the map
are tested between real players. The rest, the minimap and nameplate crests above all, are new: please
tell me how they work for you, and which nameplate addon you use.

## 1.0.0

The first release, for World of Warcraft Forever.

- **Find my family.** One click searches the game's `/who` for your surname and lists everyone online
  with exactly that surname, with their level, zone and guild. Whisper them, invite them or join
  their layer from their page. When the game's list of 50 people fills up, the next clicks look
  through the levels.
- **The family map.** Cousins who share where they are show as crests on the world map, and on
  OpenMap's stitched map. A click opens their page. Sharing is off until you turn it on; then your
  guild and anyone with your surname who runs the addon can see you, on your faction only, never in
  a fight or a dungeon. Sharing beyond a guild is new: please tell me how far it reaches.
- **"A cousin is near!"** A pop-up with their face and a sound the first time you meet (or every
  time, if you want). Click it to target them. Black sheep, cousins on the other side, get their own.
- **The family window.** Everyone you met or found, who is near you or online now, the family's stats,
  and a page for each cousin: every time you met, where, when and how.
- **The family tree.** Your guild as a family, each rank a generation. A guild master can give each
  rank a family word and write a welcome line.
- **Your crest.** Make your own with shapes, patterns, colors and symbols. It shows in chat, in
  tooltips and on the minimap.
- **Three looks:** Pixel, Forever (the classic game's parchment) and Smooth.
- **12 languages:** English, German, French, Italian, Spanish (Spain and Latin America), Brazilian
  Portuguese, Russian, Ukrainian, Korean, and Chinese (simplified and traditional).
