; hires20.asm
;
; Commodore Vic-20 High Resolution Graphics BASIC Extension
; Copyright (c) 2022 Dave Van Wagner (davevw.com)
; MIT LICENSE - see file LICENSE

; memory map
; 0000-03FF Low RAM (1K)
; 0400-0FFF RAM Expansion (3K)
; 1000-1FFF Standard RAM (4K)
;  1000-11E1 TEXT Video Memory 8x8 characters 00-FF, 22*23=482
;  11E2-1FFF Available RAM when in TEXT mode
;  1000-10EF HIRES Video Memory 8x16 characters 10-FF
;  10F0-1FFF HIRES Video RAM Bitmap (of characters 0F-FF)
; 2000-7FFF Expansion RAM (24K) - recommend relocation of start of BASIC
; 8000-8FFF Character ROM (4K)
; 9000-9FFF I/O space and color RAM (nybbles)
; A000-BFFF Cartridge ROM and/or RAM (8K) - HIRES20.ML loaded A000-????
; C000-DFFF BASIC ROM
; E000-FFFF KERNAL ROM

; PROPOSED COMMANDS
; HIRES 1,[XR],[YR]
; PLOT 0|1|2|3,X,Y
; PLOT 0|1,"ABC",X,Y
; PLOT 0|1|2|3 [@ X1, Y1][TO X2, Y2][...]
; RECT 0|1|2|3 @ X1, Y1 TO X2, Y2
; PLOT COLOR [FG]
; COLOR [1,[FG][,[BG][,[BD][,AUX]]]]|[INVERSE]
; COLOR 0|1[,FG] @ X1, Y1 [TO x2, Y2]
; DELAY {JIFFIES}
;
; PROPOSED VARIABLES
; .XRES
; .YRES
; .JOYS
; .FORE
; .BACK
; .BORD
; .AUXC
; .REVS
; .PAL
; .NTSC

chkcom=$cefd
getbytc=$d79b
frmnum=$cd9e
syntax_error=$cf08
error=$c437
frmevl=$cd9e
pulstr=$d6a3

chars=$1000
bitmap_chars_most=240
bitmap=chars+bitmap_chars_most
char_first=bitmap_chars_most/16 ; 15

chrout=$ffd2

*=$A000

start
    jmp hires_init ; switch to HIRES
    jmp multax ; multiply 8-bit by 8-bit
    jmp divaxwithy ; divide 16-bit by 8-bit
    jmp divremainder ; get remainder of last division of 16-bit by 8-bit
    jmp hires_plot ; plot point on screen
    jmp hires_unplot ; remove point from screen
    jmp get_resolution ; retrieve resolution
    jmp draw_text ; text at location
    jmp color ; set foreground, background, border, auxilary, inverse
    jmp hires_mplot ; plot multi-color point on screen
    jmp hires_fill ; fill graphics with a bit pattern
    jmp set_plot_color ; set color selectively applied to color cells for graphics, or 255 to use existing color cells
    jmp hires_draw ; draw line on screen
    ;jmp hires_mdraw ; draw multicolor line on screen

    ; BRK statements filler for yet to be implemented entry points (256 bytes)
    !byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    !byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    !byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    !byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    !byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    !byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    !byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    !byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    !byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    !byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    !byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    !byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    !byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    !byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    !byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    !byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

hires_init
    jsr two_params_bytes
+   jsr verifyres
    jsr switch_graphics
    jsr clear_graphics
    jsr fill_video_chars
    jsr fill_video_color
    jsr get_resolution
    rts

draw_text
    jsr two_params_bytes_string
    jsr plot_prep

    ldx strlen
    beq ++ ; check if nothing to do

    txa
    clc
    adc param1
    cmp resx
    beq +
    bcs ++ ; out of range, avoid inadvertant memory overwrites and wrap by exiting
+   clc
    tya
    adc #8
    cmp resy
    beq +
    bcs ++ ; out of range, avoid memory overwrites and wrap by exiting
+
    ; add y offset to pointer, so can use y for other things
    clc
    tya
    adc $fb
    sta $fb
    bcc +
    inc $fc
