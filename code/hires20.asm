; hires20.asm

; Commodore Vic-20 High Resolution Graphics BASIC Extension
; Copyright (c) 2022 Dave Van Wagner (davevw.com)
; MIT LICENSE - see file LICENSE

; Thanks to https://archive.org/details/COMPUTEs_Mapping_the_VIC_1984_COMPUTE_Publications

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

; WORKING SYNTAX
; COLOR [fg[+8][,[bg][,[bd][,aux[,inverse]]]]]
; COLOR [fg[+8]] @ x1,y1 [TO x2,y2]
; TEXT
; HIRES xr, yr [,fillbyte]
; DELAY jiffies
; PLOT COLOR ON|OFF
; PLOT [0|1|2|3|NOT|CLR] (@ x1,y1)|(TO x2,y2)...     (** first @ optional if not multicolor) 
; PLOT "ABC" @ x,y [,addr [,width,height [,bytes]]]
; RECT [NOT|CLR] [@] x1,y1 TO x2,y2
; RECT 0|1|2|3 @ x1,y1 TO x2,y2
; SHAPE GET|PUT|OR|XOR|AND|NOT|CLR addr @ x1, y1 TO x2, y2

; PROPOSED SYNTAX REMAINING
; PLOT [0|1|2|3 ,] "ABC" @ x,y [,addr [,width,height [,bytes]]]
; SHAPE [0|1|2|3] GET|PUT|OR|XOR|AND|NOT|CLR addr @ x1,y1 TO x2,y2
; PATTERN addr @ x1,y1 TO x2,y2

; PROPOSED VARIABLES
; .HIRES
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

ptrl=$fe
ptrh=$ff

chkcom=$cefd
getbytc=$d79b
frmnum=$cd9e
syntax_error=$cf08
error=$c437
frmevl=$cd9e
pulstr=$d6a3
makadr=$d7f7 ; convert fp to 2 byte integer
listchr=$cb47 ; output a character

chars=$1000
bitmap_chars_most=240
bitmap=chars+bitmap_chars_most
char_first=bitmap_chars_most/16 ; 15

chrout=$ffd2

*=$A000

start
    jmp init_basic

copyright
    !byte 18
    !text "VIC-20 HIRES"
    !byte 13
    !text "COPYRIGHT (C) 2022"
    !byte 13
    !text "BY DAVID VAN WAGNER"
    !byte 13
    !text "DAVEVW.COM"
    !byte 13
    !text "MIT LICENSE"
    !byte 13
    !byte 0

init_basic ; setup vectors for adding HIRES commands, etc.
    ldx #0
-   lda copyright,x
    beq +
    jsr chrout
    inx
    bne -

+   lda #<basic_error
    sta $300
    lda #>basic_error
    sta $301

    lda #<hires_crunch
    sta $304
    lda #>hires_crunch
    sta $305

    lda #<list_tokens
    sta $306
    lda #>list_tokens
    sta $307

    lda #<execute
    sta $308
    lda #>execute
    sta $309

    jmp crunch_patch

exec_text
    jsr switch_text
    jsr $0073
    jmp reloop

exec_hires
    jsr reset_font_params
    jsr next_two_bytes
    jsr hires_init
    ldx resx
    ldy resy
    stx 781
    sty 782
    ldy #0
    lda ($7a),y
    cmp #$2C ; comma
    bne +
    jsr getbytc
    txa
    jsr fill_graphics
+   jmp reloop

hires_init
    jsr verifyres
    jsr switch_graphics
    jsr clear_graphics
    jsr fill_video_chars
    jsr fill_video_color
    rts

plot_string
    ldx strlen
    beq ++ ; check if nothing to do

    ; mode=1 PUT
    lda #1
    sta param5

    ; y2=y1+height-1
    clc
    lda param2
    adc font_height
    sbc #0 ; subtract one with carry clear
    sta param4
    cmp resy
    bcs ++

    ldy #0
    sty $60

