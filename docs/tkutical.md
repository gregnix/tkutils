# tkutils::tkutical  (optional widget)

Month calendar widget that wraps the **tical** library. OPTIONAL: not in the
tkutils umbrella; require it directly once `tical` is on the module path
(`tical::view::month` + `tical::render::canvas`).

## API
    set w [::tkutils::tkutical::widget .w ?-year Y? ?-month M? \
            ?-weeknumbers 0|1? ?-fontsize N? ?-holidays REGION? \
            ?-selectmode none|single|multiple? ?-command CMD?]
    ::tkutils::tkutical::setMonth   $w year month     ;# -> {y m}; throws on bad month
    ::tkutils::tkutical::getMonth   $w                ;# -> {y m}
    ::tkutils::tkutical::next       $w
    ::tkutils::tkutical::prev       $w
    ::tkutils::tkutical::today      $w
    ::tkutils::tkutical::refresh    $w
    ::tkutils::tkutical::selectMode $w none|single|multiple
    ::tkutils::tkutical::getSelection   $w            ;# -> sorted ISO dates
    ::tkutils::tkutical::setSelection   $w {dates / A..B ranges}
    ::tkutils::tkutical::clearSelection $w
    ::tkutils::tkutical::canvasWidget   $w            ;# underlying canvas
    ::tkutils::tkutical::setView    $w month|week     ;# switch view; throws on bad view
    ::tkutils::tkutical::getView    $w                ;# -> month|week
    ::tkutils::tkutical::setDate    $w iso            ;# set the focused date (YYYY-MM-DD)
    ::tkutils::tkutical::getDate    $w                ;# -> focused ISO date

`-command CMD` is called as `CMD $w $selection` on selection changes (selection
modes only). Default `-selectmode single`. Errorcodes: `{TKUTILS TKUTICAL MONTH}`,
`{TKUTILS TKUTICAL SELECTMODE}`, `{TKUTILS TKUTICAL VIEW}`, `{TKUTILS TKUTICAL DATE}`.

## Install / run
- Drop `lib/tm/tkutils/tkutical-0.1.tm` into the tkutils tree (do NOT add it to
  the umbrella -- it is optional, like tkutablelist/tkusqlite).
- Add the optional-widgets row already prepared in README.md.
- Launcher: `bin/tkutical.tcl` (set `TICAL_DIR=/path/to/tical` or keep tical as a
  sibling repo). e.g.  `TICAL_DIR=.../tical wish bin/tkutical.tcl 2025 10`

## Verification
- tkutical.test: 8/8 on Tcl/Tk 9.0 (Xvfb).
- With tical (or Tk) absent the suite SKIPS via the `tical` constraint
  (8 skipped, 0 failed) -- never breaks the tkutils runner, which already runs
  each test in its own process.
