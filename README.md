# Hi-Res BASIC Extensions for Commodore Vic-20 #

I added commands to Commodore Vic-20 BASIC via software extensions
written in 6502 Assembly.  This is an original work leveraging my [HIRES for C64](https://github.com/davervw/hires-c64). 

<details>
<summary>Command syntax</summary>

    COLOR [foreground[+8][,[background][,[border][,auxillary[,inverse]]]]]
    COLOR [foreground[+8]] @ x1,y1 [TO x2,y2]
    TEXT
    HIRES xresolution, yresolution [,fillbyte]
    DELAY jiffies
    PLOT COLOR ON|OFF
    PLOT [NOT|CLR] (@ x1,y1)|(TO x2,y2)...    **
    PLOT 0|1|2|3 (@ x1,y1)|(TO x2,y2)...
    PLOT "ABC" @ x,y [,addr [,width,height [,bytes]]]
    RECT [NOT|CLR] [@] x1,y1 TO x2,y2
    RECT 0|1|2|3 @ x1,y1 TO x2,y2
    SHAPE GET|PUT|OR|XOR|AND|NOT|CLR addr @ x1, y1 TO x2, y2

    ** only first @ optional, when not multi-color

</details>

<br>

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

<br>

![Demo3 tiny font](https://github.com/davervw/hires-vic-20/raw/master/doc/media/demo3/40x24chars_vs_72x16chars.png)

<details>
<summary>4x8 font</summary>

The PLOT "TEXT" syntax allows for optionally specifying the font address, height, width, and number of bytes to skip between characters (useful when squeezing the font smaller to eliminate whitespace... example 7 lines instead of 8 sacrificing the last line of the font image but skipping 8 bytes because the font is designed with 8 bytes).

The 4x8 font is currently at $B000 (11*4096 decimal), included in the LOADHIRES20 image.   It may be optional or moved in the future.

Feel free to make fonts of any size.  The font SHAPEs can be any height/width you design.  Then use the PLOT command to draw the text on the screen.

</details>

<br>

<details>
<summary>Usage</summary>

    REM REQUIRES 8K expansion at $2000, and 8K expansion at $A000
    LOAD"LOADHIRES20",8 : REM LOAD/INIT HIRES EXTENSION
    RUN
    LOAD"HIRES28",8 : REM DEMO1
    RUN
    LOAD"4UPART",8 : REM DEMO2
    RUN

* LOADHIRES20 is only file needed to install the extensions (but do not modify by conventional means)
* HIRES20.ML is an alternative copy that can be manually loaded and initialized (SYS 40960), 
but requires additional steps including moving start of BASIC programs (away from 4096-8191) and performing NEW (see LOADHIRES20)

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