-   
    ; x2=x1+width-1
    lda param1
    adc font_width
    sbc #0 ; subtract one with carry clear
    sta param3
    cmp resx
    bcs ++

    ldy $60
    lda ($5a),y
    jsr petscii_to_screencode
    jsr get_char_addr
    jsr get_put_shape

    ; x1+=width
    clc
    lda param1
    adc font_width
    sta param1
    bcs ++
    cmp resx
    bcs ++

    ; ++y
    inc $60

    dec strlen
    bne -

++  rts

exec_plot
    lda #128
    sta plot_mode  ; assume monochrome set pixel

    jsr lookahead

    cmp #$CD ; COLOR token
    bne +++ ; branch not color
    ; PLOT COLOR ON|OFF
    jsr $0073
    jsr $0073
    bne +
--- jmp syntax_error
+   cmp #$91 ; ON token
    bne +
    lda 646
    jmp ++
+   cmp #$D7 ; OFF token
    bne ---
    lda #$FF
++  sta plot_color
    jsr $0073
    jmp reloop

    ; optional NOT/CLR for erasing monochrome pixel
+++ cmp #$A8 ; NOT token
    beq +
    cmp #$9C ; CLR token
    bne ++
+   jsr $0073
    lda #$FF
    sta plot_mode
    jsr lookahead

++  cmp #$A4 ; TO token
    bne + ; branch not to
    jsr $0073
    bne ++ ; should always branch

+   cmp #$40 ; @ token
    bne +
    jsr $0073 ; gobble optional @
    jmp +++

    ; no optional @ (yet)
+   lda plot_mode
    cmp #$FF
    beq +++ ; NOT/CLR seen, but not TO, so must be coordinate
    ; so look for coordinate or multicolor choice
    jsr $0073 ; get next token
    jsr string_or_byte
    bcc + ; branch if byte
    ; string!
    sta strlen
    stx $5a
    sty $5b
    ldy #0
    lda ($7a),y
    cmp #$40 ; require @
    bne ---
    jsr next_two_bytes
    jsr more_plot_text_params
    jsr plot_string
    jmp reloop
+   ldy #0
    lda ($7a),y
    cmp #$A4 ; TO token?
    bne +
    stx plot_mode
    beq ++
+   cmp #$40 ; @ required after multicolor choice
    bne + ; must be coordinate instead
    stx plot_mode
    jmp +++ ; go get coordinate after @

    ; we got first coordinate, now go for second
+   cmp #$2c
    beq +
    jmp syntax_error
+   stx param1
    jsr getbytc
    stx param2
    jmp ++++

--  ; loop:
    cmp #$A4 ; TO token
    bne ++
++  jsr next_two_bytes
    php
    pha
    lda #3
    sta param4
    lda plot_mode
    sta param3
    cmp #$80
    bne +
    dec param4
+   jsr hires_draw_line
-   pla
    plp
    bne --
    jmp reloop  
++  cmp #$40 ; @ token
    beq +++
    jmp ---
+++ 
    jsr next_two_bytes
++++
    php
    pha
    lda plot_mode
    cmp #$ff
+   bne +
    jsr hires_unplot_point
    jmp -
+   cmp #$80
    bne +
    jsr hires_plot_point
    jmp -
+   sta param3
    jsr hires_mplot_point
    jmp -

more_plot_text_params
    beq ++
    jsr chkcom
    jsr frmevl
    jsr makadr
    sty font_address
    sta font_address+1
    ldy #0
    lda ($7a),y
    beq ++
    cmp #$3a
    beq ++
    cmp #$2c
    bne ++++
    jsr getbytc
    stx font_width
    cmp #$2C
    bne ++++
    jsr getbytc
    stx font_height
+   clc
    lda font_width
    adc #7
    lsr
    lsr
    lsr
    beq +++
    ldx font_height
    beq +++
    jsr multax
    cpx #0
    bne +++
    sta font_bytes
    ldy #0
    lda ($7a),y
    beq ++
    cmp #$3a
    beq ++
    jsr getbytc
    cpx #0
    beq +++
    stx font_bytes
++  rts
+++ jmp illegal_quantity
++++ jmp syntax_error

reset_font_params
    lda #$00
    sta font_address
    lda #$80
    sta font_address+1
    lda #8
    sta font_width
    sta font_height
    sta font_bytes
    rts

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

    ; param1 = x coordinate
    ; param2 = y coordinate
    ; param3 (optional) = multicolor 0,1,2,3 choice, or 255 (unplot hires)
    ; param4 = number of parameters
