@echo off

echo ***
echo *** Deleting temporary files ...
echo ***

  del *.~*  /S >nul
  del *.dcu /S >nul
  del *.drc /S >nul
  del *.dsm /S >nul
  del *.obj /S >nul
  rem del *.map /S >nul
  del *.$$$ /S >nul
  rem del *.bee /S >nul
  del *.ppu /S >nul
  del *.o   /S >nul
  del *.a   /S >nul
  del *.bak /S >nul