+
-   ldy #0
    lda ($fd),y
    jsr petscii_to_screencode
    jsr get_screen_char_addr
--  lda ($57),y
    sta ($fb),y
    iny
    cpy #8
    bne --
    clc
    lda $fb
    adc resy
    sta $fb
    bcc +
    inc $fc
    lda $fc
    cmp #$20
    bcs ++ ; branch if dest is out of range, don't write over BASIC RAM
+   inc $fd
    bne +
    inc $fe
+   dex
    bne -
++  rts

hires_plot
    jsr two_params_bytes
hires_plot_point
    jsr plot_prep
    ora ($fb),y
    sta ($fb),y
    lda plot_color
    bmi +
    ldx plot_color_offset
    and #7 
    sta $9400,x
+   rts

hires_unplot
    jsr two_params_bytes
hires_unplot_point
    jsr plot_prep
    eor #$ff
    and ($fb),y
    sta ($fb),y
    lda plot_color
    bmi +
    ldx plot_color_offset
    and #7 
    sta $9400,x
+   rts

hires_mplot
    jsr three_params_bytes
hires_mplot_point
    jsr mplot_prep
    and ($fb),y
    sta $57
    txa
    ora $57
    sta ($fb),y
    lda plot_color
    bmi +
    ldx plot_color_offset
    ora #8 
    sta $9400,x
+   rts

hires_fill
    jsr one_param_byte
    lda param1
    jmp fill_graphics

set_plot_color
    jsr one_param_byte
    lda param1
    cmp #$10
    bcc +
    cmp #$FF
    beq +
    jmp illegal_quantity
+   sta plot_color
    rts

hires_draw
    jsr two_or_three_params_bytes
    ; param1 = x coordinate
    ; param2 = y coordinate
    ; param3 (optional) = multicolor 0,1,2,3 choice, or 255 (unplot hires)
    ; param4 = number of parameters

    ; check if out of range
    lda param1
    cmp resx
    bcc +
-   jmp illegal_quantity
+   lda param2
    cmp resy
    bcs -
    lda param4
    cmp #4
    bcs -
    cmp #2
    bcc -
    bne +
    ldx #<hires_plot_point
    ldy #>hires_plot_point
    bne +++
+   lda param3
    bmi ++
    ldx #<hires_mplot_point
    ldy #>hires_mplot_point
    bne +++
++  ldx #<hires_unplot_point
    ldy #>hires_unplot_point
+++ stx plot_point_vector
    sty plot_point_vector+1

    lda #1
    sta incx
    sta incy

    ; get absolute diffx, diffy
    lda param1
    sec
    sbc oldx
    bcs +
    ldx #$ff
    stx incx
    eor #$ff
    adc #1
+   sta diffx
    lda param2
    sec
    sbc oldy
    bcs +
    ldy #$ff
    sty incy
    eor #$ff
    adc #1
+   sta diffy

    ; test for point only
    lda diffx
    ora diffy
    bne +
    jmp call_plot_point_indirect

    ; swap old/new
+   ldx param1
    ldy param2
    lda oldx
    sta param1
    lda oldy
    sta param2
    stx param4
    sty param5

    lda diffx
    cmp diffy
    bcs +++

    ; diffx is less than diffy, so draw each y
    lda #0
    sta $59
-   jsr call_plot_point_indirect
    clc
    lda param2
    adc incy
    sta param2
    clc
    lda $59
    adc diffx
    sta $59
    bcs +
    cmp diffy
    bcc ++
+   sbc diffy
    sta $59
    clc
    lda param1
    adc incx
    sta param1

++  lda param2
    cmp param5
    bne -
    jmp call_plot_point_indirect ; one last time

+++ ; diffx is greater than or equal to diffy, so draw each x 
    lda #0
    sta $59
-   jsr call_plot_point_indirect
    clc
    lda param1
    adc incx
    sta param1
    clc
    lda $59
    adc diffy
    sta $59
    bcs + ; if 8-bit overflow, then definitely bigger than diffx
    cmp diffx
    bcc ++
+   sbc diffx ; reset remainder
    sta $59
    clc
    lda param2
    adc incy
    sta param2

