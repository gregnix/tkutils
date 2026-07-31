# tkutils::tkucalc

A small desktop calculator widget: a display plus a button grid, with keyboard
support. A namespaced, reusable replacement for ad-hoc global-variable
calculator scripts. Pure Tk + `expr`; nothing external. Tk 8.6+ and 9.x.

## API

```tcl
::tkutils::tkucalc::widget   path ?-onresult script?
::tkutils::tkucalc::evaluate text     ;# the arithmetic core (no GUI)
::tkutils::tkucalc::clear    path     ;# clear the display
::tkutils::tkucalc::getHistory   path ;# past "expr = result" lines
::tkutils::tkucalc::clearHistory path ;# forget the history
```

- `-onresult` if given, is appended the result string after each successful `=`.
- `-history` show a history panel (a listbox of past "expr = result" lines);
  double-click or Return on a line loads its result back into the display.

## The arithmetic core

`evaluate` turns a display expression into a number, independent of the GUI, so
it is easy to test and reuse:

```tcl
::tkutils::tkucalc::evaluate "2+3*4"    ;# -> 14
::tkutils::tkucalc::evaluate "10/4"     ;# -> 2.5   (division is floating-point)
::tkutils::tkucalc::evaluate "2^10"     ;# -> 1024  (^ is power)
::tkutils::tkucalc::evaluate "3,5 + 1"  ;# -> 4.5   (German decimal comma)
::tkutils::tkucalc::evaluate "7 % 3"    ;# -> 1     (modulo)
```

It accepts the on-screen math symbols (x, /, -) and the German decimal comma,
allows only a whitelist of characters (digits, `+ - * / ( ) . ^ %`, exponent
`e`), and evaluates in a **safe interpreter** -- so a hand-typed expression can
never run commands or touch the file system. Division uses floating point
(`10/4` is `2.5`, not integer `2`), whole results drop a trailing `.0`, and
division by zero, letters, brackets, or variable references raise an error.

## Widget

```tcl
package require tkutils::tkucalc
::tkutils::tkucalc::widget .calc
pack .calc
```

Buttons: digits `0`-`9`, `.`, operators `+ - x /`, parentheses, `C` (clear),
`<` (backspace) and `=` (evaluate). **Keyboard** works throughout: the display
is a normal entry, so type digits, operators and parentheses directly; Enter
evaluates, Escape clears, BackSpace deletes. Buttons do not steal keyboard focus,
so you can freely mix clicking and typing. A bad expression shows `Error` instead
of crashing.

With `-history 1` a panel below the keypad lists past calculations; double-click
a line to reuse its result:

```tcl
::tkutils::tkucalc::widget .calc -history 1
```

```tcl
# feed each result somewhere:
::tkutils::tkucalc::widget .calc -onresult {apply {{r} {puts "= $r"}}}
```

## See also

`tkunumentry`, `tkuvalidate`
