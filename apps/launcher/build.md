# Windows-GUI-Basekit besorgen (BAWT oder magicsplat), z.B.:

> Current build-app (Tcl/Tk 9 only): `-launch` is not needed -- the program
> starts the app through its own argv0 guard; the SQL editors bring their
> shared code from `_lib/sqledit` themselves (no `-include`); the prober
> looks in the Tcl running build-app when `-extlib` is missing. See
> `build-app-README.md` (tclutils/apps/build-app/doc).
#   zipkit-9_0_4-win64-intel-tk.exe   (GUI, ohne Konsolenfenster)

cd tclutils/apps/build-app
wish9.0 build-app.tcl \
  -kind gui -out tkulauncher.exe \
  -basekit ../../../runtimes/zipkit-9_0_4-win64-intel-tk.exe \
  -app ../../../tkutils/apps/launcher -main launcher.tcl \
  -tm ../../lib/tm -tm ../../../tkutils/lib/tm \
  -extlib /path/to/tklib/modules \
  -probe 0