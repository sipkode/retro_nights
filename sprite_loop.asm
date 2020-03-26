.include "settings.inc"
.include "constants.inc"

.bank 0, 16, $c000, "NES_PRG0"
.segment "Code"
.org $C000 

.function irq_handler
    RTI
.endfunction

; zero-page Variable Declarations
BUTTONS = $00
YPOS    = $01
XPOS    = $02

.function move_sprites
    LDX #$00

move_sprites_loop:
    LDA sprites, x
    ADC YPOS
    STA $0200, x
    INX
    INX
    INX
    LDA sprites, x
    ADC XPOS
    STA $0200, x
    INX
    CPX #$10
    BNE move_sprites_loop

    LDA #%10010000
    STA PPUCTRL
    LDA #%00011110
    STA PPUMASK
    RTS
.endfunction

.function nmi_handler
    LDA #$00
    STA OAMADDR
    LDA #$02
    STA OAMDMA

reset_controllers:
    LDA #$01
    STA CTRLRST
    LDA #$00
    STA CTRLRST

read_controllers:
    ; A, B, Select, Start, Up, Down, Left, Right
    LDX #$00                ; x = i
    LDA #$01                ; A = bitmask
    STA BUTTONS

read_controller_loop:
    LDA CONTROL1
    LSR A                   ; bit 0 -> Carry   
    ROL BUTTONS             ; Carry -> bit 0; bit 7 -> Carry
    BCC read_controller_loop

    LDA BUTTONS
    AND #PAD_UP
    BEQ not_up
    ; Up pressed
    DEC YPOS
not_up:
    LDA BUTTONS
    AND #PAD_DOWN
    BEQ not_down
    ; Down pressed
    INC YPOS
not_down:
    LDA BUTTONS
    AND #PAD_LEFT
    BEQ not_left
    ; Left pressed
    DEC XPOS
not_left:
    LDA BUTTONS
    AND #PAD_RIGHT
    BEQ not_right
    ; Right pressed
    INC XPOS
not_right: 
    move_sprites()
    RTI
.endfunction

.function reset_handler
    SEI
    CLD
    LDX #$00
    STX PPUCTRL
    STX PPUMASK

vblankwait:
    BIT PPUSTATUS
    BPL vblankwait

clrmem:
    LDA #$00
    STA $0000, x
    STA $0100, x
    STA $0300, x
    STA $0400, x
    STA $0500, x
    STA $0600, x
    STA $0700, x
    LDA #$FE
    STA $0200, x            ;move all sprites off screen
    INX
    BNE clrmem

init_vars:
    LDA #$70
    STA YPOS
    STA XPOS
   
vblankwait2:                ; Second wait for vblank, PPU is ready after this
    BIT PPUSTATUS
    BPL vblankwait2

    JMP main
.endfunction

.function main
    LDX PPUSTATUS		    ; Reset PPUADDR
    LDX #$3f			    ; Write to PPUADDR
    STX PPUADDR
    LDX #$00
    STX PPUADDR
    
load_palettes_loop:
    LDA palette, x          ;load palette byte
    STA PPUDATA             ;write to PPU
    INX                     ;set index to next byte
    CPX #$20            
    BNE load_palettes_loop  ;if x = $20, 32 bytes copied, all done

load_sprite_data:
    LDX #$00

load_sprites_loop:
    LDA sprites, x
    STA $0200, x
    INX
    CPX #$10
    BNE load_sprites_loop

    ;move_sprites()

    LDA #%10010000
    STA PPUCTRL
    LDA #%00011110
    STA PPUMASK

forever:
    JMP forever
    
.endfunction

.segment "Palette"
.org $E000
palette:
    .byte $0F,$31,$32,$33,$0F,$35,$36,$37,$0F,$39,$3A,$3B,$0F,$3D,$3E,$0F
    .byte $0F,$2C,$25,$24,$0F,$02,$38,$3C,$0F,$1C,$15,$14,$0F,$02,$38,$3C

.segment "Sprites"
.org $E100
sprites:
    .byte $00,$05,$00,$00,$00,$06,$00,$08,$08,$07,$00,$00,$08,$08,$00,$08

.segment "Vectors"
.org $FFFA     		        ;first of the three vectors starts here

.word nmi_handler           ;when an NMI happens (once per frame if enabled) the 
                 	        ;processor will jump to the label NMI:
.word reset_handler         ;when the processor first turns on or is reset, it will jump
                 	        ;to the label RESET:
.word irq_handler           ;external interrupt IRQ is not used in this tutorial

.bank 1, 8, $0000, "NES_CHR0"
.segment "Chr"
.org $0000 
.incbin "graphics.chr"