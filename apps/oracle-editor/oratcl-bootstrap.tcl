# oratcl-bootstrap.tcl -- locate the Oracle Instant Client and prepare the
# environment BEFORE `package require Oratcl` runs. This belongs in the launcher,
# not in the backend (be-oracle.tcl assumes Oratcl is loadable).
#
# Fallstricke, die dieses Modul kapselt (siehe Handbuch, Kapitel 8):
#   1. Oratcl ist nur eine Huelle ueber libclntsh.so (Linux) / oci.dll (Windows);
#      diese Client-Bibliothek muss gefunden werden -- ueber ORACLE_LIBRARY
#      (Linux) oder den PATH (Windows).
#   2. Windows: oci.dll braucht die MS VC++ Redistributable (VS2013). Fehlt sie,
#      scheitert der DLL-Load mit "error 126".
#   3. NLS_LANG muss zum Server-Charset passen, sonst falsche Umlaute.
#   4. Explizit gesetzte ORACLE_LIBRARY/NLS_LANG haben Vorrang und werden hier
#      NICHT ueberschrieben.
#   5. Linux: der Instant Client braucht libaio. Fehlt libaio.so.1, hilft ein
#      Symlink, z.B.:
#        sudo ln -s /lib/x86_64-linux-gnu/libaio.so.1t64 \
#                   /lib/x86_64-linux-gnu/libaio.so.1

package require Tcl 8.6-

namespace eval ::sqledit::oratcl {
    # Known Instant-Client locations, most-recent first. Extend as needed.
    variable unixDirs {
        /opt/oracle/instantclient_19_25
        /opt/oracle/instantclient_21_13
        /opt/oracle/instantclient_12_2
    }
    variable winDirs {
        {C:\app\instantclient_19_25}
        {C:\app\instantclient_12_2-64}
    }
}

# Return the first existing Instant-Client directory for this platform, or "".
# Read-only: touches nothing.
proc ::sqledit::oratcl::detectInstantClient {} {
    variable unixDirs
    variable winDirs
    if {$::tcl_platform(platform) eq "windows"} {
        foreach d $winDirs { if {[file isdirectory $d]} { return $d } }
    } else {
        foreach d $unixDirs { if {[file isdirectory $d]} { return $d } }
        # also try a glob for other versions under /opt/oracle
        foreach d [lsort -decreasing [glob -nocomplain /opt/oracle/instantclient_*]] {
            if {[file isdirectory $d]} { return $d }
        }
    }
    return ""
}

# A sensible platform default for NLS_LANG. The character set half follows the
# handbook (AL32UTF8 on Linux/macOS, WE8MSWIN1252 on Windows); adjust the
# language/territory to your locale, or set NLS_LANG yourself to override.
proc ::sqledit::oratcl::defaultNlsLang {} {
    if {$::tcl_platform(platform) eq "windows"} {
        return "GERMAN_GERMANY.WE8MSWIN1252"
    }
    return "GERMAN_GERMANY.AL32UTF8"
}

# Prepare the environment for loading Oratcl. Explicitly-set values win and are
# never overwritten. Returns the Instant-Client dir that was used (or "").
proc ::sqledit::oratcl::setupEnv {{clientDir ""}} {
    if {$clientDir eq ""} { set clientDir [detectInstantClient] }

    if {![info exists ::env(NLS_LANG)] || $::env(NLS_LANG) eq ""} {
        set ::env(NLS_LANG) [defaultNlsLang]
    }

    if {$clientDir eq ""} { return "" }

    if {$::tcl_platform(platform) eq "windows"} {
        # oci.dll resolves its own dependencies from PATH.
        set sep ";"
        if {![string match "*[file nativename $clientDir]*" $::env(PATH)]} {
            set ::env(PATH) "[file nativename $clientDir]$sep$::env(PATH)"
        }
    } else {
        if {![info exists ::env(ORACLE_LIBRARY)] || $::env(ORACLE_LIBRARY) eq ""} {
            set lib [file join $clientDir "libclntsh[info sharedlibextension]"]
            set ::env(ORACLE_LIBRARY) $lib
        }
    }
    return $clientDir
}

# Diagnostic dump as a list of "key: value" lines. Safe to call before or after
# Oratcl is loaded; the orainfo section is included only if Oratcl is loaded.
# `orainfo version` / `orainfo client` need no handle; server/status need one.
proc ::sqledit::oratcl::diagInfo {{lh ""}} {
    set out {}
    lappend out "platform: $::tcl_platform(platform) ($::tcl_platform(os))"
    lappend out "tcl: [info patchlevel]   encoding: [encoding system]"
    lappend out "pointerSize: $::tcl_platform(pointerSize) (8 = 64-bit)"
    foreach v {ORACLE_LIBRARY ORACLE_HOME LD_LIBRARY_PATH TNS_ADMIN NLS_LANG ORACLE_SID} {
        lappend out "$v: [expr {[info exists ::env($v)] ? $::env($v) : "(unset)"}]"
    }
    if {[llength [info commands orainfo]]} {
        catch { lappend out "oratcl version: [orainfo version]" }
        catch { lappend out "oracle client: [orainfo client]" }
        if {$lh ne ""} {
            catch { lappend out "server: [orainfo server $lh]" }
            catch { lappend out "status: [orainfo status $lh]" }
        }
    }
    return $out
}
