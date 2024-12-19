nasm -fobj -o main.obj main.asm && ^
nasm -fobj -o window.obj window.asm && ^
alink.exe -subsys console -oPE main.obj window.obj && ^
main.exe

@echo off
del *.obj
@REM del main.exe

@REM normally, you would use the commands below, but since there is a bug in nasm, we have to trick it
@REM by using the -fobj flag instead of -fwin32, and need a less restrictive linker than gcc (alink)
@REM however, the asm syntax is also a tiny bit different

@REM nasm -fwin32 -o main.obj main.asm && ^
@REM gcc -m32 -o main main.obj