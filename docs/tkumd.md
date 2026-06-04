# tkutils::tkumd

Markdown outline viewer. Built on `tclutils::tumd`; the document headings are
shown as a nested outline in a ttk::treeview.

## API
```tcl
set w [::tkutils::tkumd::widget .w ?-height N?]
::tkutils::tkumd::setMarkdown  $w markdownText
::tkutils::tkumd::loadFile     $w path
::tkutils::tkumd::getHeadings  $w               ;# list of {level title}
```

## Launcher
```bash
tclsh bin/tkumd.tcl document.md
```
