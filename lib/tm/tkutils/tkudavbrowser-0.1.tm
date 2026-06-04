# tkutils::tkudavbrowser -- a read-only navigation pane for a CalDAV/CardDAV
# server, built on tclutils::tudav. It shows the server's collections grouped by
# kind (Calendars / Address Books / Other) in a ttk::treeview; selecting a
# collection fires the -oncollection callback so an app can load its contents
# into tkuvcard / tkutodo / tkuical.
#
#   set b [tkudavbrowser::widget .b -oncollection {apply {{w info} {
#       puts "selected [dict get $info kind]: [dict get $info href]"
#   }}}]
#   pack $b -fill both -expand 1
#   tkudavbrowser::setClient .b $davClient
#   tkudavbrowser::refresh .b            ;# discover + listCollections (network!)
#
# refresh performs synchronous HTTP via tudav and may block briefly; for offline
# rendering or testing, setData accepts a ready list of {href displayname kind}.

package require Tcl 8.6-
package require Tk 8.6-
package require tclutils::tudav 0.1
package require tclutils::common 0.1

namespace eval ::tkutils {}
namespace eval ::tkutils::tkudavbrowser {
    namespace export widget treeWidget setClient refresh setData collections \
        selected createCalendar createAddressbook deleteCollection
    variable state
    array set state {}
    variable version 0.1
}

proc ::tkutils::tkudavbrowser::widget {path args} {
    variable state
    array set o {-oncollection "" -editable 0}
    array set o $args
    ttk::frame $path
    set state($path,client) ""
    set state($path,oncollection) $o(-oncollection)
    set state($path,editable) $o(-editable)
    set state($path,collections) {}
    set state($path,disc) {}
    set state($path,cur) {}
    set state($path,ename) ""
    bind $path <Destroy> [list ::tkutils::tkudavbrowser::_cleanup $path %W]

    set tv $path.tv
    ttk::treeview $tv -columns {kind} -yscrollcommand [list $path.ys set]
    $tv heading #0   -text "Collection"
    $tv heading kind -text "Kind"
    $tv column #0   -width 240 -anchor w
    $tv column kind -width 110 -anchor w
    $tv tag configure group -foreground "#1a4f8b"
    ttk::scrollbar $path.ys -orient vertical -command [list $tv yview]
    grid $tv      -row 0 -column 0 -sticky nsew
    grid $path.ys -row 0 -column 1 -sticky ns
    grid rowconfigure $path 0 -weight 1
    grid columnconfigure $path 0 -weight 1

    bind $tv <<TreeviewSelect>> [list ::tkutils::tkudavbrowser::_onSelect $path]

    if {$state($path,editable)} {
        set bb $path.bb
        ttk::frame $bb
        ttk::label $bb.nl -text "Name:"
        ttk::entry $bb.ne -width 16 -textvariable ::tkutils::tkudavbrowser::state($path,ename)
        ttk::button $bb.nc -text "New calendar" \
            -command [list ::tkutils::tkudavbrowser::_uiCreate $path calendar]
        ttk::button $bb.na -text "New address book" \
            -command [list ::tkutils::tkudavbrowser::_uiCreate $path addressbook]
        ttk::button $bb.del -text "Delete" \
            -command [list ::tkutils::tkudavbrowser::deleteCollection $path]
        pack $bb.nl $bb.ne $bb.nc $bb.na $bb.del -side left -padx 2 -pady 3
        grid $bb - -row 1 -column 0 -columnspan 2 -sticky ew
    }
    return $path
}

proc ::tkutils::tkudavbrowser::treeWidget {path} { return $path.tv }

proc ::tkutils::tkudavbrowser::setClient {path client} {
    variable state
    set state($path,client) $client
    return $path
}

# Fetch collections from the server (discover + listCollections of both home
# sets) and render them. Network; requires a client. Returns the collection count.
proc ::tkutils::tkudavbrowser::refresh {path args} {
    variable state
    set client $state($path,client)
    if {$client eq ""} {
        return -code error -errorcode {TKUTILS TKDAVBROWSER NOCLIENT} \
            "no DAV client set; call setClient first"
    }
    set opts [::tclutils::common::parseOptions {-path ""} {*}$args]
    set disc [::tclutils::tudav::discover $client -path [dict get $opts -path]]
    set state($path,disc) $disc
    set all {}
    set seen {}
    foreach key {calendarHome addressbookHome} {
        set home [dict get $disc $key]
        if {$home eq ""} continue
        foreach col [::tclutils::tudav::listCollections $client -path $home] {
            set href [dict get $col href]
            if {[dict exists $seen $href]} continue
            dict set seen $href 1
            lappend all $col
        }
    }
    return [setData $path $all]
}

