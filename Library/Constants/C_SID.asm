.namespace SID {
// ++++ VOICE #1 -------------------------------------------------------------------------------------------------------
    .label _FRELO1       	= $D400 	// Frequency voice 1 low byte (Write Only)
    .label _FREHI1       	= $D401 	// Frequency voice 1 high byte (Write Only)
    .label _PWLO1        	= $D402 	// Pulse wave duty cycle voice 1 low byte 7..4 3..0 (Write Only)
    .label _PWHI1        	= $D403 	// Pulse wave duty cycle voice 1 high byte (Write Only)
    .label _VCREG1       	= $D404 	// Control register voice 1 (Write Only)
										/*	Bit #0: 0 = Voice off, Release cycle; 1 = Voice on, Attack-Decay-Sustain cycle.
											Bit #1: 1 = Synchronization enabled (With Voice 3).
											Bit #2: 1 = Ring modulation enabled (with Voice 3).
											Bit #3: 1 = Disable voice, reset noise generator.
											Bit #4: 1 = Triangle waveform enabled.
											Bit #5: 1 = Saw waveform enabled.
											Bit #6: 1 = Rectangle waveform enabled.
											Bit #7: 1 = Noise enabled. */
    .label _ATDCY1       	= $D405 	// Attack duration decay duration voice 1 (Write Only)
										/*	Bits #0-#3: Decay length. Values:
											%0000, 0: 6 ms.
											%0001, 1: 24 ms.
											%0010, 2: 48 ms.
											%0011, 3: 72 ms.
											%0100, 4: 114 ms.
											%0101, 5: 168 ms.
											%0110, 6: 204 ms.
											%0111, 7: 240 ms.
											%1000, 8: 300 ms.
											%1001, 9: 750 ms.
											%1010, 10: 1.5 s.
											%1011, 11: 2.4 s.
											%1100, 12: 3 s.
											%1101, 13: 9 s.
											%1110, 14: 15 s.
											%1111, 15: 24 s.
											Bits #4-#7: Attack length. Values:
											%0000, 0: 2 ms.
											%0001, 1: 8 ms.
											%0010, 2: 16 ms.
											%0011, 3: 24 ms.
											%0100, 4: 38 ms.
											%0101, 5: 56 ms.
											%0110, 6: 68 ms.
											%0111, 7: 80 ms.
											%1000, 8: 100 ms.
											%1001, 9: 250 ms.
											%1010, 10: 500 ms.
											%1011, 11: 800 ms.
											%1100, 12: 1 s.
											%1101, 13: 3 s.
											%1110, 14: 5 s.
											%1111, 15: 8 s.	*/
    .label _SUREL1       	= $D406 	// Sustain level release duration voice 1 (Write Only)
										/*	Bits #0-#3: Release length. Values:
											%0000, 0: 6 ms.
											%0001, 1: 24 ms.
											%0010, 2: 48 ms.
											%0011, 3: 72 ms.
											%0100, 4: 114 ms.
											%0101, 5: 168 ms.
											%0110, 6: 204 ms.
											%0111, 7: 240 ms.
											%1000, 8: 300 ms.
											%1001, 9: 750 ms.
											%1010, 10: 1.5 s.
											%1011, 11: 2.4 s.
											%1100, 12: 3 s.
											%1101, 13: 9 s.
											%1110, 14: 15 s.
											%1111, 15: 24 s.
											Bits #4-#7: Sustain volume. */

// ++++ VOICE #2 -------------------------------------------------------------------------------------------------------
    .label _FRELO2       	= $D407 	// Frequency voice 2 low byte
    .label _FREHI2       	= $D408 	// Frequency voice 2 high byte
    .label _PWLO2        	= $D409 	// Pulse wave duty cycle voice 2 low byte
    .label _PWHI2        	= $D40A 	// Pulse wave duty cycle voice 2 high byte
    .label _VCREG2       	= $D40B 	// Control register voice 2
    .label _ATDCY2       	= $D40C 	// Attack duration decay duration voice 2
    .label _SUREL2       	= $D40D 	// Sustain level release duration voice 2

// ++++ VOICE #3 -------------------------------------------------------------------------------------------------------
    .label _FRELO3       	= $D40E 	// Frequency voice 3 low byte
    .label _FREHI3       	= $D40F 	// Frequency voice 3 high byte
    .label _PWLO3        	= $D410 	// Pulse wave duty cycle voice 3 low byte
    .label _PWHI3        	= $D411 	// Pulse wave duty cycle voice 3 high byte
    .label _VCREG3       	= $D412 	// Control register voice 3
    .label _ATDCY3       	= $D413 	// Attack duration decay duration voice 3
    .label _SUREL3       	= $D414 	// Sustain level release duration voice 3


    .label _CUTLO        	= $D415 	// Filter cutoff frequency low byte
    .label _CUTHI        	= $D416 	// Filter cutoff frequency high byte
    .label _RESON        	= $D417 	// Filter resonance and routing
										/*	Bit #0: 1 = Voice #1 filtered.
											Bit #1: 1 = Voice #2 filtered.
											Bit #2: 1 = Voice #3 filtered.
											Bit #3: 1 = External voice filtered.
											Bits #4-#7: Filter resonance. */
    .label _SIGVOL       	= $D418 	// Filter mode and main volume control
										/*	Bits #0-#3: Volume.
											Bit #4: 1 = Low pass filter enabled.
											Bit #5: 1 = Band pass filter enabled.
											Bit #6: 1 = High pass filter enabled.
											Bit #7: 1 = Voice #3 disabled. */
	.label _POTX         	= $D419 	// Read game paddle 1 (or 3) position
	.label _POTY         	= $D41A 	// Read game paddle 2 (or 4) position
    .label _RANDOM       	= $D41B 	// Oscillator voice 3 (read only)
    .label _ENV3         	= $D41C 	// Envelope voice 3 (read only)

/*
	FreqTablePalLo:
	             	   C   C#  D   D#  E   F   F#  G   G#  A   A#  B
                .byte $16,$27,$39,$4b,$5f,$74,$8a,$a1,$ba,$d4,$f0,$0e  // 0
                .byte $2d,$4e,$71,$96,$be,$e7,$14,$42,$74,$a9,$e0,$1b  // 1
                .byte $5a,$9c,$e2,$2d,$7b,$cf,$27,$85,$e8,$51,$c1,$37  // 2
                .byte $b4,$38,$c4,$59,$f7,$9d,$4e,$0a,$d0,$a2,$81,$6d  // 3
                .byte $67,$70,$89,$b2,$ed,$3b,$9c,$13,$a0,$45,$02,$da  // 4
                .byte $ce,$e0,$11,$64,$da,$76,$39,$26,$40,$89,$04,$b4  // 5
                .byte $9c,$c0,$23,$c8,$b4,$eb,$72,$4c,$80,$12,$08,$68  // 6
                .byte $39,$80,$45,$90,$68,$d6,$e3,$99,$00,$24,$10,$ff  // 7

	FreqTablePalHi:
				       C   C#  D   D#  E   F   F#  G   G#  A   A#  B
                .byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$02  // 0
                .byte $02,$02,$02,$02,$02,$02,$03,$03,$03,$03,$03,$04  // 1
                .byte $04,$04,$04,$05,$05,$05,$06,$06,$06,$07,$07,$08  // 2
                .byte $08,$09,$09,$0a,$0a,$0b,$0c,$0d,$0d,$0e,$0f,$10  // 3
                .byte $11,$12,$13,$14,$15,$17,$18,$1a,$1b,$1d,$1f,$20  // 4
                .byte $22,$24,$27,$29,$2b,$2e,$31,$34,$37,$3a,$3e,$41  // 5
                .byte $45,$49,$4e,$52,$57,$5c,$62,$68,$6e,$75,$7c,$83  // 6
                .byte $8b,$93,$9c,$a5,$af,$b9,$c4,$d0,$dd,$ea,$f8,$ff  // 7


SID-ADR-Table:

     VALUE    ATTACK    DECAY/RELEASE
   +-------+----------+---------------+
   |   0   |    2 ms  |      6 ms     |
   |   1   |    8 ms  |     24 ms     |
   |   2   |   16 ms  |     48 ms     |
   |   3   |   24 ms  |     72 ms     |
   |   4   |   38 ms  |    114 ms     |
   |   5   |   56 ms  |    168 ms     |
   |   6   |   68 ms  |    204 ms     |
   |   7   |   80 ms  |    240 ms     |
   |   8   |  100 ms  |    300 ms     |
   |   9   |  240 ms  |    720 ms     |
   |   A   |  500 ms  |    1.5 s      |
   |   B   |  800 ms  |    2.4 s      |
   |   C   |    1 s   |      3 s      |
   |   D   |    3 s   |      9 s      |
   |   E   |    5 s   |     15 s      |
   |   F   |    8 s   |     24 s      |
   +-------+----------+---------------+



*/

}