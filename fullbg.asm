.include "settings.inc"
.include "constants.inc"

.bank 0, 16, $c000, "NES_PRG0"

;;;;;;;;;;;;;;  

.segment "ROData"
.org $E000
palette:
    .byte $22,$29,$1a,$0f,  $22,$36,$17,$0f,  $22,$30,$21,$0f,  $22,$27,$17,$0f   ;;background palette
    .byte $0F,$2C,$25,$24,  $0F,$02,$38,$3C,  $0F,$1C,$15,$14,  $0F,$02,$38,$3C   ;;sprite palette
end_palette:
    s_palette = (end_palette - palette)

rosprites:
    ;vert tile attr horiz
    .byte $80, $32, $00, $80   ;sprite 0
    .byte $80, $33, $00, $88   ;sprite 1
    .byte $88, $34, $00, $80   ;sprite 2
    .byte $88, $35, $00, $88   ;sprite 3
end_rosprites:
    s_rosprites = (end_rosprites - rosprites)

background:

    .storage $20, $24  ;;row 1, all sky -- This row is discarded

    .byte $24, $f4, $f6, $f6, $f6, $f6, $f6, $f6, $f6, $f6, $f7, $24, $24, $24, $24, $24, $24, $24, $24, $24, $24, $24, $24, $24, $24, $24, $24, $24, $24, $24, $24, $24
    .byte $24, $f8, $1c, $1e, $19, $24, $1d, $12, $16, $2b, $f8, $24, $24, $24, $24, $24, $24, $24, $24, $24, $24, $24, $24, $24, $24, $24, $24, $24, $24, $24, $24, $24
    .byte $24, $f8, $24, $24, $24, $24, $24, $24, $24, $24, $f8, $24, $24, $24, $24, $24, $24, $24, $24, $24, $24, $24, $24, $24, $24, $24, $24, $24, $24, $24, $24, $24  
    .byte $24, $f8, $24, $24, $24, $24, $24, $24, $fd, $fe, $f8, $24, $24, $24, $24, $24, $24, $24, $24, $24, $24, $24, $24, $24, $24, $24, $24, $24, $24, $24, $24, $24
    .byte $24, $f8, $24, $24, $24, $24, $24, $24, $24, $24, $f8, $24, $24, $24, $24, $24, $24, $24, $24, $24, $24, $24, $24, $24, $24, $24, $24, $24, $24, $24, $24, $24
    .byte $24, $f5, $f6, $f6, $f6, $f6, $f6, $f6, $f6, $f6, $f9, $24, $24, $24, $24, $24, $24, $24, $24, $24, $24, $24, $24, $24, $24, $24, $24, $24, $24, $24, $24, $24

    ;.storage $F0, $24

end_background:
    s_background = (end_background - background)

attribute:
    .byte %00000000, %00010000, %01010000, %00010000, %00000000, %00000000, %00000000, %00110000
end_attribute:
    s_attribute = (end_attribute - attribute)

bg_addr_lo .lobyte background
bg_addr_hi .hibyte background

;;;;;;;;;;;;;;  

.segment "Code"
.org $C000 

; Zero page data
p_lo = $00
p_hi = $01

.function IRQ
    RTI
.endfunction

.function VBLANKWAIT
    BIT PPUSTATUS
    BPL VBLANKWAIT
.endfunction

.function LOAD_BG
    LDA #%10010000          ; enable nmi, sprites from pattern table 0, background from pattern table 1
    STA PPUCTRL

    LDA bg_addr_lo
    STA p_lo
    LDA bg_addr_hi
    STA p_hi

    LDA PPUSTATUS           ; read ppu status to reset the high/low latch
    LDA #$20    
    STA PPUADDR             ; write the high byte of $2000 address
    LDA #$00    
    STA PPUADDR             ; write the low byte of $2000 address
    LDX #$00                
    LDY #$00                ; start out at 0, 0