++  lda param1
    cmp param4
    bne -
    jmp call_plot_point_indirect ; one last time

call_plot_point_indirect
    jmp (plot_point_vector)

plot_prep
; input param1 = x coord
; input param2 = y coord
; output address in $fb/$fc accounting only for x coord
; output .a=bit mask shifted
; output .y=y coord to be used as offset, e.g. ($fb),y
; output plot_color_offset=offset to color memory, e.g. $9400,x
    jsr plot_addr
    stx plot_color_offset
    lda param1
    and #$07
    tax
    lda pow7_x,x
    rts

mplot_prep
; input param1 = x coord
; input param2 = y coord
; input param3 = color bit 0,1,2,3 (00, 01, 10, 11)
; output address in $fb/$fc acconting only for x coord
; output .a=inverse bits mask, .x=bits color shifted
; output .y=y coord to be used as offset, e.g. ($fb),y
; output .x=bit position
; output plot_color_offset contains offset to color memory, e.g. $9400,x
    jsr plot_addr
    stx plot_color_offset
    lda param1
    and #$07
    lsr
    sta $57
    tax
    lda mbit_x+12, x ; bits mask
    eor #$ff
    pha
    lda param3
    and #$03
    asl
    asl
    adc $57
    tax
    lda mbit_x, x
    tax ; bits selection in X
    pla ; bits mask in A
    rts

; hires_addr = $1100 + vr*(x >> 3) + y
; bit = 2^(7-(x and 7))
; color_addr = $9400 + (y >> 4) * (xr >> 3) + (x >> 3)  ; offset to $9400 returned in .x
plot_addr
    lda param1
    cmp resx
    bcs ++
    lda param2
    cmp resy
    bcc +
++  jmp illegal_quantity
+   lda param1
    sta oldx
    lsr
    lsr
    lsr
    sta $57
    ldx resy
    jsr multax
    sta $fb
    txa
    clc
    adc #$11
    sta $fc

    lda param2
    lsr
    lsr
    lsr
    lsr
    tax
    lda cols
    jsr multax    
    clc
    adc $57
    tax

    ldy param2
    sty oldy
    rts
    
; addr = $1100 + 16*int(x/8)+16*hr/8*int(y/16)+(y and 15)
; addr = $1100 + 2*(x and 248) + hr*((y >> 3) and 254)+(y and 15)
; bit = 2^(7-(x and 7))

; plot_prep
;     lda param1
;     cmp resx
;     beq +
;     bcs ++
; +   lda param2
;     cmp resy
;     beq +
;     bcc +
; ++  jmp syntax_error
; +   lda #$11
;     sta $fc
;     lda param1
;     and #$f8
;     asl
;     sta $fb
;     bcc +
;     inc $fc
; +   lda param2
;     lsr
;     lsr
;     lsr
;     and #$fe
;     ldx resx
;     jsr multax
;     clc
;     adc $fb
;     sta $fb
;     txa
;     adc $fc
;     sta $fc
;     lda param2
;     and #$0F
;     tay
;     lda param1
;     and #$07
;     tax
;     lda pow7_x,x
;     rts

switch_graphics
    lda cols
    sta 36866
    lda rows
    sec
    rol
    sta 36867
    lda #$CC
    sta 36869

    jsr ntsc_or_pal
    bcs +++

; adjust ntsc margins of screen based on resolutions
    lda cols
    cmp #25
    bcs + ; special case for 200 resx or above
    eor #$ff ; invert bits to make negative, off by one
    adc #28 ; add one more to compensate for ones complement
    bpl ++ ; make sure positive (will probably never be negative due to earlier 200 check)
+   lda #1 
++  sta 36864
    lda resy
    lsr
    lsr
    eor #$ff ; invert bits to make negative, off by one
    adc #72 ; add one more to compensate for ones complement
    sta 36865
    rts

; adjust pal margins of screen based on resolutions
+++ lda cols
    eor #$ff ; invert bits to make negative, off by one
    adc #35 ; add one more to compensate for ones complement
    sta 36864
    lda resy
    lsr
    lsr
    eor #$ff ; invert bits to make negative, off by one
    adc #85 ; add one more to compensate for ones complement
    sta 36865
    rts

