# tkutils — Conventions & Contribution Guide

Rules and templates for adding or updating a tkutils widget. They keep the library
consistent, dual-compatible with Tcl/Tk 8.6 and 9, and a thin GUI layer on top of the
pure-Tcl `tclutils` engine.

## 0. Character and scope

- **tkutils = Tk GUI tools on top of the tclutils engine.** Every widget is a thin
  view/controller; all byte/data/text logic lives in `tclutils` (`tubin`,
  `tuhexdump`, `tucsv`, `tujson`, `tumd`, `tuzip`, ...). Do **not** reimplement engine
  logic in tkutils — reuse tclutils. (The 0.2.0 rebuild of `tkhexedit` did exactly
  this and thereby dropped a `-encoding binary` bug that the duplicated code had
  reintroduced.)
- Requiring `tclutils` pulls in **no** Tk, so `tclutils` stays usable on the
  console/CI. tkutils requires **Tk and tclutils**.

## 1. Language and style

- English everywhere: identifiers, comments, error messages, documentation.
- 4-space indentation; braced expressions (`expr {...}`); braced control bodies.
- Private helpers are prefixed `_` and are not exported.
- Prefer themed `ttk::*` widgets over legacy Tk widgets.

## 2. Tcl/Tk version and portability

- `package require Tcl 8.6-` **and** `package require Tk 8.6-` (open-ended). Bare
  `Tcl 8.6` / `Tk 8.6` FAIL on 9 with a version conflict — verified.
- Binary I/O never uses `-encoding binary` (removed in Tcl 9). Use
  `-encoding iso8859-1` with `-translation binary`, and prefer
  `tclutils::common::readBinaryFile` for reads.
- A standalone launcher must enter the Tk event loop (see §7): `tclsh` does not do
  this automatically.
- Avoid `exec`-ing platform tools inside a widget; keep behaviour portable and
  document any Windows-specific differences.

## 3. Dependency on tclutils — discovery

- Module requires the engine explicitly, e.g. `package require tclutils::tubin 0.1`.
- **Installed systems:** tclutils is on the standard module path, so it just works.
- **Dev / in-tree:** the tests, demo and launcher honour the `TCLUTILS_TM`
  environment variable or auto-discover a sibling `tclutils-*/lib/tm` checkout (see
  the resolver in §11.2). Never hard-code an absolute path.

## 4. Namespace and naming (aligned with tclutils)

The `tk` prefix mirrors tclutils' `tu` prefix. For a widget named `<name>`, keep all
of these aligned:

| Artifact     | Name                                   |
|--------------|----------------------------------------|
| package      | `tkutils::tk<name>`                     |
| module file  | `lib/tm/tkutils/tk<name>-0.1.tm`        |
| namespace    | `::tkutils::tk<name>`                   |
| launcher     | `bin/tk<name>.tcl` (command `tk<name>`) |
| test         | `tests/tk<name>.test`                   |
| doc          | `docs/tk<name>.md`                      |
| man page     | `man/mann/tk<name>.n`                   |
| demo         | `examples/demo-tk<name>.tcl`            |

Module package versions stay `0.1`; the release version is carried by the umbrella
`tkutils-<ver>.tm` (same scheme as tclutils).

## 5. Widget API conventions

- Constructor `::tkutils::tk<name>::widget path ?options?` builds the megawidget
  under `path` (a `ttk::frame`) and returns `path`.
- Operations are namespace procs taking the widget `path` as the first argument
  (`loadFile`, `saveFile`, `setData`, `getData`, ...).
- Per-widget state lives in a namespace `variable state` array keyed by `$path,...`.
- **Bind `<Destroy>` to release state** (guarding `%W eq $path`); otherwise state
  leaks after the widget is destroyed. See §11.1.
- Errors use `return -code error -errorcode {TKUTILS <MOD> <REASON>} "message"`,
  where `<MOD>` is the upper-case widget name (e.g. `TKHEXEDIT`).
- No `global`; all state is per-widget.

## 6. TclOO — where it earns its place

- The traditional path-keyed state-array megawidget (as in `tkhexedit`) is the
  accepted baseline and is fine for small/medium widgets.
- Reach for TclOO (`oo::class`, a widget-adaptor style wrapper) when a widget is
  genuinely stateful/configurable, needs many independent instances with
  encapsulated state and methods, or grows large. Keep it optional; do not OO-ify
  trivial views.

## 7. Launcher (CLI)

- Do the tclutils discovery (§11.2) **before** `package require tkutils::tk<name>`.
- Because `tclsh` does not auto-enter the Tk loop, a standalone launcher must end
  with `vwait forever` (works under both `tclsh` and `wish`).

## 8. Testing & the verification gate

- tcltest with a `haveTk` constraint:
  `if {[catch {package require Tk 8.6-}]} {set haveTk 0}`; widget tests use
  `-constraints haveTk`.
- Run under a virtual display when headless: `xvfb-run -a tclsh tests/all.tcl`.
- **Gate: 0 failures on both Tk 8.6 and Tk 9.x.** Obtain/build Tk 9 to verify (Tk 9
  builds from source against a Tcl 9 install). Tests skip only when no display is
  available — and a skip must never mask a real load failure (do not let a bad
  `package require` silently set `haveTk 0` on a machine that actually has Tk).