hires_draw_line
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

exec_rect
    lda #128
    sta param5 ; assume monochrome set
    ; optional NOT/CLR for erasing monochrome rect
    jsr lookahead
    cmp #$A8 ; NOT token
    beq +
    cmp #$9C ; CLR token
    bne ++
+   lda #255
    sta param5
    jsr $0073 ; gobble up
    jsr lookahead

++  cmp #$40 ; skip over optional @
    bne +
    jsr $0073
+   
--  jsr getbytc ; not sure yet, so parse one byte
    cmp #$2c ; is next token is comma?
    bne + 
    ; yes, these are coordinates
    stx param1
    jsr getbytc
    stx param2
    jmp ++
    
+   ldy param5
    cpy #$ff
    bne + ; branch if didn't see NOT/CLR  
-   jmp syntax_error
+   stx param5 ; this is multicolor choice (must be 0-3)
    cmp #$40 ; expect @
    bne -  ; @ was expected
    beq --

++  cmp #$A4 ; TO token
    bne - ; TO was expected

    ; expect two more bytes for ending coordinates
    jsr getbytc
    cmp #$2c
    stx param3
    bne -
    jsr getbytc
    stx param4

    lda #5 ; assume 5 parameters, multicolor or erase
    ldy param5
    cpy #$80
    bne +
    lda #4 ; just monochrome normal, so no extra param
+   jsr hires_rect ; draw rectangle
    jmp reloop

    ; param1/param2 = first x/y coordinate
    ; param3/param4 = second x/y coordinate
    ; param5 = multicolor 0,1,2,3 choice, or 255 (unplot hires), or undefined if 4 parameters
    ; .A = number of parameters
    ; validate and store parameters
hires_rect
    cmp #6
    bcc +
-   jmp illegal_quantity
+   cmp #4
    bcc -
    sbc #2 ; convert to number of parameters will be passing to draw
    sta rectdrawparams
    cmp #3
    bcc ++
    lda param5
    cmp #255
    beq +
    cmp #4
    bcs -
+   sta rectdrawcolor
++  lda param1
    cmp resx
    bcs -
    sta rectx1
    lda param2
    cmp resy
    bcs -
    sta recty1
    lda param3
    cmp resx
    bcs -
    sta rectx2
    lda param4
    cmp resy
    bcs -
    sta recty2

    lda rectx2
    sta oldx
    lda recty2
    sta oldy

    ldx rectx1
    ldy recty2
    jsr +

    ldx rectx1
    ldy recty1
    jsr +

    ldx rectx2
    ldy recty1
    jsr +

    ldx rectx2
    ldy recty2

+   stx param1
    sty param2
    lda rectdrawcolor
    sta param3
    lda rectdrawparams
    sta param4
    jmp hires_draw_line

hires_color_at
    lda param1
    cmp resx
    bcc +
-   jmp illegal_quantity
+   lsr
    lsr
    lsr
    sta param1
    lda param2
    cmp resy
    bcs -
    lsr
    lsr
    lsr
    lsr
    sta param2
    lda param3
    cmp resx
    bcs -
    lsr
    lsr
    lsr
    sta param3
    lda param4
    cmp resy
    bcs -
    lsr
    lsr
    lsr
    lsr
    sta param4
    lda param5
    cmp #16
    bcs -
    ldy cols
    jmp rect_color

text_color_at
    lda param1
    cmp #22
    bcc +
-   jmp illegal_quantity
+   lda param2
    cmp #23
    bcs -
    lda param3
    cmp #22
    bcs -
    lda param4
    cmp #23
    bcs -
    lda param5
    cmp #16
    bcs -
    ldy #22
    jmp rect_color

exec_delay
    jsr $0073
    jsr +
    jmp reloop

sys_delay
    jsr chkcom
