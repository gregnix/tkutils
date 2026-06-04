# tkutils::tkdavaccount

A DAV account form: fields for server URL, user, password and type
(carddav/caldav/webdav), plus a **Test connection** button that runs a PROPFIND
through `tclutils::tudav` and reports success or failure in a status line.

The test is synchronous (one PROPFIND); the UI is briefly blocked while it runs.

## API

```tcl
set a [::tkutils::tkdavaccount::widget .a -type carddav \
        -command {apply {{ok msg} {puts [expr {$ok ? "connected" : $msg}]}}}]
::tkutils::tkdavaccount::setConfig $a {url https://h/c/ user alice password pw}
::tkutils::tkdavaccount::testConnection $a      ;# 1 on success, 0 on failure
```

Commands:

- `widget path ?-url? ?-user? ?-password? ?-type? ?-command cmd?`
- `getConfig path` → dict `{url user password type}` ; `setConfig path dict`
- `clear path` ; `focusUrl path`
- `testConnection path` — runs the PROPFIND; returns 1/0, updates the status
  line, and calls `-command ok message`.

Requires `tclutils::tudav` (https pulls in the `tls` package on first use).
