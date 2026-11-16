# tkutils::tkufiledialog

Modal **open / save / directory** chooser on top of `tkupath` + `tkufilelist`.
Same look as the explorer stack; local `tuprovider` by default, optional
`-provider` for ZIP/remote. On the left **Places**: the home folder and the
user folders, drives or the root, and -- with `-app` -- bookmarks and recent
folders. Returns a path (or a list with `-multiple`), or `""` / `{}` if
cancelled. Tk 8.6+ and 9.x.

Not a full file manager — a compact dialog for “pick this file/folder”.

## API

```tcl
::tkutils::tkufiledialog::open      ?options?
::tkutils::tkufiledialog::save      ?options?
::tkutils::tkufiledialog::directory ?options?
::tkutils::tkufiledialog::bookmarks    app        ;# list of {label path}
::tkutils::tkufiledialog::setBookmarks app list   ;# replace them
```

## Options

| Option | Meaning |
|--------|---------|
| `-parent w` | toplevel for transient / placement |
| `-title t` | window title |
| `-initialdir d` | start directory (default: the last one with `-app`, else `$HOME` or `pwd`) |
| `-provider p` | `tuprovider` (default: fresh local) |
| `-filetypes {{Label {.ext …}}…}` | type combobox → list filter; every extension of a type counts |
| `-multiple 0\|1` | open only: return a list of paths |
| `-showhidden 0\|1` | show hidden files (the dialog has a check box for it) |
| `-showsystem 0\|1` | Windows: also show hidden system files |
| `-hideextensions 0\|1` | hide known extensions in the names |
| `-columns keys` | columns of the list (`name mtime type size ext`) |
| `-timeformat f` | `clock format` of the Modified column |
| `-app name` | remember bookmarks, recent folders, last folder, view and size for this application |
| `-places 0\|1` | the Places pane (default 1; only with the local provider) |
| `-initialfile name` | save only: prefill name entry |
| `-defaultextension .ext` | save only: append if name has no extension |

## Behaviour

- Double-click a **directory** → navigate; double-click a **file** → OK (open/save).
- Escape / Cancel → empty result; OK / Return in the name field → confirm.
- Directory mode lists folders only; OK returns the selected folder or the
  current path.
- **Show hidden files** at the bottom switches hidden files on and off. On
  Windows, protected system files (hidden **and** system, such as
  `desktop.ini`) stay hidden, as in the Explorer; only `-showsystem 1` in the
  call shows them.
- A right-click on the column headers shows and hides columns.
- **Places** (local provider only): Home, Desktop, Documents, Downloads --
  on Linux the folders named in `~/.config/user-dirs.dirs`, so a German
  "Schreibtisch" is found; on Windows the folders from the registry
  (`User Shell Folders`, read only), so a Desktop moved to OneDrive is found
  -- then the drives (Windows; not Tcl 9's `//zipfs:/`) or the root.

## Bookmarks and settings (`-app`)

With `-app name` the dialog keeps, per application, in the config directory
of `name` (`tclutils::tusettings`: `%APPDATA%\name`, `~/.config/name`,
`~/Library/Application Support/name`):

- `filedialog.ini` -- the bookmarks, the view (columns, hidden files,
  extensions, sorting), the window size and the last folder;
- `filedialog-dirs.txt` -- the last ten folders confirmed with OK.

"+ Bookmark this folder" adds the current folder, once: paths are compared
normalized, on Windows without regard to case. A right-click on a bookmark
offers Rename and Remove. A bookmark or recent folder that no longer exists
(a USB stick pulled out) is shown grey and kept. Without `-app` nothing is
written. An option given in the call wins over the saved view.

## Use

```tcl
package require tkutils::tkufiledialog

set f [::tkutils::tkufiledialog::open -parent . -app myapp \
    -title "Open text" -filetypes {{Text {.txt .md}} {All *}}]

set d [::tkutils::tkufiledialog::directory -parent . -initialdir /tmp]

set s [::tkutils::tkufiledialog::save -parent . -app myapp \
    -initialfile out.txt -defaultextension .txt]
```

## Texts

Labels are English and go through `msgcat` (namespace `::tkutils`), like
`tkufilelist`: `Places`, `Bookmarks`, `Recent`, `Home`, `Desktop`,
`Documents`, `Downloads`, `Computer`, `+ Bookmark this folder`,
`Show hidden files`, `Rename...`, `Remove`, `Rename bookmark`, `Open`, `Save`,
`Choose folder`, `Name`, `Folder`, `Type`, `OK`, `Cancel`, `All files`.

## See also

`tkufilelist`, `tkupath`, `tkudialog`, `tclutils::tuprovider`, `tclutils::tusettings`
