# tkutils::tkico — build `.ico` files from Tk images

Renders the individual icon sizes with Tk and hands the PNG payloads to
`tclutils::tuico`, which assembles the container. Transparency is preserved,
because the payloads are PNGs written by Tk itself.

```tcl
package require tkutils::tkico 0.1
```

## The short version

```tcl
# best quality: every size rendered from the vector
tkutils::tkico fromSvg logo.svg app.ico

# from a raster image (integer scaling, see the caveat below)
tkutils::tkico fromPhoto $photo app.ico -sizes {32 16}

# full control: one image per size, nothing is scaled here
tkutils::tkico fromPhotos [list [list 32 $big] [list 16 $small]] app.ico
```

## Three ways to produce a size

**1. From SVG — the good one.** Each size is rendered from the vector at its
target resolution, so every step is crisp:

```tcl
image create photo -file logo.svg -format {svg -scaletowidth 48}
```

Tk 9 has SVG built in. Under Tk 8.6 the `tksvg` package provides the same photo
format; load it before calling `fromSvg`.

**2. From a raster image.** `fromPhoto` scales with Tk's `image copy
-zoom/-subsample`. These are integer factors sampled without interpolation, so
a 256-pixel source reduced to 16 pixels gets visibly ragged. Fine for a quick
icon, not for a shipped one.

**3. One image per size.** `fromPhotos` scales nothing and simply packs what it
is given — the escape hatch when you rendered the sizes elsewhere, or drew the
small ones by hand.

That last point is worth taking seriously: what reads well at 256 pixels turns
to mush at 16. Simplified artwork for the small steps beats any scaler.

## Commands

### `fromSvg svgFile outFile ?-sizes list?`

Renders every size from the SVG and writes the `.ico`. Returns the number of
bytes written. `-sizes` defaults to `{256 128 64 48 32 16}`.

### `fromPhoto photo outFile ?-sizes list?`

Scales one square photo image to every size. Same defaults, same return value.
The source must be square.

### `fromPhotos photos outFile`

Takes a list of `{size photoImage}` pairs. Each image must already be square and
match its nominal size.

### `defaultSizes`

Returns the default size list, `{256 128 64 48 32 16}`.

## Notes

- Sizes are sorted largest first and de-duplicated before writing.
- Images created internally are deleted again; images passed in by the caller
  are left alone.
- Tk needs a display connection even when no window is shown. In headless
  builds or CI, run under `Xvfb` and `wm withdraw .`.

## Errors

`errorCode` is always `{TKUTILS TKICO <REASON>}`:

| Reason | When |
|---|---|
| `NOSIZES` | empty size list, or no images given |
| `BADSIZE` | size outside 1..256 |
| `BADOPTION` | unknown option |
| `NOFILE` | source file not readable |
| `NOSVG` | SVG could not be rendered (no SVG photo format available) |
| `NOTSQUARE` | source image is not square |
| `SIZEMISMATCH` | supplied image does not match its nominal size |
| `BADENTRY` | entry is not a `{size image}` pair |
| `PNGFAILED` | Tk produced no PNG data |

Container-level problems surface with `{TCLUTILS TUICO ...}` from the underlying
module.

## Requirements

Tcl 8.6+, Tk 8.6+, `tclutils::tuico` 0.1. For `fromSvg`: Tk 9, or Tk 8.6 with
`tksvg`.
