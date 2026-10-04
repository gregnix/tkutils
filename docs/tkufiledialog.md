# tkutils::tkufiledialog

Modal **open / save / directory** chooser on top of `tkupath` + `tkufilelist`.
Same look as the explorer stack; local `tuprovider` by default, optional
`-provider` for ZIP/remote. Returns a path (or a list with `-multiple`), or
`""` / `{}` if cancelled. Tk 8.6+ and 9.x.

Not a full file manager — a compact dialog for “pick this file/folder”.

## API

```tcl
::tkutils::tkufiledialog::open      ?options?
::tkutils::tkufiledialog::save      ?options?
::tkutils::tkufiledialog::directory ?options?
```

## Options

| Option | Meaning |
|--------|---------|
| `-parent w` | toplevel for transient / placement |
| `-title t` | window title |
| `-initialdir d` | start directory (default: `$HOME` or `pwd`) |
| `-provider p` | `tuprovider` (default: fresh local) |
| `-filetypes {{Label {.ext}}…}` | type combobox → list filter (first ext used) |
| `-multiple 0\|1` | open only: return a list of paths |
| `-showhidden 0\|1` | show dotfiles |
| `-initialfile name` | save only: prefill name entry |
| `-defaultextension .ext` | save only: append if name has no extension |

## Behaviour

- Double-click a **directory** → navigate; double-click a **file** → OK (open/save).
- Escape / Cancel → empty result; OK / Return in the name field → confirm.
- Directory mode lists folders only; OK returns the selected folder or the
  current path.

## Use

```tcl
package require tkutils::tkufiledialog

set f [::tkutils::tkufiledialog::open -parent . \
    -title "Open text" -initialdir [pwd] \
    -filetypes {{Text {.txt .md}} {All *}}]

set d [::tkutils::tkufiledialog::directory -parent . -initialdir /tmp]

set s [::tkutils::tkufiledialog::save -parent . \
    -initialfile out.txt -defaultextension .txt]
```

## See also

`tkufilelist`, `tkupath`, `tkudialog`, `tclutils::tuprovider`
