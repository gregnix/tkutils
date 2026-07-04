# tkutils::tkudhash

The image-file front end for the perceptual dHash. It decodes an image with Tk's
photo image (plus the `Img` package for JPEG/TIFF/… when available) and hands the
pixels to the Tk-free core `tclutils::tudhash`. In other words: `tudhash` does
the maths, `tkudhash` does the loading.

Needs Tk (8.6+/9.x). `Img` is optional — PNG/GIF/PPM work with plain Tk, and
`Img` adds JPEG, TIFF and more.

## Commands

```tcl
tkudhash::fromFile      path ?-sample N?      ;# -> 16 hex chars
tkudhash::similarFiles  pathA pathB ?maxDist? ;# -> bool (default 10)
tkudhash::distance      a b                   ;# -> 0..64  (from tudhash)
tkudhash::similar       a b ?maxDist?         ;# -> bool    (from tudhash)
```

`fromFile` returns the 64-bit dHash of an image file as 16 hex chars.
`distance`/`similar` are re-exported from `tudhash` so a caller needs only this
one package.

## Example

```tcl
package require tkutils::tkudhash
namespace import ::tkutils::tkudhash::*

set h1 [fromFile /share/scans/rechnung-042.png]
set h2 [fromFile /share/scans/rechnung-042-kopie.jpg]
if {[similar $h1 $h2]} { puts "same document (distance [distance $h1 $h2])" }

# or in one step:
similarFiles a.png b.png        ;# -> 1 / 0
```

## Speed on large scans

`-sample N` (default 48) caps the work: the image is first subsampled so its
long side is at most ~`2*N` pixels, and only that small copy is read; the core
then box-averages it to 9×8. The hash is deterministic and, because dHash is
scale-invariant, a 60×45 and a 1200×900 version of the same picture produce the
same hash. Raise `N` for a little more fidelity, lower it for speed.

## Errors

Error code `{TKUTILS TKUDHASH <REASON>}`:

| REASON | When |
|--------|------|
| `LOAD` | the file could not be decoded (unknown format → install `Img`) |
| `EMPTY` | the image has zero width or height |
| `OPTION` | unknown option to `fromFile` |

## Testing

`tkudhash.test` builds gradient PNGs and checks the hash format, that
near-duplicate images are `similar`, that different images are not, scale
invariance, and the load error. It needs a Tk display; run under `Xvfb`
(passes on 8.6 and 9.0). The maths itself is covered by `tudhash`'s tests.