+
    jsr frmnum
 	jsr makadr	; convert to integer

    ; set alarm with interrupts on during critical part, avoiding rollover
    clc
    pha ; save bits 8..15
	tya ; transfer bits 0..7
    sei
    adc $A2
	sta alarm+2
    pla ; restore bits 8..15
    adc $A1
    sta alarm+1
    lda $A0
    cli
    adc #0
    sta alarm
 
    ; check for alarm, busy wait, highest byte down, assume interrupts off is fine, will wait for any rollover
    lda alarm
-   cmp $A0
    bne -
    lda alarm+1
-   cmp $A1
    bne -
    lda alarm+2
-   cmp $A2
    bne -
    rts

parse_shape_op ; convert token to shape operation mode 0..5
    jsr $0073 ; get next token
    ldx #0
    cmp #$A1 ; GET
    beq +
    inx
    cmp #$D0 ; PUT
    beq +
    inx
    cmp #$B0 ; OR
    beq +
    inx
    cmp #$D1 ; XOR
    beq +
    inx
    cmp #$AF ; AND
    beq +
    inx
    cmp #$A8 ; NOT
    beq +
    cmp #$9C ; CLR synonym for NOT
    beq +
    jmp syntax_error
+   stx param5
    rts

exec_shape
    jsr parse_shape_op
    jsr $0073 ; get next token
    jsr +
    jmp reloop

sys_shape
    ; get mode
    jsr getbytc
    cpx #6
    bcs +++ ; branch if mode out of range
    cmp #$2C
    bne ++
    stx param5
    
    ; get address of shape to get/put
    jsr chkcom
+   jsr frmnum
 	jsr makadr	; convert to integer
    sty $fd
    sta $fe
    
    ; @ param1,param2 = x1/y1 position on screen (left/top of shape)
    ldy #0
    lda ($7a),y
    cmp #$40 ; @
    bne ++
    jsr getbytc
    stx param1
    cmp #$2c ; comma
    bne ++
    jsr getbytc
    stx param2

    ; TO param3,param4 = x2/y2 position on screen (right/bottom of shape)
    cmp #$a4 ; TO token
    bne ++
    jsr getbytc
    stx param3
    cmp #$2c ; comma
    bne ++
    jsr getbytc
    stx param4

    ; validate coordinate parameters
    ; x1 <= x2 < resx
    ; y1 <= y2 < resy
    lda param1
    cmp param3
    beq +
    bcs +++
+   lda param2
    cmp param4
    beq +
    bcs +++
+   lda param3
    cmp resx
    bcs +++
    lda param4
    cmp resy
    bcs +++
    jmp get_put_shape
++  jmp syntax_error
+++ jmp illegal_quantity

; mode GET(0)|PUT(1)|OR(2)|XOR(3)|AND(4)|NOT(5)
get_put_shape ; addr=$fd/$fe (x1,y1)=(param1,param2) (x2,y2)=(param3,param4) mode=param5
    ; load function address into $5e/$5f
    ldx param5
    bne +
    lda #<get_shape_fn
    ldy #>get_shape_fn
    bne ++
+   cpx #6
    bcc +
    jmp +++ ; mode out of range
+   dex
    bne + 
    ; mode PUT(1)
    lda #<put_shape_fn
    ldy #>put_shape_fn
    bne ++
+   dex
    bne + 
    ; mode OR(2)
    lda #<or_shape_fn
    ldy #>or_shape_fn
    bne ++
+   dex
    bne + 
    ; mode XOR(3)
    lda #<xor_shape_fn
    ldy #>xor_shape_fn
    bne ++
+   dex
    bne + 
    ; mode AND(4)
    lda #<and_shape_fn
    ldy #>and_shape_fn
    bne ++
+   ; mode NOT(5)
    lda #<not_shape_fn
    ldy #>not_shape_fn
