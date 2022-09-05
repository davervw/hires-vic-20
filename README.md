# Hi-Res BASIC Extensions for Commodore Vic-20 #

I added commands to Commodore Vic-20 BASIC via software extensions
written in 6502 Assembly.  This is an original work leveraging my [HIRES for C64](https://github.com/davervw/hires-c64). (_Work in progress, nearing Alpha functionality_)

### Command syntax ###
_(work in progress, subject to change)_

    COLOR [foreground[+8][,[background][,[border][,[auxillary][,inverse]]]]]
    COLOR [fg[+8]] @ x1,y1 [TO x2,y2]
    TEXT
    HIRES xresolution, yresolution
    DELAY jiffies
    PLOT x, y
    PLOT [@ x,y][TO x,y]...
    PLOT COLOR ON|OFF
    RECT x1,y1, x2,y2 [,0|1|2|3|255]
    SHAPE GET|PUT|OR|XOR|AND|NOT address, x1, y1, x2, y2

<details>
<summary>SYS syntax</summary>

This syntax provides more complete access to low level features (especially until BASIC syntax implemented)

    SYS 40960, xres, yres : REM switch to graphics at resolution, may zero one axis, result in .X, .Y
    ; specify both zeros to switch back to text
    POKE 780, n1:POKE 781, n2:SYS 40963 : REM multiply .A and .X (shift/add method), result in .A(low),.X(high)
    POKE 780,781,782...:SYS 40966 : REM divide 16-bit(.A,.X) by .Y, result in .A(low), .X(high)
    SYS 40969 : REM get division remainder, result in .A(low), .X(high)
    SYS 40972, x, y : REM plot point on screen
    SYS 40975, x, y : REM erase point from screen
    SYS 40978 : REM get resolution in .X, .Y (781, 782)
    SYS 40981, x, y, "string" : REM draw text on graphics screen
    SYS 40984, fg[+8], bg, bd, alt, inverse : REM set VIC color registers and inverse flag, supports multicolor
    SYS 40987, x, y, color : REM multicolor plot/unplot
    SYS 40990, byte : REM fill hires graphics screen memory with byte value
    SYS 40993, color : REM set color used plotting points/lines (or 255 to reset)
    SYS 40996, x1, y1, x2, y2 [,color] : REM draw(/erase color 255) hires line, or multicolor line (color 0-3)
    SYS 40999, x1, y1, x2, y2 [,color] : REM draw/erase rectangle (multicolor 0-3, erase hires 255)
    SYS 41002, x1, y1, x2, y2, fg : REM set foreground color of hires 8x16 tiles
    SYS 41005, x1, y1, x2, y2, fg : REM set foreground color of text screen characters
    SYS 41008, jiffies : REM delay for a multiple of 1/60 of a second
    SYS 41011, x1, y1, x2, y2, op : REM shape operation GET(0), PUT(1), OR(2), XOR(3), AND(4), NOT(5)
    SYS 41014 : REM initialize package including BASIC vectors for list, crunch, execute, error
</details>

</br>

![Demo1 resizing](https://github.com/davervw/hires-vic-20/raw/master/doc/media/demo1/video.gif)
<details>
<summary>Demo1 resizing Notes</summary>

    Keys ,.<> change resolution
    Cursor keys adjust screen positioning
    RETURN exits
    (recommend run in Vice warp mode in emulation except for positioning)

</details>

</br>

![Demo2 shapes or blit](https://github.com/davervw/hires-vic-20/raw/master/doc/media/demo2/video2.gif)

4UPART (demo2)

<details>
<summary>Usage</summary>

    REM REQUIRES 8K expansion at $2000, and 8K expansion at $A000
    LOAD"LOADER",8 : REM LOAD/INIT HIRES20.ML
    RUN
    LOAD"HIRES28",8 : REM DEMO1
    RUN
    LOAD"4UPART",8 : REM DEMO2
    RUN

</details>

</br>

<details>
<summary>Build notes</summary>

* Compiling requires [ACME](https://sourceforge.net/projects/acme-crossass/) for use with Microsoft Visual Code.  
* Also leverages [Esshahn/acme-assembly-vscode-template](https://github.com/Esshahn/acme-assembly-vscode-template)
* Build launches [VICE](http://vice-emu.sourceforge.net/index.html#download) C-64 Emulator so install that too.
* And some manual editing of the development system and configuration files is required (e.g. ACME and VICE locations).  See build.sh for use within Visual Code.
* Additional work will be required for non-Windows platforms (but it's easy).
</details>

</br>

Links: 

* [Built D64 disk image for Vic-20](https://github.com/davervw/hires-vic-20/raw/master/build/hires20.d64)
* [Blog: Vic-20 Hi-Res in progress memory layout](https://techwithdave.davevw.com/2022/07/vic-20-hi-res-in-progress-memory-layout.html)
* [Blog: Vic-20 Hi-Res BASIC extension progress](https://techwithdave.davevw.com/2022/08/vic-20-hi-res-basic-extension-progress.html)

