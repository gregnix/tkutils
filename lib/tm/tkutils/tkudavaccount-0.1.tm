# tkutils::tkudavaccount -- a DAV account form (URL / user / password / type)
# Description: a DAV account form (URL / user / password / type) with a Test-connection button
# Category: Tk · widgets
# with a "Test connection" button that runs a PROPFIND through tclutils::tudav
# and reports success or failure. Tcl/Tk 8.6+ and 9.x.
#
# The connection test is synchronous (one PROPFIND); the UI is briefly blocked
# while it runs. getConfig returns a dict {url user password type}.

package require Tcl 8.6-
package require Tk 8.6-
package require tclutils::tudav 0.1

namespace eval ::tkutils {}
namespace eval ::tkutils::tkudavaccount {
    namespace export widget getConfig setConfig clear testConnection focusUrl
    variable state
}

proc ::tkutils::tkudavaccount::_cleanup {path w} {
    variable state
    if {$w eq $path} { array unset state $path,* }
}

# Build the account form under $path.
# Options: -url, -user, -password, -type carddav|caldav|webdav (default carddav),
# -command cmd (called as: cmd ok message  after a test; ok is 1/0).
proc ::tkutils::tkudavaccount::widget {path args} {
    variable state
    array set opts {-url "" -user "" -password "" -type carddav -command ""}
    array set opts $args

    ttk::frame $path
    set state($path,cmd) $opts(-command)
    set ns ::tkutils::tkudavaccount::state
    set state($path,url) $opts(-url)
    set state($path,user) $opts(-user)
    set state($path,password) $opts(-password)
    set state($path,type) $opts(-type)
    set state($path,status) ""
    bind $path <Destroy> [list ::tkutils::tkudavaccount::_cleanup $path %W]

    ttk::label $path.lurl  -text "Server URL:"
    ttk::entry $path.url   -width 40 -textvariable ${ns}($path,url)
    ttk::label $path.luser -text "User:"
    ttk::entry $path.user  -width 24 -textvariable ${ns}($path,user)
    ttk::label $path.lpass -text "Password:"
    ttk::entry $path.pass  -width 24 -show "*" -textvariable ${ns}($path,password)
    ttk::label $path.ltype -text "Type:"
    ttk::combobox $path.type -width 12 -state readonly \
        -values {carddav caldav webdav} -textvariable ${ns}($path,type)

    ttk::button $path.test -text "Test connection" \
        -command [list ::tkutils::tkudavaccount::testConnection $path]
    ttk::label $path.status -textvariable ${ns}($path,status) -anchor w

    grid $path.lurl  $path.url  -sticky w -padx 4 -pady 2
    grid $path.luser $path.user -sticky w -padx 4 -pady 2
    grid $path.lpass $path.pass -sticky w -padx 4 -pady 2
    grid $path.ltype $path.type -sticky w -padx 4 -pady 2
    grid $path.test  -row 4 -column 1 -sticky w -padx 4 -pady {6 2}
    grid $path.status -row 5 -column 0 -columnspan 2 -sticky ew -padx 4 -pady {0 4}
    grid columnconfigure $path 1 -weight 1
    return $path
}

# --- public API ----------------------------------------------------------

proc ::tkutils::tkudavaccount::getConfig {path} {
    variable state
    return [dict create \
        url      $state($path,url) \
        user     $state($path,user) \
        password $state($path,password) \
        type     $state($path,type)]
}

proc ::tkutils::tkudavaccount::setConfig {path cfg} {
    variable state
    foreach k {url user password type} {
        if {[dict exists $cfg $k]} { set state($path,$k) [dict get $cfg $k] }
    }
    return [getConfig $path]
}

proc ::tkutils::tkudavaccount::clear {path} {
    variable state
    set state($path,url) ""
    set state($path,user) ""
    set state($path,password) ""
    set state($path,status) ""
    return
}

proc ::tkutils::tkudavaccount::focusUrl {path} { focus $path.url; return $path.url }

# Run a PROPFIND (depth 0) against the configured URL and report the result.
# Returns 1 on success, 0 on failure; also fires -command and updates status.
proc ::tkutils::tkudavaccount::testConnection {path} {
    variable state
    if {$state($path,url) eq ""} {
        _result $path 0 "no URL"
        return 0
    }
    set state($path,status) "Testing\u2026"
    catch {update idletasks}
    set cfg [getConfig $path]
    set rc [catch {
        set c [::tclutils::tudav::client [dict get $cfg url] \
            -user [dict get $cfg user] -password [dict get $cfg password]]
        ::tclutils::tudav::propfind $c -depth 0
        ::tclutils::tudav::destroy $c
    } err]
    if {$rc == 0} {
        _result $path 1 ""
        return 1
    }
    catch {::tclutils::tudav::destroy $c}
    _result $path 0 $err
    return 0
}

# --- internals -----------------------------------------------------------

proc ::tkutils::tkudavaccount::_result {path ok message} {
    variable state
    if {$ok} {
        set state($path,status) "\u2713 Connected"
    } else {
        set state($path,status) "\u2717 $message"
    }
    if {$state($path,cmd) ne ""} {
        uplevel #0 [linsert $state($path,cmd) end $ok $message]
    }
}

package provide tkutils::tkudavaccount 0.1