++  sta $5e
    sty $5f

        ; shift = (X1 AND 7)
    lda param1
    and #7
    sta shift
    sec
    lda #8
    sbc shift
    sta shiftopposite
        ; shmask = 255 >> shift
    ldx shift
    lda ff_rshifted,X
    sta shmask
        ; columns = int((x2+1-(x1 and 248)+7)/8); // screen columns
    lda param1
    and #248
    eor #$ff ; start 1s complement
    sec ; complete 1s complement
    adc #(7+1)
    clc
    adc param3
    lsr
    lsr
    lsr
    sta shcolumns
        ; colnum = 0
    lda #0
    sta shcolnum

        ; ys = y2+1-y1
    lda param4
    clc
    adc #1
    sec
    sbc param2
    sta shys

    ldx param1
    ldy param2
    jsr plot_prep ; $fb/$fc has address based on x, y is untouched
        ; $57/$58 = addr(src)-ys
    sec
    lda $fd
    sbc shys
    sta $57
    lda $fe
    sbc #0
    sta $58
        ; do
        ; {
---
        ;   i = 0
    ldy param2
    sty shbitmapy
        ;   if (columns - colnum = 1) // last column
        ;     mask &= 255 << (~X2 AND 7)
    sec
    lda shcolumns
    sbc shcolnum
    cmp #1
    bne +
    lda param3
    and #7
    tax
    lda ff_lshiftedrev, x
    and shmask
    sta shmask
+
        ;   do
        ;   {
--
        ;     data = (src[i-ys] << (8-shift)) | (src[i] >> shift)
    ldx param5
    beq ++
    lda #0
    tay
    ldx shift ; should be 0..7
    beq +   ; optimize for speed (skips if shiftopposite is 8)
    lda ($57),y
    ldx shiftopposite ; due to optimization, should be 7..1
-   asl
    dex
    bne -
+   sta $59
    lda ($fd),y
    ldx shift
    beq +
-   lsr
    dex
    bne -
+   ora $59
        ;     data &= mask
    and shmask
    sta $59
        ;     dst[i] = (dst[i] & ~mask) | data; // apply operator
++  ldy shbitmapy
    jsr call_shape_fn

        ;     ++dst
    ; destination handled by inc bitmapy
        ;     ++src
    inc $57
    bne +
    inc $58
+   inc $fd
    bne +
    inc $fe
+
        ;   } while (i++ < ys)
    cpy param4
    beq +
    inc shbitmapy
    bne --
+
        ;   shmask = 255
    lda #$ff
    sta shmask
        ;   dst += resy
    clc
    lda $fb
    adc resy
    sta $fb
    bcc +
    inc $fc
+    
        ; } while (++colnum < columns)
    inc shcolnum
    lda shcolnum
    cmp shcolumns
    bcs +++
    jmp ---
+++ rts

call_shape_fn
    jmp ($5e)

get_shape_fn
    lda ($fb),y ; retrieve screen image
    and shmask  ; mask to shape bits to keep
    ldy #0
    ldx shift
    beq ++      ; optimize for speed when no shifting
-   asl
    rol $59
    dex
    bne -
    sta $5c
    ldx shcolnum
    beq +       ; skip if at left column
    ldx shift
    lda $59
    and ff_rshiftedrev, x   ; (1<<(x+1))-1
    sta $59
    lda ff_rshiftedrev, x
    eor #$ff                ; ~((1<<(x+1))-1)
    and ($57),y
    ora $59
    sta ($57),y
+   lda $5c
++  sta ($fd),y
    ldy shbitmapy
    rts

put_shape_fn
        ;     dst[i] = (dst[i] & ~mask) | data
    lda shmask  ; get shape mask
    eor #$ff    ; inverse mask to keep bits outside shape
    and ($fb),y ; retrieve screen outside shape
    ora $59     ; combine with shape image
    sta ($fb),y ; store to screen
    rts

or_shape_fn
        ;     dst[i] |= data
    lda $59     ; get shape image
    ora ($fb),y ; combine with screen
    sta ($fb),y ; store to screen
    rts

xor_shape_fn
        ;     dst[i] ^= data
    lda $59     ; get shape image
    eor ($fb),y ; interact with screen
    sta ($fb),y ; store to screen
    rts

and_shape_fn
        ;    dst[i] &= (~mask | data)
    lda shmask  ; get shape mask
    eor #$ff    ; mask bits outside shape area
    ora $59     ; combine with shape image
    and ($fb),y ; interact with screen
    sta ($fb),y ; store to screen
    rts

