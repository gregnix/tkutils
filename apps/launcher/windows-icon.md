# Changing the icon of the built Windows .exe

When you cross-build with a Windows basekit (e.g.
`zipkit-9_0_4-win64-intel-tk.exe`), `zipfs mkimg` only appends your zip archive
to the basekit -- it does **not** touch the PE resource section, so the produced
`.exe` keeps the basekit's icon. To use your own icon you must replace the
icon **resource** (`RT_GROUP_ICON` + `RT_ICON`) in the PE file. `build-app` /
`tuzipfs` have no icon option, and this is a post-build step.

## 0. Make an .ico first

From a PNG (ideally a square image, 256x256), build a multi-size `.ico`.

- With ImageMagick:
  ```bash
  convert icon.png -define icon:auto-resize=256,128,64,48,32,16 app.ico
  ```
- Or with icoutils:
  ```bash
  # scale to the standard sizes, then pack them into one .ico
  for s in 16 32 48 64 128 256; do convert icon.png -resize ${s}x${s} ic-$s.png; done
  icotool -c -o app.ico ic-16.png ic-32.png ic-48.png ic-64.png ic-128.png ic-256.png
  ```

## 1. Recommended: rcedit (works from Linux via Wine)

`rcedit` replaces the whole icon group correctly (all sizes, consistent group).
It is a Windows executable, so on Linux run it under Wine (`apt install wine`,
or `wine64`). `rcedit` itself comes from npm or from its GitHub releases.

```bash
# get rcedit (either of these)
npm install rcedit            # -> node_modules/rcedit/bin/rcedit-x64.exe
#   or download rcedit-x64.exe from github.com/electron/rcedit/releases

# replace the icon of the built exe
wine node_modules/rcedit/bin/rcedit-x64.exe tkulauncher.exe --set-icon app.ico

# rcedit can also set version strings while you are at it:
wine .../rcedit-x64.exe tkulauncher.exe \
     --set-icon app.ico \
     --set-version-string ProductName "Launcher" \
     --set-version-string FileDescription "Launcher" \
     --set-file-version 1.0.0.0
```

This is the most reliable route and is scriptable in a build step.

## 2. On a Windows machine (no Wine)

If you have Windows handy, use **Resource Hacker** (free, GUI + CLI):

```bat
ResourceHacker.exe -open tkulauncher.exe -save tkulauncher.exe ^
  -action addoverwrite -res app.ico -mask ICONGROUP,MAINICON,
```

or run the same `rcedit-x64.exe --set-icon app.ico` there natively.

## 3. Do it at basekit level (once)

If you always want the same icon, patch the **basekit** once with rcedit /
Resource Hacker, then build all your apps from that patched basekit. Every
`build-app` output then carries your icon with no per-build step.

## Notes / what does NOT work here

- `icoutils` (`wrestool`) on Linux only **extracts** resources; the build's
  `wrestool` has no `--replace`, so it cannot set an icon.
- `windres` / `llvm-rc` compile `.rc` scripts at **link** time -- they cannot
  patch an already-linked `.exe`.
- The Tk call `wm iconphoto` sets the **window/taskbar** icon at runtime, not
  the file icon Explorer shows. Use it in addition if you like:
  ```tcl
  image create photo appicon -file [file join $dir icon.png]
  wm iconphoto . -default appicon
  ```
  This app already does that: it loads `icon.png` from next to the script via
  `_setIcon`. Because `build-app` copies the whole `-app` directory into the
  image, the `icon.png` shipped in `apps/launcher/` is bundled automatically --
  no `-include` needed. Replace that file to change the runtime window icon.
