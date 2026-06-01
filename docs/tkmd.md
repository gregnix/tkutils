# tkutils::tkmd

Markdown outline viewer. Built on `tclutils::tumd`; the document headings are
shown as a nested outline in a ttk::treeview.

## API
```tcl
set w [::tkutils::tkmd::widget .w ?-height N?]
::tkutils::tkmd::setMarkdown  $w markdownText
::tkutils::tkmd::loadFile     $w path
::tkutils::tkmd::getHeadings  $w               ;# list of {level title}
```

## Launcher
```bash
tclsh bin/tkmd.tcl document.md
```