fill_video_chars ; fill number of 8x16 programmable characters on screen
    ; fill video characters left to right a full column at a time
    ldy #0 ; i = 0..bitmap_chars-1(<240) by 1
    ldx #16 ; j = 16..bitmap_chars+15(<=255) by rows, with adjustment each col
--  tya
    clc
    adc cols
    sta $fd
-   txa
    sta $1000,y
    clc
    adc rows
    tax
    iny
    cpy $fd
    bne -
+   sec
    sbc bitmap_chars
    tax
    inx
    cpy bitmap_chars
    bne --
    rts

fill_video_color
    ; fill color
    ldy bitmap_chars
    lda 646
-   dey
    sta $9400,y
    cpy #0
    bne -
    rts

; limits
; 0 < resx * resy / 128 <= 240
; resx & 7 = 0
; resy & 15 = 0
; resx <= 216
; resy <= 320

; calculate maximum resolution, picking one dimension
; 240*128 = 30720
; resx = (240*128/resy) and $1f8
; resy = (240*128/resx) and $1f0

illegal_quantity
    ldx #14
    jmp error

verifyres
    lda param1
    and #7
    bne illegal_quantity
    
    lda param2
    and #15
    bne illegal_quantity

    lda param1
    bne +++
    ldy param2
    beq illegal_quantity
    lda #<240*128
    ldx #>240*128
    jsr divaxwithy
    and #$f8
    cmp #217
    bcc ++++
    lda #216
++++
    sta param1
    cpx #1
    bcc ++
    lda #216
    sta param1
    bne ++

+++ lda param2
    bne ++
    ldy param1
    beq illegal_quantity
    lda #<240*128
    ldx #>240*128
    jsr divaxwithy
    and #$f0
    sta param2
    cpx #1
    bcc ++
    lda #$f0
    sta param2

++  lda param1
    ldx param2
    jsr multax
    ldy #128
    jsr divaxwithy
    cpx #1
    bcs illegal_quantity
    cmp #0
    beq illegal_quantity
    cmp #bitmap_chars_most+1
    bcs illegal_quantity
    sta bitmap_chars
    lda param1
    sta resx
    lsr
    lsr
    lsr
    sta cols
    lda param2
    sta resy
    lsr
    lsr
    lsr
    lsr
    sta rows
    rts

clear_graphics
    lda #0
    jmp fill_graphics

fill_graphics
    ldy #0
-   sta $1100, y
    sta $1200, y
    sta $1300, y
    sta $1400, y
    sta $1500, y
    sta $1600, y
    sta $1700, y
    sta $1800, y
    sta $1900, y
    sta $1a00, y
    sta $1b00, y
    sta $1c00, y
    sta $1d00, y
    sta $1e00, y
    sta $1f00, y
    iny
    bne -
    rts

color
    jsr five_params_bytes
    lda param1
    and #$F0
    bne ++
    lda param2
    and #$F0
    bne ++
    lda param3
    and #$f8
    bne ++
    lda param4
    and #$f0
    bne ++
    lda param5
    and #$fe
    bne ++
    lda param1
    sta 646
    lda param2
    asl
    asl
    asl
    asl
    ora param3
    ldx param5
    bne +
    ora #$08
+   sta $900F
    lda $900E
    asl
    asl
    asl
    asl
    ora param4
    asl
    rol
    rol
    rol
    adc #0
    sta $900E
    rts
++  jmp illegal_quantity

;multiply by shift/add
;input: a and x
;output: a (low), x (high), y (preserved)
multax: 
    sty save_y 
    ldy #$00 
    sty suml
    sty sumh 
    sta shiftl 
    sty shifth 
-   txa 
    ror
    tax
    bcc +
    clc 
    lda suml
    adc shiftl 
    sta suml
    lda sumh 
    adc shifth 
    sta sumh
+   iny 
    cpy #08 
    beq +
    asl shiftl 
    rol shifth 
    bcc - 
+   lda suml
    ldx sumh 
    ldy save_y 
    rts

