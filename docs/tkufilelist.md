# tkutils::tkufilelist

A detail file list, filled from a storage provider. The list counterpart to
`tkufiletree`: where the tree shows the hierarchy, the list shows the contents
of one directory in columns -- name, modified, type, size and extension, chosen
and ordered per option or by the user from a menu on the header. Directories
come first, hidden entries follow the rules of the system, known extensions
can be hidden, and one or several globs narrow the files. Tk 8.6+ and 9.x.

## API

```tcl
::tkutils::tkufilelist::widget          path ?options?
::tkutils::tkufilelist::setDir          path dir     ;# show a directory
::tkutils::tkufilelist::dir             path         ;# current directory
::tkutils::tkufilelist::refresh         path         ;# re-read the directory
::tkutils::tkufilelist::setFilter       path glob    ;# one glob ("" = all files)
::tkutils::tkufilelist::setFilters      path globs   ;# several globs ({} = all)
::tkutils::tkufilelist::columns         path         ;# shown columns, in order
::tkutils::tkufilelist::setColumns      path keys    ;# show these, in this order
::tkutils::tkufilelist::allColumns                   ;# name mtime type size ext
::tkutils::tkufilelist::setShowHidden   path bool
::tkutils::tkufilelist::setHideExtensions path bool
::tkutils::tkufilelist::view            path         ;# the view as a dict
::tkutils::tkufilelist::setView         path dict    ;# apply a saved view
::tkutils::tkufilelist::selectedEntry   path         ;# entry dict of the selection, or ""
::tkutils::tkufilelist::selectedEntries path         ;# all selected entry dicts, in row order
```

## Options

| Option | Default | Meaning |
|--------|---------|---------|
| `-provider` | local | a `tclutils::tuprovider` object |
| `-dir` | `/` | the directory to show first |
| `-show` | `both` | `both`, `files` or `dirs` |
| `-files` | 1 | old form of `-show` (0 = `dirs`) |
| `-columns` | `{name mtime type size}` | columns and their order, from `name mtime type size ext`; `name` is always shown |
| `-columnmenu` | 1 | right-click on the header: a menu to show and hide columns |
| `-showhidden` | 0 | show hidden entries |
| `-showsystem` | 0 | also show hidden Windows system files |
| `-hideextensions` | 0 | hide known extensions in the name (`report.pdf` shows as `report`) |
| `-knownextensions` | a common list | the extensions that count as known (lower case, dot optional) |
| `-dirsfirst` | 1 | directories before files, also after a click on a header |
| `-timeformat` | `%d.%m.%Y %H:%M` | `clock format` of the Modified column |
| `-sizeunits` | 1000 on macOS, else 1024 | 1024 gives KB/MB (Windows), 1000 kB/MB (macOS) |
| `-filter` | `""` | one glob for file names |
| `-filters` | `{}` | several globs; a file shows when it matches any |
| `-onactivate` | | script, appended the entry dict -- double-click / Enter |
| `-onselect` | | script, appended the entry dict -- selection change |
| `-height` | 16 | visible rows |

## Columns

| Key | Title | Shows |
|-----|-------|-------|
| `name` | Name | the name, without a known extension under `-hideextensions` |
| `mtime` | Modified | the modification time (`-timeformat`) |
| `type` | Type | `Folder`, `PDF file`, ..., `File` without extension |
| `size` | Size | the size, empty for folders (`-sizeunits`) |
| `ext` | Extension | the extension in lower case, without dot |

The cells hold the raw values -- size in bytes, time in seconds -- and the
table formats them, so a click on a header sorts by value, not by text.
Directories stay in front (`-dirsfirst`). Every column exists in the table;
hidden ones can be switched on later without rebuilding it.

## Hidden entries

What is hidden depends on the system, as in its own file manager:

- **Windows:** the *hidden* attribute; a leading dot means nothing
  (`.gitignore` is shown). A file that is hidden **and** has the *system*
  attribute (`desktop.ini`, `pagefile.sys`) stays hidden until `-showsystem 1`
  is given as well -- the Explorer's "Hide protected operating system files".
- **Linux, macOS:** a leading dot.

The local provider reports this in the entry keys `hidden` and `system`
(tclutils `tuprovider` 0.4). Other providers (ZIP, WebDAV, ...) do not, and
then the leading dot decides.

## View

`view` returns `columns`, `showhidden`, `hideextensions`, `sortcolumn` and
`sortorder` as a dict; `setView` applies one (missing keys stay as they are,
an unknown column is dropped). `tkufiledialog -app` stores the view per
application this way.

## Entry dicts

Callbacks and `selectedEntry` hand back the provider's entry dict: `name`,
`path`, `type` (`file`/`dir`), `size`, `mtime`, from the local provider also
`hidden` and `system`. The entry travels with its row when the list is sorted.

## Use

```tcl
package require tkutils::tkufilelist

::tkutils::tkufilelist::widget .list -dir [pwd] \
    -columns {name mtime size} -hideextensions 1 \
    -onactivate {apply {e {
        if {[dict get $e type] eq "dir"} {
            ::tkutils::tkufilelist::setDir .list [dict get $e path]
        }
    }}}
pack .list -fill both -expand 1
```

## Filtering

`setFilter` takes one case-insensitive glob, `setFilters` a list of them;
directories are never filtered, so navigation still works while a filter is
active. `""` or `{}` clears it. The `ctrlutils::cufilter` controller wires a
text box to `setFilter`.

```tcl
::tkutils::tkufilelist::setFilters .list {*.pdf *.docx}   ;# PDF and Word files
::tkutils::tkufilelist::setFilter  .list ""               ;# everything again
```

## Texts

Titles and type names are English and go through `msgcat`. An application
translates them in the `::tkutils` namespace, for example in German:

```tcl
namespace eval ::tkutils {
    foreach {en de} {Name Name Modified Geändert Type Typ Size Größe
            Extension Endung Folder Ordner File Datei "%s file" "%s-Datei"} {
        ::msgcat::mcset de $en $de
    }
}
```

## Provider-backed

Because the list is filled through a provider, the same widget shows a local
directory, the contents of a ZIP, or a WebDAV collection -- only the
`-provider` differs.

## See also

`tkufiledialog`, `tkufiletree`, `tkupath`, `tclutils::tuprovider`
