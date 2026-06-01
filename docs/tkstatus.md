# tkutils::tkstatus

A status bar with an expanding main message, optional named fields and an
optional progress bar. Pure Tk.

(The main-text accessors are `setText`/`getText`, not `set`/`get`, so the module
does not shadow the Tcl `set` command.)

## API
```tcl
set st [::tkutils::tkstatus::widget .st]
::tkutils::tkstatus::setText   $st text
::tkutils::tkstatus::getText   $st
::tkutils::tkstatus::addField  $st id ?-width N?
::tkutils::tkstatus::setField  $st id text
::tkutils::tkstatus::fieldText $st id
::tkutils::tkstatus::progress  $st ?value?    ;# 0..100 to show, "" to hide
::tkutils::tkstatus::flash     $st text ?ms?  ;# temporary message, then restore
```

## Launcher
```bash
tclsh bin/tkstatus.tcl
```
