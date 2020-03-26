.include "settings.inc"
.include "constants.inc"

.bank 0, 16, $c000, "NES_PRG0"
.segment "Code"
.org $C000 

.function IRQ
    RTI
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

vblankwait1:       ; First wait for vblank to make sure PPU is ready
    BIT PPUSTATUS
    BPL vblankwait1

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
   
vblankwait2:      ; Second wait for vblank, PPU is ready after this
    BIT PPUSTATUS
    BPL vblankwait2

    LDA #%00011110   ;intensify blues
    STA PPUMASK

loadpalettes:
    LDA PPUSTATUS         ; read ppu status to reset the high/low latch
    LDA #$3f
    STA PPUADDR           ; write the high byte of $3f00 address
    LDA #$00
    STA PPUADDR           ; write the low byte of $3f00 address
    LDX #$00              ; start out at 0
loadpalettesloop:
    LDA palette, x        ; load data from address (palette + the value in x)
                          ; 1st time through loop it will load palette+0
                          ; 2nd time through loop it will load palette+1
                          ; 3rd time through loop it will load palette+2
                          ; etc
    STA PPUDATA           ; write to ppu
    INX                   ; x = x + 1
    CPX #s_palette        ; compare x to hex $10, decimal 16 - copying 16 bytes = 4 sprites
    BNE loadpalettesloop  ; branch to loadpalettesloop if compare was not equal to zero
                          ; if compare was equal to 32, keep going down

loadbackground:
    LDA PPUSTATUS         ; read ppu status to reset the high/low latch
    LDA #$20
    STA PPUADDR           ; write the high byte of $2000 address
    LDA #$00
    STA PPUADDR           ; write the low byte of $2000 address
    LDX #$00              ; start out at 0
loadbackgroundloop:
    LDA background, x     ; load data from address (background + the value in x)
    STA PPUDATA           ; write to ppu
    INX                   ; x = x + 1
    CPX #s_background     ; compare x to hex $80, decimal 128 - copying 128 bytes
    BNE loadbackgroundloop; branch to loadbackgroundloop if compare was not equal to zero
                          ; if compare was equal to 128, keep going down
              
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

forever:
    JMP forever     ;jump back to forever, infinite loop
.endfunction

.function NMI
    LDA #$00
    STA OAMADDR       ; set the low byte (00) of the ram address
    LDA #$02
    STA OAMDMA       ; set the high byte (02) of the ram address, start the transfer

    RTI
.endfunction

;;;;;;;;;;;;;;  

.segment "ROData"
.org $E000
palette:
    .byte $22,$29,$1a,$0f,  $22,$36,$17,$0f,  $22,$30,$21,$0f,  $22,$27,$17,$0f   ;;background palette
    .byte $22,$1c,$15,$14,  $22,$02,$38,$3c,  $22,$1c,$15,$14,  $22,$02,$38,$3c   ;;sprite palette
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
    sky = $24
    bricktop = $45
    brickbottom = $47
    qblock = $53
    .storage $20, sky  ;;row 1, all sky
    .storage $20, sky  ;;row 2, all sky

    .byte sky,sky,sky,sky,bricktop,bricktop,sky,sky
    .byte bricktop,bricktop,bricktop,bricktop,bricktop,bricktop,sky,sky  ;;row 3
    .byte sky,sky,sky,sky,sky,sky,sky,sky
    .byte sky,sky,sky,sky,qblock,qblock+1,sky,sky  ;;some brick tops
    
    .byte sky,sky,sky,sky,brickbottom,brickbottom,sky,sky
    .byte brickbottom,brickbottom,brickbottom,brickbottom,brickbottom,brickbottom,sky,sky  ;;row 4
    .byte sky,sky,sky,sky,sky,sky,sky,sky
    .byte sky,sky,sky,sky,qblock+2,qblock+3,sky,sky  ;;brick bottoms

end_background:
    s_background = (end_background - background)

attribute:
    .byte %00000000, %00010000, %01010000, %00010000, %00000000, %00000000, %00000000, %00110000
end_attribute:
    s_attribute = (end_attribute - attribute)

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