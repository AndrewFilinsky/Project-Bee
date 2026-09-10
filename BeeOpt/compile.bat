@echo off

  call clear.bat
  del  temp\BeeOpt.exe
  del  distribution\BeeOpt.exe

echo *** 
echo *** Compile BeeOpt.exe ...
echo *** 

  cd source
  dcc32 BeeOpt.dpr -q -b -h -w -k0x400000
  cd ..

echo *** 
echo *** StripReloc Bee ...
echo *** 

  ..\ThirdParty\StripReloc\StripReloc.exe /B /C distribution\BeeOpt.exe
  ..\ThirdParty\Upx\Upx.exe distribution\BeeOpt.exe

  call clear.bat
  