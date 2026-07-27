# tkutils::tkutab

A tabbed container with the conveniences a file manager needs that a bare
`ttk::notebook` lacks: a "+" new-tab button and closeable tabs (middle-click, or
a close call from the caller). Each tab is a frame the caller fills with its own
content. Tk 8.6+ and 9.x.

## API

```tcl
::tkutils::tkutab::widget   path ?options?
::tkutils::tkutab::add      path label      ;# add a tab, returns its content frame
::tkutils::tkutab::close    path frame      ;# close the tab holding frame
::tkutils::tkutab::current  path            ;# content frame of the active tab
::tkutils::tkutab::setLabel path frame label
::tkutils::tkutab::tabs     path            ;# list of content frames, in order
::tkutils::tkutab::count    path            ;# number of open tabs
```

## Options

- `-onnew`    script -- run when the "+" button is pressed (typically calls `add`).
- `-onclose`  script, appended the closing frame -- run when a tab is closed.
- `-onselect` script, appended the selected frame -- run when the active tab changes.

## Use

```tcl
package require tkutils::tkutab

::tkutils::tkutab::widget .tabs \
    -onnew    {apply {{} {newTab}}} \
    -onselect {apply {f {puts "now on $f"}}}
pack .tabs -fill both -expand 1

proc newTab {} {
    set f [::tkutils::tkutab::add .tabs "untitled"]
    # fill $f with this tab's content
    ttk::label $f.l -text "content of [::tkutils::tkutab::count .tabs]"
    pack $f.l
}
newTab
```

`add` returns the content frame; put the tab's widgets inside it. `current`
gives the active tab's frame, so per-tab state can be keyed by frame path. A tab
is closed with middle-click or by calling `close`; `-onclose` fires so the
caller can release that tab's resources.

## See also

`tkufilelist`, `tkufiletree`, `tkupath`