not_shape_fn
        ;    dst[i] &= (~mask | ~data)
    lda $59
    eor #$ff
    sta $59
    lda shmask  ; get shape mask
    eor #$ff    ; mask bits outside shape area
    ora $59     ; combine with inverse shape image
    and ($fb),y ; interact with screen
    sta ($fb),y ; store to screen
    rts

; param1/param2 = x/y first corner cell coordinate
; param3/param4 = x/y second corner cell coordinate
; param5 = desired color
; y = columns on screen
rect_color
    sty $58 ; columns on screen
    sec
    lda param3
    sbc param1
    bcs + ; branch if param3 >= param1
    ldx param3 ; reorder x coordinates so param3 > param1
    lda param1
    stx param1
    sta param3
    sec
    sbc param1
+   sta diffx
    lda param4
    sbc param2
    bcs + ; branch if param4 >= param2
    ldx param4 ; reorder y coordinats so param4 > param2
    lda param2
    stx param2
    sta param4
    sec
    sbc param2
+   sta diffy
    ; .x = top/left corner color offset to $9400 = param2 * cols + param1
    tya ; retrieve cols
    ldx param2
    jsr multax
    clc
    adc param1
    bcc +
    inx
+   sta $fb
    txa
    clc
    adc #$94
    sta $fc

    ; fill one row
--  lda param5
    ldy diffx
-   sta ($fb),y
    dey
    bpl -

    ; advance ($fb) pointer one row
    clc
    lda $fb
    adc $58
    sta $fb
    bcc +
    inc $fc
+   dec diffy
    bpl -- ; repeat

    rts

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

switch_text
    lda #22
    sta cols
    lda #23
    sta rows
    lda #(23*8)
    sta resy
    ldx #0
    stx param1
    ldy #0
    sty param2
    jsr switch_graphics
    lda #(23*2)
    sta 36867
    lda #$C0
    sta 36869
    lda 646
    and #7  ; mask out multicolor
    sta 646 ; foreground color
    lda #147 ; clear screen
    jsr chrout
    lda #0
    sta resx
    sta resy
    rts

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
    bne +
    pla ; throw away return address
    pla ;   to return to original caller directly
    jmp switch_text
+   lda #<240*128
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

exec_color
    ; load parameters
    lda 646
    sta param1
    ldx #0
    lda $900F
    lsr
    lsr
    lsr
    lsr
    bcs +
    inx
+   stx param5
    sta param2
    lda $900F
    and #7
    sta param3
    lda $900E
    lsr
    lsr
    lsr
    lsr
    sta param4

    ; if any parameters present, store them over the current values
    jsr exec_five_optional_params_bytes

    ; @ syntax for coloring region?
    cmp #$40
    bne +++ ; no - color jump to color registers
    ; yes @ syntax
    lda param_count
    cmp #1
    beq +
-   jmp syntax_error   
+   lda param1
++  pha
    jsr next_two_bytes
    ; copy param1/2 to param3/4
    ldx param1
    ldy param2
    stx param3
    sty param4
    cmp #$A4 ; TO token
    beq +
    cmp #$00 ; end of statement
    beq ++
    cmp #$3a ; colon - end of statement
    beq ++
    bne -
+   jsr next_two_bytes ; fill param1/2
++  pla
    sta param5
    lda $9003
    and #1
    bne +
    jsr text_color_at
    jmp reloop
+   jsr hires_color_at
    jmp reloop

    ; check and set plot color if necessary
+++ lda plot_color
    bmi + ; plot color not on
    ; plot color on, so stash the forground color
    lda param1
    sta plot_color

+   jsr color
    jmp reloop

color
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

exec_two_params_bytes
    jsr getbytc
    cmp #$2C
    bne ++
    stx param1
    jsr getbytc
    bne ++
    stx param2
    rts
++  jmp syntax_error

next_two_bytes
+   jsr getbytc
    cmp #$2C
    bne ++
    stx param1
    jsr getbytc
    stx param2
    rts
++  jmp syntax_error

exec_five_optional_params_bytes
    ldy #0
    sty param_count
-   jsr commaorbyte
    pha
    inc param_count
    bcc +
    ldy param_count
    cpy #6
    bcs ++
    txa
    sta param1-1, y
