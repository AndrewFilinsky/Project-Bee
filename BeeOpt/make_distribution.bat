@echo off

echo * Create BeeOpt distribution ...
echo * (

call clear.bat

echo *   Delete old files ...

if exist distribution\*.exe del distribution\*.exe
if exist distribution\*.txt del distribution\*.txt

echo *   Copy documentation ...

copy doc\About.txt distribution\About.txt >nul
copy doc\License.txt distribution\License.txt >nul
copy doc\Manual.txt distribution\Manual.txt >nul
copy WhatsNew.txt distribution\WhatsNew.txt >nul

echo *   Compile source ...

call compile.bat

echo * )
