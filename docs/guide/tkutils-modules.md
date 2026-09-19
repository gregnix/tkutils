| package | version | description | category | test | doc | man | repo | path | deps |
|---|---|---|---|---|---|---|---|---|---|
| `tkutils::tkuaction` | 0.1 | action abstraction (one action, many widgets) | Tk · widgets | Y | Y | Y | tkutils | `lib/tm/tkutils/tkuaction-0.1.tm` |  |
| `tkutils::tkuballoon` | 0.1 | balloon help / tooltips for any widget | Tk · widgets | Y | Y | Y | tkutils | `lib/tm/tkutils/tkuballoon-0.1.tm` |  |
| `tkutils::tkubase64` | 0.1 | Base64 encode/decode panel | Tk · widgets | Y | Y | Y | tkutils | `lib/tm/tkutils/tkubase64-0.1.tm` | tclutils::tubase64 |
| `tkutils::tkubind` | 0.1 | platform key/context bindings (from uitoolkit uibindings) | Tk · widgets | Y | Y | Y | tkutils | `lib/tm/tkutils/tkubind-0.1.tm` |  |
| `tkutils::tkucal` | 0.1 | calendar view | Tk · widgets | Y | Y | Y | tkutils | `lib/tm/tkutils/tkucal-0.1.tm` | tclutils::tucal |
| `tkutils::tkucalc` | 0.2 | a calculator widget with keyboard support | Tk · widgets | Y | Y | N | tkutils | `lib/tm/tkutils/tkucalc-0.2.tm` | tkutils::tkuopts |
| `tkutils::tkucalendar` | 0.2 | a clickable month calendar widget | Tk · widgets | Y | Y | N | tkutils | `lib/tm/tkutils/tkucalendar-0.2.tm` | tkutils::tkuopts |
| `tkutils::tkucanvaspng` | 0.2 | export a live Tk canvas widget to a PNG image, after pdf4tcl's `$pdf canvas` model | Tk · widgets | Y | Y | Y | tkutils | `lib/tm/tkutils/tkucanvaspng-0.2.tm` | tclutils::common,tclutils::tupngdraw,Glyphs |
| `tkutils::tkucontextmenu` | 0.1 | generic right-click context menu (from uitoolkit) | Tk · widgets | Y | Y | Y | tkutils | `lib/tm/tkutils/tkucontextmenu-0.1.tm` |  |
| `tkutils::tkucsv` | 0.1 | CSV table viewer | Tk · widgets | Y | Y | Y | tkutils | `lib/tm/tkutils/tkucsv-0.1.tm` | tclutils::tucsv,tclutils::common |
| `tkutils::tkudateentry` | 0.1 | date entry with a drop-down calendar picker. | Tk · widgets | Y | Y | Y | tkutils | `lib/tm/tkutils/tkudateentry-0.1.tm` |  |
| `tkutils::tkudavaccount` | 0.1 | a DAV account form (URL / user / password / type) with a Test-connection button | Tk · widgets | Y | Y | Y | tkutils | `lib/tm/tkutils/tkudavaccount-0.1.tm` | tclutils::tudav |
| `tkutils::tkudavbrowser` | 0.2 | a read-only navigation pane for a CalDAV/CardDAV server, built on tclutils::tudav. | Tk · widgets | Y | Y | Y | tkutils | `lib/tm/tkutils/tkudavbrowser-0.2.tm` | tkutils::tkuopts,tclutils::tudav,tclutils::common |
| `tkutils::tkudhash` | 0.1 | image-file front end for the perceptual dHash | Tk · widgets | Y | Y | Y | tkutils | `lib/tm/tkutils/tkudhash-0.1.tm` | tclutils::tudhash,Img |
| `tkutils::tkudialog` | 0.2 | dialogs with copyable message text | Tk · widgets | Y | Y | Y | tkutils | `lib/tm/tkutils/tkudialog-0.2.tm` | tkutils::tkuform |
| `tkutils::tkudiff` | 0.1 | line diff viewer | Tk · widgets | Y | Y | Y | tkutils | `lib/tm/tkutils/tkudiff-0.1.tm` | tclutils::tudiff,tclutils::common |
| `tkutils::tkueditor` | 0.2 | text editor widget (v0.2 PROTOTYPE) | Tk · widgets | Y | Y | Y | tkutils | `lib/tm/tkutils/tkueditor-0.2.tm` | tclutils::tuiconv,tkutils::tkuicon,tkutils::tkutoolbar,tkutils::tkustatus |
| `tkutils::tkufilelist` | 0.2 | a detail file list, filled from a storage provider | Tk · widgets | Y | Y | Y | tkutils | `lib/tm/tkutils/tkufilelist-0.2.tm` | tkutils::tkuopts,tkutils::tkutablelist,tclutils::tuprovider |
| `tkutils::tkufiletree` | 0.2 | a lazy file-system tree built on tkutils::tkutree. | Tk · widgets | Y | Y | Y | tkutils | `lib/tm/tkutils/tkufiletree-0.2.tm` | tkutils::tkuopts,tkutils::tkutree |
| `tkutils::tkufilterbar` | 0.2 | a per-column filter bar: one small entry per column, each typing a substring that the consumer ANDs together. | Tk · widgets | Y | Y | Y | tkutils | `lib/tm/tkutils/tkufilterbar-0.2.tm` | tkutils::tkuopts |
| `tkutils::tkuform` | 0.1 | declarative form widget | Tk · widgets | Y | Y | Y | tkutils | `lib/tm/tkutils/tkuform-0.1.tm` |  |
| `tkutils::tkufuzzy` | 0.1 | incremental fuzzy filter | Tk · widgets | Y | Y | Y | tkutils | `lib/tm/tkutils/tkufuzzy-0.1.tm` | tclutils::tufuzzy |
| `tkutils::tkuhexedit` | 0.1 | small Tk hex viewer/editor | Tk · widgets | Y | Y | Y | tkutils | `lib/tm/tkutils/tkuhexedit-0.1.tm` | tclutils::tubin,tclutils::tuhexdump,tclutils::common |
| `tkutils::tkuical` | 0.2 | iCalendar event viewer/editor | Tk · widgets | Y | Y | Y | tkutils | `lib/tm/tkutils/tkuical-0.2.tm` | tkutils::tkuopts,tclutils::tuical |
| `tkutils::tkuicon` | 0.1 | SVG icon loader / generator for toolbars (from uitoolkit) | Tk · widgets | Y | Y | Y | tkutils | `lib/tm/tkutils/tkuicon-0.1.tm` | tksvg,tclutils::tusvg |
| `tkutils::tkuimage` | 0.2 | image helpers and a scrollable/zoomable viewer widget for Tk | Tk · widgets | Y | Y | Y | tkutils | `lib/tm/tkutils/tkuimage-0.2.tm` | imgtools |
| `tkutils::tkuini` | 0.2 | INI viewer | Tk · widgets | Y | Y | Y | tkutils | `lib/tm/tkutils/tkuini-0.2.tm` | tkutils::tkuopts,tclutils::tuini |
| `tkutils::tkujson` | 0.1 | JSON tree viewer | Tk · widgets | Y | Y | Y | tkutils | `lib/tm/tkutils/tkujson-0.1.tm` | tclutils::tujson,tclutils::common |
| `tkutils::tkukeynav` | 0.1 | keyboard focus navigation helpers | Tk · widgets | Y | Y | Y | tkutils | `lib/tm/tkutils/tkukeynav-0.1.tm` |  |
| `tkutils::tkulabeled` | 0.1 | labeled input composites (label + control in one) | Tk · widgets | Y | Y | Y | tkutils | `lib/tm/tkutils/tkulabeled-0.1.tm` |  |
| `tkutils::tkulauncher` | 0.2 | an application launcher widget, as a menu or a list | Tk · widgets | Y | Y | N | tkutils | `lib/tm/tkutils/tkulauncher-0.2.tm` | tkutils::tkuopts,tclutils::tuopen,tkutils::tkuscrolledframe,tkutils::tkuwheel,tkutils::tkuballoon,tclutils::tujson,tclutils::tuini,tkutils::tkutical,tkutils::tkucalendar,tkutils::tkucal,tkutils::tkucalc,tkutils::tkuform |
| `tkutils::tkulayoutcanvas` | 0.1 | visual block layout designer on a Tk canvas | Tk · widgets | Y | Y | Y | tkutils | `lib/tm/tkutils/tkulayoutcanvas-0.1.tm` | tclutils::tulayout |
| `tkutils::tkuldif` | 0.2 | LDIF entry viewer/editor | Tk · widgets | Y | Y | Y | tkutils | `lib/tm/tkutils/tkuldif-0.2.tm` | tkutils::tkuopts,tclutils::tuldif |
| `tkutils::tkuload` | 0.1 | instantiate a tkudesigner `.tkd` layout as a live Tk widget tree (no code export) | Tk · widgets | Y | Y | Y | tkutils | `lib/tm/tkutils/tkuload-0.1.tm` | tkutils::tkurender |
| `tkutils::tkumarquee` | 0.1 | rubber-band (marquee) rectangle selection on a canvas | Tk · widgets | Y | Y | Y | tkutils | `lib/tm/tkutils/tkumarquee-0.1.tm` |  |
| `tkutils::tkumd` | 0.1 | Markdown outline viewer | Tk · widgets | Y | Y | Y | tkutils | `lib/tm/tkutils/tkumd-0.1.tm` | tclutils::tumd,tclutils::common |
| `tkutils::tkumdview` | 0.1 | Markdown viewer (headings outline + rendered preview) | Tk · widgets | Y | Y | Y | tkutils | `lib/tm/tkutils/tkumdview-0.1.tm` | tclutils::tumd |
| `tkutils::tkumonthcanvas` | 0.5 | canvas calendar widget (month/quarter/year) OPTIONAL: requires tical (engine). | Tk · widgets | Y | Y | Y | tkutils | `lib/tm/tkutils/tkumonthcanvas-0.5.tm` | tical::config,tical::locale,tical::holidays,tical::holidays::de,tical::view::month |
| `tkutils::tkunotes` | 0.2 | hierarchical notes widget | Tk · widgets | Y | Y | Y | tkutils | `lib/tm/tkutils/tkunotes-0.2.tm` | tkutils::tkuopts,tclutils::tunotes |
| `tkutils::tkunumentry` | 0.1 | numeric entry with validation, fixed decimals and optional min/max clamping | Tk · widgets | Y | Y | Y | tkutils | `lib/tm/tkutils/tkunumentry-0.1.tm` |  |
| `tkutils::tkuopts` | 0.1 | merge options over defaults; an unknown option is an error that lists the known ones | System · runtime | Y | Y | N | tkutils | `lib/tm/tkutils/tkuopts-0.1.tm` |  |
| `tkutils::tkupath` | 0.2 | a breadcrumb path bar with clickable segments | Tk · widgets | Y | Y | Y | tkutils | `lib/tm/tkutils/tkupath-0.2.tm` | tkutils::tkuopts |
| `tkutils::tkupdfinspect` | 0.1 | PDF structure inspector (read-only) | Tk · widgets | Y | Y | Y | tkutils | `lib/tm/tkutils/tkupdfinspect-0.1.tm` | tclutils::tupdf |
| `tkutils::tkupreview` | 0.1 | a content preview widget, policy-free (the caller picks the kind) | Tk · widgets | Y | Y | Y | tkutils | `lib/tm/tkutils/tkupreview-0.1.tm` | tkutils::tkumdview,tcllitehtml,tkutils::tkucsv,tkutils::tkusqlite,tkutils::tkuimage,tkutils::tkupdfinspect |
| `tkutils::tkurender` | 0.1 | shared render core for tkudesigner / tkuload. | Tk · widgets | Y | Y | Y | tkutils | `lib/tm/tkutils/tkurender-0.1.tm` |  |
| `tkutils::tkuscrolledframe` | 0.1 | scrollable frame container (thin scrollutil wrapper) | Tk · widgets | Y | Y | Y | tkutils | `lib/tm/tkutils/tkuscrolledframe-0.1.tm` | scrollutil |
| `tkutils::tkusearchbar` | 0.1 | a search bar: entry with debounced change callback, a clear button, and an optional filter drop-down. | Tk · widgets | Y | Y | Y | tkutils | `lib/tm/tkutils/tkusearchbar-0.1.tm` |  |
| `tkutils::tkusqlite` | 0.1 | SQLite table browser | Tk · widgets | Y | Y | Y | tkutils | `lib/tm/tkutils/tkusqlite-0.1.tm` | sqlite3 |
| `tkutils::tkustatus` | 0.2 | status bar widget | Tk · widgets | Y | Y | Y | tkutils | `lib/tm/tkutils/tkustatus-0.2.tm` | tkutils::tkuopts |
| `tkutils::tkustrings` | 0.1 | printable strings viewer | Tk · widgets | Y | Y | Y | tkutils | `lib/tm/tkutils/tkustrings-0.1.tm` | tclutils::tustrings |
| `tkutils::tkutab` | 0.2 | a tabbed container with a "+" button and closeable tabs | Tk · widgets | Y | Y | Y | tkutils | `lib/tm/tkutils/tkutab-0.2.tm` | tkutils::tkuopts |
| `tkutils::tkutablelist` | 0.3 | multi-column table (OPTIONAL: requires Tablelist) | Tk · tablelist | Y | Y | Y | tkutils | `lib/tm/tkutils/tkutablelist-0.3.tm` | tkutils::tkuopts,tablelist_tile,Tablelist,tclutils::tunum,tclutils::tucsv,tclutils::tunotes |
| `tkutils::tkutags` | 0.1 | tag editor: tags shown as removable chips plus an input. | Tk · widgets | Y | Y | Y | tkutils | `lib/tm/tkutils/tkutags-0.1.tm` |  |
| `tkutils::tkutical` | 0.3 | month/week calendar widget (OPTIONAL: requires tical) | Tk · widgets | Y | Y | Y | tkutils | `lib/tm/tkutils/tkutical-0.3.tm` | tkutils::tkuopts,tical::view::month,tical::view::week,tical::render::canvas |
| `tkutils::tkutimeentry` | 0.1 | time entry with hour/minute (optional second) spinboxes. | Tk · widgets | Y | Y | Y | tkutils | `lib/tm/tkutils/tkutimeentry-0.1.tm` |  |
| `tkutils::tkutlclip` | 0.1 | copy tablelist rows to the clipboard as TSV or CSV. | Tk · tablelist | Y | Y | Y | tkutils | `lib/tm/tkutils/tkutlclip-0.1.tm` | tablelist,tclutils::tucsv |
| `tkutils::tkutlfind` | 0.1 | incremental find with match highlighting for a tablelist widget. | Tk · tablelist | Y | Y | Y | tkutils | `lib/tm/tkutils/tkutlfind-0.1.tm` | tablelist |
| `tkutils::tkutlfmt` | 0.2 | per-column display formatting for a tablelist widget via tablelist's -formatcommand. | Tk · tablelist | Y | Y | Y | tkutils | `lib/tm/tkutils/tkutlfmt-0.2.tm` | tkutils::tkuopts,tablelist,tclutils::tunum |
| `tkutils::tkutlfooter` | 0.2 | a footer row for a tablelist widget, realised as a second single-row tablelist ("header at the bottom" look). | Tk · tablelist | Y | Y | Y | tkutils | `lib/tm/tkutils/tkutlfooter-0.2.tm` | tablelist,tclutils::tunum |
| `tkutils::tkutlsort` | 0.1 | type-aware column sorting for a tablelist widget. | Tk · tablelist | Y | Y | Y | tkutils | `lib/tm/tkutils/tkutlsort-0.1.tm` | tablelist,tclutils::tunum |
| `tkutils::tkutlstate` | 0.2 | save and restore a tablelist's column layout: widths, hidden state, display order and the active sort. | Tk · tablelist | Y | Y | Y | tkutils | `lib/tm/tkutils/tkutlstate-0.2.tm` | tablelist |
| `tkutils::tkutltools` | 0.1 | umbrella for the tablelist extension family. | Tk · tablelist | Y | Y | Y | tkutils | `lib/tm/tkutils/tkutltools-0.1.tm` | tablelist,tclutils::tunum,tkutils::tkutlsort,tkutils::tkutlfmt,tkutils::tkutlclip,tkutils::tkutlfooter,tkutils::tkutlfind,tkutils::tkutlstate,tkutils::tkutltree |
| `tkutils::tkutltree` | 0.1 | convert between nested data and a tablelist tree, with free column mapping. | Tk · tablelist | Y | Y | Y | tkutils | `lib/tm/tkutils/tkutltree-0.1.tm` | tablelist |
| `tkutils::tkutodo` | 0.2 | a task-list widget for iCalendar VTODO components, built on tclutils::tuical (todos / todoInfo / setProperty). | Tk · widgets | Y | Y | Y | tkutils | `lib/tm/tkutils/tkutodo-0.2.tm` | tkutils::tkuopts,tclutils::tuical |
| `tkutils::tkutoolbar` | 0.2 | toolbar widget (v0.2) | Tk · widgets | Y | Y | Y | tkutils | `lib/tm/tkutils/tkutoolbar-0.2.tm` | tkutils::tkuballoon,tkutils::tkuaction |
| `tkutils::tkutree` | 0.2 | a thin ttk::treeview wrapper for hierarchical data. | Tk · widgets | Y | Y | Y | tkutils | `lib/tm/tkutils/tkutree-0.2.tm` | tkutils::tkuopts |
| `tkutils::tkuvalidate` | 0.1 | inline validation feedback for input widgets | Tk · widgets | Y | Y | Y | tkutils | `lib/tm/tkutils/tkuvalidate-0.1.tm` | tkutils::tkuballoon,tclutils::tuvalidate |
| `tkutils::tkuvcard` | 0.2 | vCard contact viewer | Tk · widgets | Y | Y | Y | tkutils | `lib/tm/tkutils/tkuvcard-0.2.tm` | tkutils::tkuopts,tclutils::tuvcard,tkutils::tkuimage |
| `tkutils::tkuwheel` | 0.2 | forward mouse-wheel events to a scrollable target | Tk · widgets | Y | Y | Y | tkutils | `lib/tm/tkutils/tkuwheel-0.2.tm` |  |
| `tkutils::tkuwinico` | 0.1 | build Windows .ico files from Tk images (SVG or photo), alpha preserved | Tk · widgets | Y | Y | Y | tkutils | `lib/tm/tkutils/tkuwinico-0.1.tm` | tclutils::tuico |
| `tkutils::tkuxml` | 0.1 | XML tree viewer | Tk · widgets | Y | Y | Y | tkutils | `lib/tm/tkutils/tkuxml-0.1.tm` | tdom,tclutils::common |
| `tkutils::tkuzip` | 0.1 | ZIP archive browser | Tk · widgets | Y | Y | Y | tkutils | `lib/tm/tkutils/tkuzip-0.1.tm` | tclutils::tuzip |
