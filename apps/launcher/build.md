# Windows-GUI-Basekit besorgen (BAWT oder magicsplat), z.B.:
#   zipkit-9_0_4-win64-intel-tk.exe   (GUI, ohne Konsolenfenster)

cd tclutils/apps/build-app
wish9.0 build-app.tcl \
  -kind gui -out tkulauncher.exe \
  -basekit ../../../runtimes/zipkit-9_0_4-win64-intel-tk.exe \
  -app ../../../tkutils/apps/launcher -main launcher.tcl \
  -launch '::launcherapp::main $argv' \
  -tm ../../lib/tm -tm ../../../tkutils/lib/tm \
  -extlib /media/localnet/datenall/tcltk/lib9/ \
  -probe 0