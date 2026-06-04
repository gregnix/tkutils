# tkutils::tkustatus

A status bar with an expanding main message, optional named fields and an
optional progress bar. Pure Tk.

(The main-text accessors are `setText`/`getText`, not `set`/`get`, so the module
does not shadow the Tcl `set` command.)

## API
```tcl
set st [::tkutils::tkustatus::widget .st]
::tkutils::tkustatus::setText   $st text
::tkutils::tkustatus::getText   $st
::tkutils::tkustatus::addField  $st id ?-width N?
::tkutils::tkustatus::setField  $st id text
::tkutils::tkustatus::fieldText $st id
::tkutils::tkustatus::progress  $st ?value?    ;# 0..100 to show, "" to hide
::tkutils::tkustatus::flash     $st text ?ms?  ;# temporary message, then restore
```

## Launcher
```bash
tclsh bin/tkustatus.tcl
```
