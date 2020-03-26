.include "settings.inc"
.include "constants.inc"

.bank 0, 16, $c000, "NES_PRG0"
.segment "Code"
.org $C000 

.function irq_handler
    RTI
.endfunction

.function nmi_handler
    LDA #$00
    STA OAMADDR
    LDA #$02
    STA OAMDMA
    RTI
.endfunction

.function reset_handler
    ;SEI
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
    
LoadPalettesLoop:
    LDA palette, x          ;load palette byte
    STA PPUDATA             ;write to PPU
    INX                     ;set index to next byte
    CPX #$20            
    BNE LoadPalettesLoop    ;if x = $20, 32 bytes copied, all done

    ; Segment 0
    LDA #$70                ; y-coord of sprite
    STA $0200   
    LDA #$05                ; index of sprite
    STA $0201   
    LDA #$00                ; sprite attributes
    STA $0202   
    LDA #$80                ; x-coord of sprite
    STA $0203   
    ; Segment 1 
    LDA #$70                ; y-coord of sprite
    STA $0204   
    LDA #$06                ; index of sprite
    STA $0205   
    LDA #$00                ; sprite attributes
    STA $0206   
    LDA #$88                ; x-coord of sprite
    STA $0207   
    ; Segment 2 
    LDA #$78                ; y-coord of sprite
    STA $0208   
    LDA #$07                ; index of sprite
    STA $0209   
    LDA #$00                ; sprite attributes
    STA $020A   
    LDA #$80                ; x-coord of sprite
    STA $020B   
    ; Segment 3 
    LDA #$78                ; y-coord of sprite
    STA $020C   
    LDA #$08                ; index of sprite
    STA $020D   
    LDA #$00                ; sprite attributes
    STA $020E   
    LDA #$88                ; x-coord of sprite
    STA $020F   

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
    .byte $0F,$1C,$15,$14,$0F,$02,$38,$3C,$0F,$1C,$15,$14,$0F,$02,$38,$3C

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