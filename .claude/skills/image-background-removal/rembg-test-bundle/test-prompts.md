# rembg-bg-remover — test prompts

Drop these four images and this file into a working folder, install `rembg-bg-remover.skill` into Claude Code, then run each prompt in a fresh chat. The point is to verify the SKILL drives sensible model selection and correct command syntax on real outputs.

Setup once per machine:

```bash
pip install "rembg[cli]"
```

The first run for each unique model downloads weights to `~/.u2net/` (~50–400 MB each). Subsequent runs reuse the cache.

---

## Test 1 — Vector-style logo on a busy patterned "background"

Image: `nfl-draft-logo.jpg` (3072×5508, NFL Draft shield logo with a fake-transparency checkerboard pattern baked in as pixels)

Prompt:
> *Remove the background from this logo — I want a transparent PNG I can drop into video edits.*

What to look for:
- SKILL should steer toward `birefnet-general` (or `u2net`); no specific "logo" row exists, so general-purpose is the right read of the table.
- The cherry-blossom petals and eagle silhouette have fine edges — if the first pass shows chunky outlines, the SKILL's alpha-matting / `birefnet-dis` guidance is the right escalation.
- Image is ~17 MP; if OOM hits, the SKILL's `u2netp` / `birefnet-general-lite` fallback should be tried.

## Test 2 — Vehicle on a natural background

Image: `f1-williams-car.jpg` (2048×1365, Williams F2 car on track)

Prompt:
> *Cut this race car out of the background.*

What to look for:
- "Products, objects, e-commerce shots, animals, general scenes" row → `birefnet-general` (quality).
- Watch the antenna/T-cam stalk on top — thin vertical element where alpha matting may help.

## Test 3 — Composite human + scoreboard graphic (ambiguity test)

Image: `mlb-twins-pitcher.jpg` (2000×2500, Twins pitcher mid-windup with a Twins 6 — Red Sox 5 scoreboard graphic baked into the bottom)

Prompt:
> *Remove the background from this Twins photo, I just want the player on transparent.*

What to look for:
- The SKILL's "When the user doesn't say" paragraph should make Claude consider asking whether the scoreboard counts as subject or background — though here the prompt does explicitly say "just the player," so a confident `birefnet-portrait` run is fine.
- The scoreboard at the bottom should disappear (a human-segmentation model treats it as not-human, hence not-foreground).
- If you instead wanted both the pitcher and the scoreboard preserved, the right call would be `birefnet-general` or `u2net`, which segment on saliency rather than human-ness. Worth testing both variants.

## Test 4 — Photoreal CGI character art (the SKILL gap we just patched)

Image: `ac-blackflag-edward.jpg` (1920×1080, Assassin's Creed IV key art — Edward Kenway, photoreal CGI render)

Prompt:
> *Isolate Edward from this Assassin's Creed art.*

What to look for:
- This is the test that motivated the recent SKILL patch. The pre-patch language ("anime, manga, illustrations, line art → `isnet-anime`") could plausibly have steered Claude toward `isnet-anime`, which would have produced bad output on photoreal CGI.
- Post-patch, the table row is narrower ("cel-shaded or hand-drawn 2D illustration") and a callout below the table tells Claude to treat photoreal CGI/3D renders as photos. Expected pick: `birefnet-portrait` (human character) or `birefnet-general`.
- If the hood edge, rope fibers, or pistol details look rough, alpha matting (`-a -ae 15`) is the right escalation.

---

## What "passing" looks like

- For each test, the model choice the SKILL drives Claude toward matches the reasoning above.
- Output PNGs have clean alpha channels — no orphan halos around the subject, no chunks of subject erroneously removed.
- The hard case (Test 4) does **not** route to `isnet-anime`.

Report back with anything that surprises you and we can iterate on the SKILL.
