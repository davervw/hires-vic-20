# Hi-Res BASIC Extensions for Commodore Vic-20 and Demo Program #

I added some commands to Commodore Vic-20 BASIC via software extensions
written in 6502 Assembly.

## WORK IN PROGRESS - CURRENTLY IS JUST SYS COMMANDS ##

Compiling requires [ACME](https://sourceforge.net/projects/acme-crossass/) for use with Microsoft Visual Code.  

Also leverages [Esshahn/acme-assembly-vscode-template](https://github.com/Esshahn/acme-assembly-vscode-template)

Build launches [VICE](http://vice-emu.sourceforge.net/index.html#download) C-64 Emulator so install that too.

And some manual editing of the development system and configuration files is required (e.g. ACME and VICE locations).  See build.sh for use within Visual Code.

Additional work will be required for non-Windows platforms.

[Built D64 disk image for Vic-20 is here](https://github.com/davervw/hires-vic-20/raw/master/build/hires20.d64)

[Related HIRES for C64](https://github.com/davervw/hires-c64)

Usage:

    REM REQUIRES 8K expansion at $2000, and 8K expansion at $A000
    LOAD"LOADER",8 : REM LOAD/INIT HIRES20.ML
    RUN
    LOAD"HIRES28",8 : REM DEMO1

## Demo1 ##

![Demo1](https://github.com/davervw/hires-vic-20/raw/master/doc/media/demo1/video.gif)

    Keys ,.<> change resolution
    Cursor keys adjust screen positioning
    RETURN exits
    (recommend run in Vice warp mode in emulation except for positioning)
