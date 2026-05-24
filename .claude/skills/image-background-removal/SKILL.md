---
name: rembg-bg-remover
description: Remove backgrounds from images using the rembg command-line tool. Use this skill whenever the user wants to remove, strip, or delete the background from an image, make image backgrounds transparent, isolate or extract a subject from a photo, cut out a person/product/object from its background, or batch-process multiple images for background removal. Covers single images, folder batches, mask-only output, custom-color background replacement, and the rembg HTTP server. Trigger on phrases like "remove background", "make this transparent", "isolate the subject", "cut out", "product photo cleanup", "transparent profile pic", "sticker from photo", or any background-removal task — even when rembg isn't mentioned by name.
---

# rembg Background Remover

Workflow for removing image backgrounds with the `rembg` CLI. `rembg` is a Python tool that runs ONNX segmentation models locally. It produces transparent PNGs by default, supports folder batches, can output the segmentation mask alone, and can paint the background a custom color.

## Setup

Check whether `rembg` is installed:

```bash
rembg --version
```

If not installed, install the CLI flavor (the plain `rembg` package omits CLI dependencies and will fail with `ModuleNotFoundError: filetype`):

```bash
pip install "rembg[cli]"
```

The first run for a given model downloads the ONNX weights (~50–400 MB depending on the model) to `~/.u2net/`. Subsequent runs are fast.

## Choosing the right model

`rembg` ships with ~19 models. The right choice depends on the **subject**, **quality target**, and **speed budget**. Default to `u2net` only when nothing better fits — there's usually a more appropriate choice.

Before picking, take a moment to look at the image (or ask one targeted question) so the model matches the subject. Running `isnet-anime` on a real photo, or `u2net_cloth_seg` on a landscape, produces obviously broken output. A quick "Is this a portrait of a person, or a product shot?" beats a wrong guess.

### By subject

| Subject | Recommended model | Why |
|---|---|---|
| Human portraits, headshots, full-body people | `birefnet-portrait` (quality) or `u2net_human_seg` (speed) | Trained on human silhouettes; handles hair edges well |
| Anime, manga, cel-shaded or hand-drawn 2D illustration, line art | `isnet-anime` | Trained on flat, stylized 2D art; general models fail badly here. **Not** for photoreal CGI or 3D renders — see note below the table. |
| Clothing items (per-garment masks) | `u2net_cloth_seg` | Outputs separate masks for upper-body, lower-body, and full-body garments |
| Products, objects, e-commerce shots, animals, general scenes | `birefnet-general` (quality) or `u2net` (speed) | Strong all-purpose segmentation |
| Fine structures: hair, fur, plants, lace, transparent glass | `birefnet-dis` + alpha matting | Dichotomous segmentation preserves thin details other models smear |
| Camouflaged or low-contrast subjects | `birefnet-cod` | Designed for objects that blend into the background |
| High-resolution images where detail matters | `birefnet-hrsod` or `birefnet-massive` | Tuned for high-resolution salient object detection |

**Photoreal CGI, 3D renders, and game key art are not "anime."** Even though they're "illustrated," they share the visual statistics of real photos (lighting, depth, texture, photoreal skin and materials) and should be treated as photos: `birefnet-portrait` for a human character, `birefnet-general` for everything else. `isnet-anime` will produce bad results on photoreal CGI — it expects flat shading and clean line work.

### Speed vs. quality

Rough CPU ranking from fastest to highest-quality:

`u2netp` ≲ `silueta` < `u2net` ≈ `isnet-general-use` < `birefnet-general-lite` < `birefnet-general` < `birefnet-massive`

For batch jobs over hundreds of images on CPU, prefer `u2netp` or `silueta`. For one-off hero shots, prefer `birefnet-general` or a subject-specific birefnet variant.

## Core workflows

### Single image → transparent PNG

```bash
rembg i -m birefnet-general input.jpg output.png
```

Output is always PNG (alpha requires it), regardless of input format. `-m` is technically optional, but explicit model selection is better than relying on the `u2net` default.

### Batch a folder

```bash
rembg p -m birefnet-general ./input_folder ./output_folder
```

`rembg p` writes one output per input file. Add `-w` to watch the folder and process new files as they appear. Add `-d` to delete each input after a successful conversion — use with caution, it is irreversible.

### Mask only (no original pixels)

```bash
rembg i -om input.jpg mask.png
```

Useful when the caller wants to composite the image themselves, or feed the mask into another pipeline (Photoshop, ffmpeg, ML training).

### Replace background with a solid color

The `-bgc` flag takes four integers — R G B A, each 0–255. For an opaque white background:

```bash
rembg i -bgc 255 255 255 255 input.jpg on_white.png
```

For a brand color, convert the hex first. Example: `#3b82f6` → `59 130 246`.

### Refining edges: alpha matting

When the result has jagged or chunky edges (common on hair, fur, and soft outlines), add alpha matting:

```bash
rembg i -m birefnet-general -a -ae 15 input.jpg output.png
```

Alpha matting runs a second pass that refines the foreground/background boundary using a trimap. It is slower (often 2–3× the base time) but produces noticeably softer, more accurate edges. Defaults for the foreground/background thresholds are usually fine; `-ae` (erode size) is the knob most worth tuning — raise it to 15–30 for fuzzy subjects, drop it toward 5 for sharp-edged products.

Post-process the mask (`-ppm`) to smooth small artifacts:

```bash
rembg i -m birefnet-general -ppm input.jpg output.png
```

`-a` and `-ppm` can be combined.

### HTTP server (for app integrations)

```bash
rembg s --host 0.0.0.0 --port 7000
```

Then POST images to `http://localhost:7000/api/remove`. Useful for wiring rembg into a web app or another local service. Stop with Ctrl-C.

## Pre-downloading models

To avoid first-call latency inside scripted or batch contexts, fetch a model up front:

```bash
rembg d birefnet-general
```

Models live in `~/.u2net/` (legacy directory name — it caches all models, not just u2net).

## Common pitfalls

- **`ModuleNotFoundError: filetype`** — the plain `rembg` package was installed without CLI extras. Reinstall with `pip install "rembg[cli]"`.
- **Output looks like the input with no transparency** — the output extension wasn't `.png`. JPEG can't hold an alpha channel.
- **The subject was cut in half or partially erased** — wrong model for the subject. Re-run with a subject-appropriate model (often the difference between `u2net` and `birefnet-portrait` on a person).
- **Hair or fur edges look chunky** — add `-a` (alpha matting), optionally with `-ae 20` and `-ppm`.
- **Out of memory on large images** — drop to `u2netp` or `birefnet-general-lite`, or resize the image first.
- **First call hangs for 30+ seconds** — it's downloading the model. Subsequent calls reuse the cached weights.

## Tips for batch jobs

1. Pick the lightest model that still produces acceptable quality on a sample. Test with `u2netp` first and escalate only if needed.
2. Pre-download the model with `rembg d` before launching the batch so the first file isn't slowed by network I/O.
3. Skip alpha matting unless edge quality demands it — it dominates runtime.
4. For very large batches, consider running `rembg s` once and posting images concurrently, rather than spawning a fresh process per file.