- File/binary fixtures are written Tcl-9-safe (`-encoding iso8859-1`); destructive
  tests use temp dirs (`makeDirectory`).

## 9. File layout (target)

```
tkutils/
  lib/tm/tkutils-<ver>.tm            umbrella (requires Tcl 8.6- and the modules)
  lib/tm/tkutils/tk<name>-0.1.tm     module
  bin/tk<name>.tcl                   launcher
  tests/all.tcl  tests/tk<name>.test
  docs/architecture.md  docs/tk<name>.md
  examples/demo-tk<name>.tcl
  man/mann/tk<name>.n
  README.md  CHANGELOG.md  ROADMAP.md  LICENSE  CONVENTIONS.md
```

## 10. Integration checklist (new widget)

1. Umbrella: add `package require tkutils::tk<name> 0.1`; bump
   `package provide tkutils <newver>`.
2. `CHANGELOG.md`: prepend a `## <newver> - <date>` entry.
3. `README.md`: bump the version, list the module + launcher, name the tclutils
   engine(s) it uses.
4. `docs/architecture.md`: add the widget and its backend.
5. man page, doc and demo present and named consistently (§4).

## 11. Templates

### 11.1 Module — `lib/tm/tkutils/tk<name>-0.1.tm`

```tcl
# tkutils::tk<name> -- one-line summary
# Tk front-end on top of the tclutils engine. Tcl/Tk 8.6+ and 9.x compatible.

package require Tcl 8.6-
package require Tk 8.6-
package require tclutils::<engine> 0.1   ;# reuse, do not reimplement

namespace eval ::tkutils {}
namespace eval ::tkutils::tk<name> {
    namespace export widget ;# ... public procs ...
    variable state
}

proc ::tkutils::tk<name>::_cleanup {path w} {
    variable state
    if {$w eq $path} { array unset state $path,* }
}

proc ::tkutils::tk<name>::widget {path args} {
    variable state
    array set opts {-example 0}
    array set opts $args

    ttk::frame $path
    set state($path,data) ""
    bind $path <Destroy> [list ::tkutils::tk<name>::_cleanup $path %W]

    # ... build ttk children under $path ...
    return $path
}

# operations take the widget path as first argument
proc ::tkutils::tk<name>::setData {path data} {
    variable state
    set state($path,data) $data
    # ... refresh view, e.g. via the tclutils engine ...
}

package provide tkutils::tk<name> 0.1
```

### 11.2 tclutils discovery (shared by test, launcher, demo)

```tcl
set tmDir [file normalize [file join $here .. lib tm]]
tcl::tm::path add $tmDir
# locate the tclutils dependency for in-tree/dev use
# (installed systems already have tclutils on the module path)
if {[info exists ::env(TCLUTILS_TM)]} {
    tcl::tm::path add $::env(TCLUTILS_TM)
} else {
    set _tkuRoot [file dirname [file dirname $tmDir]]
    foreach _c [lsort -decreasing \
            [glob -nocomplain [file join [file dirname $_tkuRoot] tclutils*/lib/tm]]] {
        tcl::tm::path add $_c
        break
    }
}
```

### 11.3 Test — `tests/tk<name>.test`

```tcl
package require Tcl 8.6-
package require tcltest
namespace import ::tcltest::*

set haveTk 1
if {[catch {package require Tk 8.6-}]} { set haveTk 0 }
testConstraint haveTk $haveTk

set here [file dirname [file normalize [info script]]]
# ... insert the §11.2 discovery block here ...

if {$haveTk} { package require tkutils::tk<name> }

test tk<name>-1.1 {create widget and set data} -constraints haveTk -body {
    catch {destroy .w}
    set w [::tkutils::tk<name>::widget .w]
    ::tkutils::tk<name>::setData $w ABC
    string length [::tkutils::tk<name>::getData $w]
} -result 3

cleanupTests
```

### 11.4 Launcher — `bin/tk<name>.tcl`

```tcl
#!/usr/bin/env tclsh
set here [file dirname [file normalize [info script]]]
# ... insert the §11.2 discovery block here ...
package require tkutils::tk<name>

wm title . "tk<name>"
set w [::tkutils::tk<name>::widget .w]
pack $w -fill both -expand 1
if {[llength $argv] > 0} { ::tkutils::tk<name>::loadFile $w [lindex $argv 0] }

# enter the Tk event loop when launched as a standalone application
vwait forever
```

### 11.5 Documentation — `docs/tk<name>.md`

```markdown
# tkutils::tk<name>

One-line summary. Built on `tclutils::<engine>`.

## API
\`\`\`tcl
set w [::tkutils::tk<name>::widget .w ?options?]
::tkutils::tk<name>::loadFile $w file
\`\`\`

## Launcher
\`\`\`bash
tclsh bin/tk<name>.tcl file
\`\`\`
```

### 11.6 Man page — `man/mann/tk<name>.n`

```troff
.TH tk<name> n <ver> tkutils "Tcl/Tk Utility Library"
.SH NAME
tkutils::tk<name> \- one-line summary
.SH SYNOPSIS
package require tkutils::tk<name>
.br
set w [::tkutils::tk<name>::widget .w]
.SH DESCRIPTION
...
.SH "SEE ALSO"
tclutils(n)
.SH KEYWORDS
Tk, widget
```