+   pla
    cmp #0
    beq +
    cmp #$3a
    beq +
    cmp #$40
    bne -
    beq +
++  jmp syntax_error
+   rts

commaorbyte
        jsr lookahead ; (past comma)
        cmp #$00 ; end of line
        bne +
-       jsr $0073
        clc
        rts
+       cmp #$3a ; colon
        beq -
        cmp #$40 ; @
        beq -
        cmp #$2c ; comma
        bne +
        jsr $0073 ; get token
        bne ++
-       pla
        pla
        jmp syntax_error
++      clc
        ldx #0
        rts
+       jsr getbytc
        beq +
        cmp #$2c ; comma
        beq +
        cmp #$40 ; @
        bne -
+       sec
        rts

string_or_byte
; returns C set: A=len, X/Y=addr of string
; returns C clear: X=value
    jsr frmevl	; evaluate expression
	bit $d		; string or numeric?
	bpl +
    jsr pulstr	; pull string from descriptor stack (a=len, x=lo, y=hi addr of string)
    sec ; string value signal
    bcs ++
+   jsr makadr
    ldx $14
    ldy $15
    beq +
    jmp illegal_quantity
+   clc ; byte value signal
++
    rts

lookahead
        ldy #0
        lda ($7A),y
        beq +		; branch if end of line
    	cmp #$3a	; colon
    	beq +		; branch if end of statement
        lda $7A
        sta ptrl
        lda $7B
        sta ptrh
        jsr $0073
        php
        pha
        lda ptrl
        sta $7A
        lda ptrh
        sta $7B
        pla
        plp
+       rts

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

get_char_addr
    sta $fd
    txa
    pha
    tya
    pha
    lda $fd
    ldx font_bytes
    jsr multax
    clc
    adc font_address
    sta $fd
    txa
    adc font_address+1
    sta $fe
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

basic_error
    pha             ; save only .A for now
    cmp #$81        ; READY
    beq +           ; skip if no error
    lda 36867       ; get size of characters
    and #$01        ; 8x16? hires active?
    beq +           ; branch if not hires
    txa             ; save .X and .Y
    pha
    tya
    pha
    jsr switch_text
    pla             ; restore .Y and .X
    tay
    pla
    tax
+   pla             ; restore .A last
    jmp $c43a       ; IERROR - Print BASIC Error Message Routine

chktoken               ; re-check last token parsed
    ldy #0
    lda ($7A),y
    sec
    beq + ; continue
    cmp #$3a ; colon
+   rts

execute
    jsr $0073 ; get next token (wedge)
    beq loop ; end of line or colon
    bcc loop ; numeric

    cmp #$cc ; HIRES?
    bne +
    jmp exec_hires
+	cmp #$cd ; COLOR?
    bne +
    jmp exec_color
+   cmp #$ce ; PLOT?
	bne +
    jmp exec_plot
+   cmp #$cf ; SHAPE?
    bne +
    jmp exec_shape
+   cmp #$d2 ; PATTERN?
    bne +
    beq +
+   cmp #$d4 ; RECT?
    bne +
    jmp exec_rect
+   cmp #$d5 ; DELAY?
    bne +
    jmp exec_delay
+   cmp #$d6 ; TEXT?
    bne +
    jmp exec_text
+   sec ; non-numeric
        ; not one of ours, continue with ROM processing
loop    
    jmp $c7e7 ; handle token

reloop  
    jsr chktoken ; verify next token is end of statement
    beq loop        
    jmp syntax_error ; syntax error

patch_table
!byte 0x37, <crunch_start, >crunch_start
!byte 0x40, <crunch_sbc, >crunch_sbc
!byte 0x7e, <crunch_get, >crunch_get
!byte 0x83, <crunch_next, >crunch_next
!byte 0

crunch_patch
        ldy #0
-       lda $c57c,y
        sta hires_crunch,y
        iny
        cpy #$97
        bne -

        ldy #0
-       lda patch_table,y
        beq +
        tax
        lda #$20 ; JSR opcode
        sta hires_crunch,x
        inx
        iny
        lda patch_table,y
        sta hires_crunch,x
        inx
        iny
        lda patch_table,y
        sta hires_crunch,x
        iny
        bne -