# Render a ready list of collections (each a dict with href/displayname/kind).
# No network -- usable offline and in tests. Returns the collection count.
proc ::tkutils::tkudavbrowser::setData {path cols} {
    variable state
    set state($path,collections) $cols
    set state($path,cur) {}
    set tv $path.tv
    $tv delete [$tv children {}]
    foreach k [array names state $path,info,*] { unset state($k) }

    set groups {calendar "Calendars" addressbook "Address Books" other "Other"}
    array set gnode {}
    # bucket collections by kind, preserving order
    foreach col $cols {
        set kind [dict get $col kind]
        switch -- $kind {
            calendar    { set g calendar }
            addressbook { set g addressbook }
            default     { set g other }
        }
        if {![info exists gnode($g)]} {
            set glabel [dict get $groups $g]
            set gnode($g) [$tv insert {} end -text $glabel -open 1 -tags group]
        }
        set name [dict get $col displayname]
        if {$name eq ""} { set name [_leaf [dict get $col href]] }
        set item [$tv insert $gnode($g) end -text $name -values [list $kind]]
        set state($path,info,$item) $col
    }
    return [llength $cols]
}

proc ::tkutils::tkudavbrowser::collections {path} {
    variable state
    return $state($path,collections)
}

# The currently selected collection dict {href displayname kind}, or {}.
proc ::tkutils::tkudavbrowser::selected {path} {
    variable state
    return $state($path,cur)
}

proc ::tkutils::tkudavbrowser::_leaf {href} {
    set t [string trimright $href /]
    return [lindex [split $t /] end]
}

proc ::tkutils::tkudavbrowser::_onSelect {path} {
    variable state
    set item [lindex [$path.tv selection] 0]
    if {$item eq "" || ![info exists state($path,info,$item)]} {
        set state($path,cur) {}
        return
    }
    set info $state($path,info,$item)
    set state($path,cur) $info
    if {$state($path,oncollection) ne ""} {
        uplevel #0 [list {*}$state($path,oncollection) $path $info]
    }
}

proc ::tkutils::tkudavbrowser::_cleanup {path w} {
    variable state
    if {$w eq $path} { array unset state $path,* }
}

# --- provisioning (opt-in; network) ------------------------------------
proc ::tkutils::tkudavbrowser::_slug {name} {
    set s [string tolower [string trim $name]]
    regsub -all {[^a-z0-9]+} $s "-" s
    set s [string trim $s "-"]
    if {$s eq ""} { set s "col-[clock milliseconds]" }
    return $s
}

proc ::tkutils::tkudavbrowser::_homeFor {path kind} {
    variable state
    set key [expr {$kind eq "addressbook" ? "addressbookHome" : "calendarHome"}]
    if {![dict exists $state($path,disc) $key]} { return "" }
    return [dict get $state($path,disc) $key]
}

proc ::tkutils::tkudavbrowser::_requireClient {path} {
    variable state
    if {$state($path,client) eq ""} {
        return -code error -errorcode {TKUTILS TKDAVBROWSER NOCLIENT} \
            "no DAV client set; call setClient first"
    }
    return $state($path,client)
}

# Create a calendar/address book under the discovered home set; then refresh.
# Returns the new collection path.
proc ::tkutils::tkudavbrowser::createCalendar {path displayname} {
    return [_create $path calendar $displayname]
}
proc ::tkutils::tkudavbrowser::createAddressbook {path displayname} {
    return [_create $path addressbook $displayname]
}
proc ::tkutils::tkudavbrowser::_create {path kind displayname} {
    variable state
    set client [_requireClient $path]
    set home [_homeFor $path $kind]
    if {$home eq ""} {
        return -code error -errorcode {TKUTILS TKDAVBROWSER NOHOME} \
            "no home set known; call refresh first"
    }
    set newpath "[string trimright $home /]/[_slug $displayname]/"
    if {$kind eq "addressbook"} {
        ::tclutils::tudav::mkAddressbook $client $newpath -displayname $displayname
    } else {
        ::tclutils::tudav::mkCalendar $client $newpath -displayname $displayname
    }
    refresh $path
    return $newpath
}

# Delete the selected collection (or the one at $href); then refresh.
proc ::tkutils::tkudavbrowser::deleteCollection {path {href ""}} {
    variable state
    set client [_requireClient $path]
    if {$href eq ""} {
        if {![dict exists $state($path,cur) href]} { return }
        set href [dict get $state($path,cur) href]
    }
    ::tclutils::tudav::delete $client $href
    refresh $path
    return $href
}

proc ::tkutils::tkudavbrowser::_uiCreate {path kind} {
    variable state
    set name [string trim $state($path,ename)]
    if {$name eq ""} { return }
    _create $path $kind $name
    set state($path,ename) ""
}

package provide tkutils::tkudavbrowser 0.1
