# tkutils::tkufilelist

A detail file list, filled from a storage provider. The list counterpart to
`tkufiletree`: where the tree shows the hierarchy, the list shows the contents
of one directory in columns (name, size, type). Directories and files are sorted
separately, hidden files can be shown or hidden, and a glob filter narrows the
files. Tk 8.6+ and 9.x.

## API

```tcl
::tkutils::tkufilelist::widget        path ?options?
::tkutils::tkufilelist::setDir        path dir     ;# show a directory
::tkutils::tkufilelist::dir           path         ;# current directory
::tkutils::tkufilelist::refresh       path         ;# re-read the directory
::tkutils::tkufilelist::setFilter     path glob    ;# filter files by glob ("" = all)
::tkutils::tkufilelist::selectedEntry path         ;# entry dict of the selection, or ""
```

## Options

- `-provider`   a `tclutils::tuprovider` object (default: a local provider).
- `-dir`        the directory to show first.
- `-files`      1 to show files, 0 for directories only (default 1).
- `-showhidden` 1 to show dot-files (default 0).
- `-onactivate` script, appended the entry dict -- double-click / Enter.
- `-onselect`   script, appended the entry dict -- selection change.

## Entry dicts

Callbacks and `selectedEntry` hand back a dict with `name`, `path`, `type`
(`file`/`dir`) and `size`. Feed `path` back to the provider's `get`/`stat` or to
`setDir` for a directory.

## Use

```tcl
package require tkutils::tkufilelist

::tkutils::tkufilelist::widget .list -dir [pwd] \
    -onactivate {apply {e {
        if {[dict get $e type] eq "dir"} {
            ::tkutils::tkufilelist::setDir .list [dict get $e path]
        }
    }}}
pack .list -fill both -expand 1
```

## Filtering

`setFilter` takes a case-insensitive glob applied to file names; directories are
never filtered, so navigation still works while a filter is active. `""` clears
it. The `ctrlutils::cufilter` controller wires a text box to this.

```tcl
::tkutils::tkufilelist::setFilter .list *.txt   ;# only .txt files (plus dirs)
::tkutils::tkufilelist::setFilter .list ""       ;# show everything again
```

## Provider-backed

Because the list is filled through a provider, the same widget shows a local
directory, the contents of a ZIP, or a WebDAV collection -- only the `-provider`
differs.

## See also

`tkufiletree`, `tkupath`, `tclutils::tuprovider`