;multiply by shift/subtract
;input: a (low), x (high), y (divisor)
;output: a (low), x (high), y (zero page pointer to remainder)
;algorithm: 
; shift contains bit (0 to 15, starts right-most [1]) to add to answer in sum (starts at 0)
; y saved to divisor (16-bit), shifted in loop to match shift
; workarea starts with a/x, subtracted by shift as appropriate, reduced to remainder
; shift advanced to left as high as possible at first, then shifted right as loops, until shifts out

divaxwithy
; initialize members
    sty divisorl
    ldy #0
    sty divisorh
    sty shiftl
    inc shiftl
    sty shifth
    sty suml
    sty sumh
    sta remainl
    stx remainh

    ; x is high byte of workarea
    cpx divisorh
    bcc ++ ; branch if workarea < shift, already done
    bne + ; branch if workarea > shift
    ; high bytes equal
    ; a is low byte of workarea
    cmp divisorl
    bcc ++ ; branch if workarea < shift, already done
    beq +++ ; workarea == shift, guaranteed we have the right shift bit to work with   
    ; workarea > shift, so shift some more
+
-   asl shiftl
    rol shifth
    bcs ++++ ; shifted too far, bit 16 fell out of shift
    asl divisorl
    rol divisorh
    bcs +++++ ; shifted too far, divisor shifted out
    ; x is high byte of workarea
    cpx divisorh
    bcs +
    ; shifted too far
+++++
--
    ror divisorh
    ror divisorl
    bcc ++++
    brk ; shouldn't happen
+   bne - ; branch if remain > than shift
    ; low bytes equal
    ; a is low byte of workarea
    cmp divisorl
    bcc -- ; remain < remain, shifted too far
    bne - ; remain > shift, so shift some more
    beq +++ ; workarea == shift, guaranteed we have the right shift bit to work with   
    brk ; assert should never get here

    ; shifted too far, carry set only if rotated out of high byte
++++
    ror shifth
    ror shiftl
    bcs + ; lowest bit shifted out, nothing more to do

+++ ; shift is just right, add to sum, subtract from workarea 
--  lda shiftl
    ora suml
    sta suml
    lda shifth
    ora sumh
    sta sumh
    sec
    lda remainl
    sbc divisorl
    sta remainl
    lda remainh
    sbc divisorh
    sta remainh
++  lda remainl ; restore .A
    ldx remainh ; restore .X
-   lsr divisorh
    ror divisorl
    lsr shifth
    ror shiftl
    bcs + ; done
    cpx divisorh
    bcc - ; remain < divisor
    bne -- ; branch if remain > divisor
    ; low bytes equal
    ; a is low byte of workarea
    cmp divisorl
    bcc - ; remain < divisor
    bcs -- ; branch if remain >= divisor
    brk ; not possible to get here

+   lda suml
    ldx sumh
    rts

divremainder ; get remainder
    lda remainl
    ldx remainh
    rts

get_resolution
    ldx resx
    ldy resy
    rts

one_param_byte
    ldy #0
    lda ($7a),y
    cmp #$2C
    bne ++
    jsr getbytc
    bne ++
    stx param1
    rts
++  jmp syntax_error

two_params_bytes
    ldy #0
    lda ($7a),y
    cmp #$2C
    bne ++
    jsr getbytc
    cmp #$2C
    bne ++
    stx param1
    jsr getbytc
    bne ++
    stx param2
    rts
++  jmp syntax_error

two_or_three_params_bytes
    ldx #2
    stx param4
    ldy #0
    lda ($7a),y
    cmp #$2C
    bne ++
    jsr getbytc
    cmp #$2C
    bne ++
    stx param1
    jsr getbytc
    stx param2
    beq +
    cmp #$2C
    bne ++
    jsr getbytc
    bne ++
    stx param3
    inc param4
+   rts
++  jmp syntax_error

two_params_bytes_string
    ldy #0
    lda ($7a),y
    cmp #$2C
    bne ++
    jsr getbytc
    cmp #$2C
    bne ++
    stx param1
    jsr getbytc
    stx param2
    jsr chkcom
	jsr frmevl	; evaluate expression
	bit $d		; string or numeric?
	bpl ++
    jsr pulstr	; pull string from descriptor stack (a=len, x=lo, y=hi addr of string)
    sta strlen
    stx $fd
    sty $fe
    rts
