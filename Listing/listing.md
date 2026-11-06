# Hey Cousin! on CurseForge and Wago

What to fill in when creating the project on each site. Nothing in this folder ships with the addon.

## The fields

| Field | Value |
| --- | --- |
| Name | Hey Cousin! |
| URL slug (CurseForge) | `hey-cousin` |
| Summary | One click finds everyone online with your surname in WoW Forever. Whisper, invite or join their layer, and see cousins who share on your map. |
| Description | [description.md](description.md), as Markdown, with the image addresses filled in (see below) |
| Logo | [logo.png](logo.png) (1024 x 1024; CurseForge scales it down to 400 x 400). [logo-transparent.png](logo-transparent.png) has no background. Neither site's rules mention a GIF logo: submit the PNG, and the animation goes in the description |
| License | All Rights Reserved |
| Game | World of Warcraft, WoW Forever only |
| Main category (CurseForge) | Chat & Communication, or the closest there is |
| More categories (CurseForge) | Guild, Map & Minimap |
| Categories (Wago) | The same ones, or the closest Wago offers |
| Source code link | `https://github.com/powercover/HeyCousin` |
| Issues link | `https://github.com/powercover/HeyCousin/issues` |
| Donation link | None (your call; keep it out of the addon) |

## Images

Upload these to each project's gallery, then put each address in `description.md` in place of its
placeholder. `python Listing/make_shots.py` draws them all again (run `python tests/kit/screens.py`
first). The cards are 2560 x 1440, made from the addon's own frames, with a made-up family and places.
They aren't game screenshots.

| Placeholder | Image |
| --- | --- |
| `IMAGE_EMBLEM` | [emblem.gif](emblem.gif): the animated crest, a 5.8-second loop on a clear background (480 x 480) |
| `IMAGE_FOUND` | [found.png](found.png): Find my family, clicked |
| `IMAGE_PAGE` | [page.png](page.png): a cousin's page, with its buttons and meetings |
| `IMAGE_CRESTS` | [crests.png](crests.png): some of the crests you can make |
| `IMAGE_TREE` | [tree.png](tree.png): the Tree tab |
| `IMAGE_LOOKS` | [looks.png](looks.png): the three looks side by side |

The gallery's own order, best first: found, page, crests, looks, tree. The pop-ups aren't here: drawn in
test mode, they all say so.

### Gallery addresses

As uploaded to each site: [description-curseforge.md](description-curseforge.md) and [description-wago.md](description-wago.md) are
`description.md` with these in place of the placeholders, without the animated crest at the top until it's uploaded too.

| Placeholder | CurseForge | Wago |
| --- | --- | --- |
| `IMAGE_FOUND` | https://media.forgecdn.net/attachments/2156/174/found-png.png | https://cdn.wago.io/gallery/HO2UjIkBq20Z4TB2bGA95Z8NBsl0raaFjRWZiMqi.png |
| `IMAGE_PAGE` | https://media.forgecdn.net/attachments/2156/175/page-png.png | https://cdn.wago.io/gallery/LzjDreoTZii1dGhgdgtKZbmq9k0HoJQG9wHSsna7.png |
| `IMAGE_CRESTS` | https://media.forgecdn.net/attachments/2156/176/crests-png.png | https://cdn.wago.io/gallery/HHHBUQ9XK1szpaVraUmtZo1jrvJGgFBfRJCSXArS.png |
| `IMAGE_TREE` | https://media.forgecdn.net/attachments/2156/177/tree-png.png | https://cdn.wago.io/gallery/KmflmYpZWqHuVA7N3IkpoGIsCYfdcFMcWPVmNRcv.png |
| `IMAGE_LOOKS` | https://media.forgecdn.net/attachments/2156/178/looks-png.png | https://cdn.wago.io/gallery/1wiWqHacqtD5SbhnZ36LuSg5db75LpdidglQ1f4G.png |

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