+       rts

crunch_start:
        lda #<$C09E	; point to original BASIC tokens, low byte
        sta ptrl
        lda #>$C09E	; point to original BASIC tokens, high byte
        sta ptrh
        STX $7A
        DEX
        rts
crunch_get:		; retrieves character from token table, looking back one index
        dey
        lda (ptrl),y
        iny
        ora #$00 ; restore N based on A (caller will BPL next)
        rts
crunch_next:
        cpy #$FF ; are we at the end of the last token in the first table?
        bne + ; no
        lda #<tokens1 ; update low pointer to next table
        sta ptrl
        lda #>tokens1 ; update high pointer to next table
        sta ptrh
        iny ; reset index to zero, start of second token table
+       lda (ptrl),y        
        rts
crunch_sbc:
        sbc (ptrl),y
        rts

list_tokens
        bit $0F   ; quoted?
        bmi +     ; if yes, handle normally in ROM
        cmp #$cc  ; compare to our first token value
        bcc +     ; skip token if less than ours
        cmp #$d8  ; compare past our last token value
        bcc ++    ; branch if our token
+       ora #$00  ; reset Z flag for zero value
        jmp $c71a ; process other token standard QPLOP
++      sty $49   ; save index
        ldy #0
        sec
        sbc #$cc
        tax
        beq +
-       lda tokens1,y
        iny
        ora #0
        bpl -
        dex
        bne -
-
+       lda tokens1,y
        bmi +
        jsr listchr
        iny
        jmp -
+       and #$7f
        jsr listchr ; output character
        ldy $49   ; restore index
        jmp $c700 ; retrieve next token

        ; Vic-20 tokens are C09E-C19D
tokens1 
    !text "HIRE"            ; CC
        !byte "S" OR $80
    !text "COLO"            ; CD
        !byte "R" OR $80
    !text "PLO"             ; CE
       !byte "T" OR $80
    !text "SHAP"            ; CF
        !byte "E" OR $80
    !text "PU"              ; D0
      !byte "T" OR $80
    !text "XO"              ; D1
      !byte "R" OR $80
    !text "PATTER"          ; D2
       !byte "N" OR $80
    !text "SWA"             ; D3
       !byte "P" OR $80
    !text "REC"             ; D4
       !byte "T" OR $80
    !text "DELA"            ; D5
       !byte "Y" OR $80
    !text "TEX"             ; D6
       !byte "T" OR $80
    !text "OF"              ; D7
       !byte "F" OR $80
    !byte 0                 ; end of table

hires_crunch ; will be copy/patch of Vic-20 BASIC crunch from C57C-C612
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0

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
param_count !byte 0

rectx1 !byte 0
recty1 !byte 0
rectx2 !byte 0
recty2 !byte 0
rectdrawcolor !byte 0 ; 0/1/2/3 for multicolor, 0 for hires draw, 255 for hires undraw
rectdrawparams !byte 0 ; param4 for line draw 3=hires draw, 4=multicolor or hires undraw

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
plot_mode !byte 0 ; multi-color 0,1,2,3, or inverse ($FF) or normal ($80)

strlen !byte 0
charrvs !byte 0

alarm !byte 0,0,0

shwidth !byte 0
shheight !byte 0
shift !byte 0
shiftopposite !byte 0
shmask !byte 0
shys !byte 0
shbitmapy !byte 0
shcolumns !byte 0
shcolnum !byte 0

pow7_x !byte 128, 64, 32, 16, 8, 4, 2, 1
ff_rshifted !byte 255, 127, 63, 31, 15, 7, 3, 1
ff_lshiftedrev !byte 128,192,224,240,248,252,254,255
ff_rshiftedrev !byte 0, 1, 3, 7, 15, 31, 63, 127, 255

mbit_x 
!byte 0, 0, 0, 0 ; bits 00
!byte 64, 16, 4, 1 ; bits 01
!byte 128, 32, 8, 2 ; bits 10
!byte 192, 48, 12, 3 ; bits 11

plot_point_vector
!byte 0, 0

font_address !byte $00, $80
font_bytes !byte 8
font_width !byte 8
font_height !byte 8

finis
