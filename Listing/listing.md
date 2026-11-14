# Hey Cousin! on CurseForge and Wago

What to fill in when creating the project on each site. Nothing in this folder ships with the addon.

## The fields

| Field | Value |
| --- | --- |
| Name | Hey Cousin! Surname & Family Finder |
| URL slug (CurseForge) | `hey-cousin` |
| Summary | Surname finder for WoW Forever: one click finds every player online who shares your surname, your last name or second name. Family chat, group finder, map and nameplate crests, guild recruiting |
| Description | [description.md](description.md), as Markdown, with the image addresses filled in (see below) |
| Logo | On CurseForge: [emblem-small.gif](emblem-small.gif), animated, and it works there. Its thumbnails give every frame the first frame's delay, so a logo needs the same delay on all frames. [logo.png](logo.png) and [logo-transparent.png](logo-transparent.png) are the still ones (1024 x 1024) |
| License | All Rights Reserved |
| Game | World of Warcraft, WoW Forever only |
| Main category (CurseForge) | Chat & Communication, or the closest there is |
| More categories (CurseForge) | Guild, Map & Minimap, and Roleplay if it's offered |
| Categories (Wago) | The same ones, or the closest Wago offers |
| Source code link | `https://github.com/powercover/HeyCousin` |
| Issues link | `https://github.com/powercover/HeyCousin/issues` |
| Donation link | None (your call; keep it out of the addon) |

## Being found

CurseForge's search (2026-11-09) found Hey Cousin! for "family" and "cousin", but not for "surname", "last
name", "second name" or "family name", though the summary said "surname.". It matches the name best, so the
name carries "Surname" and "Family", and the summary and the description's first lines say surname, last
name and second name, each with a space after it (a word right before a period may not count). Change the
name and summary on both sites by hand; the URL slug stays `hey-cousin`.

## Images

Four pictures, one for each part of the addon, each several windows side by side (2026-11-14: the
user found thirteen too many). `python Listing/make_shots.py --store` draws them again (run
`python tests/kit/screens.py` first); without `--store` it draws the crest emblem and the logos too.
They're made from the addon's own frames, with a made-up family: never game screenshots.

| Placeholder | Image |
| --- | --- |
| `IMAGE_EMBLEM` | [emblem.gif](emblem.gif): the animated crest, a 5.8-second loop on a clear background (480 x 480) |
| `IMAGE_FIND` | [find.png](find.png): the found list, a cousin's page, the pop-up and a reunion |
| `IMAGE_TOGETHER` | [together.png](together.png): Help, Crafters and Groups |
| `IMAGE_EVERYWHERE` | [everywhere.png](everywhere.png): the family map and the nameplate crests |
| `IMAGE_HOUSE` | [house.png](house.png): the growing crest, achievements, the portrait and the guild tree |

The gallery's order: find, together, everywhere, house. Each site's addresses go in
[build_descriptions.py](build_descriptions.py); run it, and paste [description-curseforge.md](description-curseforge.md)
and [description-wago.md](description-wago.md). A picture with no address yet is left out.

### One picture to take in the game

The store page should show the family map on the real game map, and only a screenshot can. Don't use
one from Forever: it would show other players' real names, in the crests and in chat.

1. Log in on **Retail**, where the addon runs with a made-up family (the `_retail_` client).
2. Type `/console screenshotQuality 10` once, so the text stays sharp.
3. Type `/cousin test map`, open the world map, and hide your chat if other players' names show in it.
4. Press Print Screen, and send me the picture. It adds a `IMAGE_MAP` picture under "The family map".

The page works without it.

## Release, in order

**1. CurseForge.** On authors.curseforge.com, create a project: World of Warcraft, Addons. Fill in the
fields above and upload the logo. Note the **project ID** on the project page.

**2. Wago.** On addons.wago.io, in the developer dashboard, create an addon with the same fields. Note
the **8-character ID** under its name.

**3. Tell me both IDs.** They go in the TOC as `## X-Curse-Project-ID` and `## X-Wago-ID`. They aren't
secret.

**4. Add the two keys to the repository.** On GitHub: `powercover/HeyCousin`, Settings, Secrets and
variables, Actions, New repository secret. They can be the same keys as Better Great Vault's:

- `CF_API_KEY`: from authors.curseforge.com, API tokens
- `WAGO_API_TOKEN`: from addons.wago.io, your account's API keys

**5. Upload the images** and give me their addresses, and I'll make `description-curseforge.md` and
`description-wago.md`. Paste each into its site's description.

**6. Publish.** Test once in the game first, then this pushes the tag, and the release goes out by itself
(it's your click):

```bash
git tag 1.0.0
```

```bash
git push origin 1.0.0
```

The Actions tab on GitHub shows it working. The first file on CurseForge goes to its moderators for
review, so it may take a while to appear.