++  jmp syntax_error

three_params_bytes
    ldy #0
    lda ($7a),y
    cmp #$2C
    bne ++
    jsr getbytc
    cmp #$2C
    bne ++
    stx param1
    jsr getbytc
    cmp #$2C
    bne ++
    stx param2
    jsr getbytc
    bne ++ ; not end of statement
    stx param3
    rts
++  jmp syntax_error

five_params_bytes
    ldy #0
    lda ($7a),y
    cmp #$2C
    bne ++
    jsr getbytc
    cmp #$2C
    bne ++
    stx param1
    jsr getbytc
    cmp #$2C
    bne ++
    stx param2
    jsr getbytc
    cmp #$2C
    bne ++
    stx param3
    jsr getbytc
    cmp #$2C
    bne ++
    stx param4
    jsr getbytc
    bne ++ ; not end of statement
    stx param5
    rts
++  jmp syntax_error

petscii_to_screencode 
        cmp #$20
        bcs +++
-       lda #63         ; out of range '?'
        bne +           ; display it
+++     cmp #$ff        ; pi?
        bne +++
        lda #$5e        ; convert to pi screen code
        bne +           ; display it
+++     cmp #$e0
        bcc +++         ; continue on if not e0..fe
        sbc #$80        ; convert to screen code
        bne +           ; display it
+++     cmp #$c0        ; check if in range c0..df
        bcc +++         ; continue on if not c0..df
        sbc #$80        ; convert to screen code
        bne +           ; display it
+++     cmp #$a0
        bcc +++         ; continue on if not a0..bf
        sec
        sbc #$40
        bne +           ; display it
+++     cmp #$80
        bcs -           ; skip if out of range 80..9f
        cmp #$40
        bcc +           ; display if in range 20..3f
        cmp #$60
        bcs +++         ; branch if 60..7f
        sec             ; otherwise in range 40..5f
        sbc #$40        ; convert ASCII to screen code
        jmp +
+++     sbc #$20        ; convert to screen code
+	    clc
        adc charrvs
        rts

get_screen_char_addr
    sta $57
    txa
    pha
    tya
    pha
    lda $57
    ldx #8
    jsr multax
    sta $57
    clc
    txa
    adc #$80
    sta $58
    pla
    tay
    pla
    tax
    rts

ntsc_or_pal
    sei
    lda $9004
    bmi +
-   lda $9004
    bpl -
+
-   tax
    lda $9004
    bmi -
-   lda $9004
    bpl -
-   tay
    lda $9004
    bmi -
    cli
    stx $57
    tya
    cmp $57
    bcs +
    lda $57
    ; a will contain largest raster line number (div2) captured of two samples (x and y)
+   cmp #$85 ; NTSC=$82, PAL=$9B
    ; carry set for PAL, carry clear for NTSC
    rts

save_y  !byte 0
shiftl !byte 0
shifth !byte 0
suml !byte 0
sumh !byte 0
divisorl !byte 0
divisorh !byte 0
remainl !byte 0
remainh !byte 0

param1 !byte 0
param2 !byte 0
param3 !byte 0
param4 !byte 0
param5 !byte 0

oldx !byte 0
oldy !byte 0

diffx !byte 0
diffy !byte 0
incx !byte 0
incy !byte 0
supress_error !byte 0

resx !byte 0
resy !byte 0
bitmap_chars !byte 0
cols !byte 0
rows !byte 0
plot_color !byte 255
plot_color_offset !byte 0

strlen !byte 0
charrvs !byte 0

pow7_x !byte 128, 64, 32, 16, 8, 4, 2, 1

mbit_x 
!byte 0, 0, 0, 0 ; bits 00
!byte 64, 16, 4, 1 ; bits 01
!byte 128, 32, 8, 2 ; bits 10
!byte 192, 48, 12, 3 ; bits 11

plot_point_vector
!byte 0, 0