loadbgloop:
loadlineloop:   
    LDA (p_lo), y           ; load data from address (background + the value in y)
    STA PPUDATA             ; write to ppu
    INY                     ; y = y + 1
    CPY #$00                ; compare y to background size
    BNE loadlineloop        ; repeat until all bytes copied on this line

    INC p_hi
    INX
    CPX #$04
    BNE loadbgloop
    
.endfunction

.function RESET
    SEI          ; disable IRQs
    CLD          ; disable decimal mode
    LDX #$40
    STX APUIRQ   ; disable APU frame IRQ
    LDX #$FF
    TXS          ; Set up stack
    INX          ; now X = 0
    STX PPUCTRL  ; disable NMI
    STX PPUMASK  ; disable rendering
    STX DPMCIRQ  ; disable DMC IRQs

    VBLANKWAIT()

clrmem:
    LDA #$00
    STA $0000, x
    STA $0100, x
    STA $0200, x
    STA $0400, x
    STA $0500, x
    STA $0600, x
    STA $0700, x
    LDA #$FE
    STA $0300, x
    INX
    BNE clrmem
   
    VBLANKWAIT()      ; Second wait for vblank, PPU is ready after this

loadpalettes:
    LDA PPUSTATUS         ; read ppu status to reset the high/low latch
    LDA #$3f
    STA PPUADDR           ; write the high byte of $3f00 address
    LDA #$00
    STA PPUADDR           ; write the low byte of $3f00 address
    LDX #$00              ; start out at 0
loadpalettesloop:
    LDA palette, x        ; load data from address (palette + the value in x)
    STA PPUDATA           ; write to ppu
    INX                   ; x = x + 1
    CPX #s_palette        ; compare x to palette size
    BNE loadpalettesloop  ; repeat until all bytes loaded

    LOAD_BG()
              
loadattribute:
    LDA PPUSTATUS         ; read ppu status to reset the high/low latch
    LDA #$23
    STA PPUADDR           ; write the high byte of $23c0 address
    LDA #$c0
    STA PPUADDR           ; write the low byte of $23c0 address
    LDX #$00              ; start out at 0
loadattributeloop:
    LDA attribute, x      ; load data from address (attribute + the value in x)
    STA PPUDATA           ; write to ppu
    INX                   ; x = x + 1
    CPX #s_attribute      ; compare x to hex $08, decimal 8 - copying 8 bytes
    BNE loadattributeloop ; branch to loadattributeloop if compare was not equal to zero
                          ; if compare was equal to 128, keep going down

    LDA #%10010000   ; enable nmi, sprites from pattern table 0, background from pattern table 1
    STA PPUCTRL

    LDA #%00011110   ; enable sprites, enable background, no clipping on left side
    STA PPUMASK

    LDA #$00        ;;tell the ppu there is no background scrolling
    STA PPUSCROLL
    sta PPUSCROLL

forever:
    JMP forever     ;jump back to forever, infinite loop
.endfunction

.function NMI
    LDA #$00
    STA OAMADDR       ; set the low byte (00) of the ram address
    LDA #$02
    STA OAMDMA       ; set the high byte (02) of the ram address, start the transfer

    LDA #%10010000   ; enable nmi, sprites from pattern table 0, background from pattern table 1
    STA PPUCTRL
    LDA #%00011110   ; enable sprites, enable background, no clipping on left side
    STA PPUMASK
    LDA #$00        ;;tell the ppu there is no background scrolling
    STA PPUSCROLL
    STA PPUSCROLL

    RTI
.endfunction

;;;;;;;;;;;;;;  
  
;.bank 1, 16, $FFFA, "NES_PRG1"
.segment "Vectors"
.org $FFFA     ;first of the three vectors starts here
.word NMI        ;when an NMI happens (once per frame if enabled) the 
                 ;processor will jump to the label NMI:
.word RESET      ;when the processor first turns on or is reset, it will jump
                 ;to the label RESET:
.word IRQ        ;external interrupt IRQ is not used in this tutorial
  
;;;;;;;;;;;;;;  

.bank 1, 8, $0000, "NES_CHR0"
.segment "Chr"
.org $0000
.incbin "mario.chr"   ;includes 8KB graphics file from SMB1