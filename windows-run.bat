@echo off

set PATH=/bin;%PATH%

rem Bootstrap busybox and cygwin.
.\bin\busybox bash "bin/bootstrap.sh"

rem Start in new shell to avoid 'Terminate batch job?' question.
.\bin\mintty --title "%*" %*
