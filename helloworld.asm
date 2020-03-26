.include "settings.inc"
.include "constants.inc"

.bank 0, 16, $c000, "NES_PRG0"
.segment "Code"
.org $C000 

.function irq_handler
  RTI
.endfunction

.function nmi_handler
  RTI
.endfunction

.function reset_handler
  SEI
  CLD
  LDX #$00
  STX $2000
  STX $2001
vblankwait:
  BIT $2002
  BPL vblankwait
  JMP main
.endfunction

.function main
  LDX PPUSTATUS
  LDX #$3f
  STX PPUADDR
  LDX #$00
  STX PPUADDR
  LDA #$25
  STA PPUDATA
  LDA #%00111110
  STA PPUMASK
forever:
  JMP forever
.endfunction

.segment "Vectors"
.org $FFFA     		;first of the three vectors starts here

.word nmi_handler   ;when an NMI happens (once per frame if enabled) the 
                 	;processor will jump to the label NMI:
.word reset_handler ;when the processor first turns on or is reset, it will jump
                 	;to the label RESET:
.word irq_handler   ;external interrupt IRQ is not used in this tutorial