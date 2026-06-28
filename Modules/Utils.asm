.namespace UTILS {

	.pc = * "Utils Data"
    Data: {
		J1Up:           .byte $00			// Byte holds historic data of button press. Each bit = press
		J1Down:         .byte $00			// Runs from Bit #7 newest to Bit #0 Oldest
		J1Left:         .byte $00			// Use bmi/bpl and bvc/bvs to check Bits #7, #6
		J1Right:        .byte $00
		J1Fire:         .byte $00 

		J2Up:           .byte $00
		J2Down:         .byte $00
		J2Left:         .byte $00
		J2Right:        .byte $00
		J2Fire:         .byte $00 
    }

	.pc = * "Utils ClearScreen"
    ClearScreen: {
        // A carries the character value to clear the screen with
			ldx #250
		!CS:
			sta VIC._SCREEN_RAM -1 + 000, x
			sta VIC._SCREEN_RAM -1 + 250, x
			sta VIC._SCREEN_RAM -1 + 500, x
			sta VIC._SCREEN_RAM -1 + 750, x
			dex
			bne !CS-
			rts                          
        }

	.pc = * "Utils ClearColour"
    ClearCharCol: {
        // A carries the colour value to clear the colour map with
			ldx #250
		!CC:
			sta VIC._COLOUR_RAM -1 + 000, x
			sta VIC._COLOUR_RAM -1 + 250, x
			sta VIC._COLOUR_RAM -1 + 500, x
			sta VIC._COLOUR_RAM -1 + 750, x
			dex
			bne !CC-
			rts    
    }

	* = * "Utils GetJoy1"
    GetJoy1: {
			lda CIA._CIAPRB                	// Read joystick port 1.  Pressed = 0, Not pressed = 1
			lsr								// Shift right
			ror Data.J1Up                   // Rotate in carry to UP
			lsr								// Repeat for each direction
			ror Data.J1Down					// Each byte contains a history of up to 8 button presses
			lsr								// Use BMI for latest press// BVC for previous press
			ror Data.J1Left 				// Switch history = switch history/2 + 128 * current switch state
			lsr
			ror Data.J1Right
			lsr
			ror Data.J1Fire
			rts
    }

	* = * "Utils GetJoy2"
    GetJoy2: {
			lda CIA._CIAPRA                  // Read joystick port 2
			lsr								// Shift right
			ror Data.J2Up                   // Rotate in carry to UP
			lsr								// Repeat for each direction
			ror Data.J2Down					// Each byte contains a history of up to 8 button presses
			lsr								// Use BMI for latest press// BVC for previous press
			ror Data.J2Left 				// Switch history = switch history/2 + 128 * current switch state
			lsr
			ror Data.J2Right
			lsr
			ror Data.J2Fire
			rts
    }

	.pc = * "Utils RNG"
    Random: {
        Initialise: {
				lda #$13				// 00010011
				sta CIA._TIMALO          // Set Timer Start Value
				lda #$FF                // 11111111
				sta CIA._TIMAHI          // Set Timer Start Value
				lda #$91                // 10010001
				sta CIA._CIACRA          // Bit #7 Set 50Hz// Bit #4 Load start value into timer// Bit #0 Start Timer A
				rts
        }

        Get: {
				// random value is stored in Seed - Value between 0 and 255
				lda Seed: #$64         	// (2) Get the Seed value
				beq !doEor+             // (3)/(2) Branch if equal zero
				asl                     // (2) Multiply by 2 
				beq !noEor+             // (3)/(2) Branch if equal zero
				bcc !noEor+             // (3)/(2) Branch if carry clear
			!doEor:
				eor #$1D                // (2) 
			!noEor:
				sta Seed                // (4)
				eor CIA._TIMALO          // (4)
				rts                     // (19 Minimum)  (24 Maximum)
				// EOR Masks that produce 256 values in a chain.
				// $1d (29),$2b (43),$2d (45),$4d (77),$5f (95),$63 (99),$65 (101),$69 (105)
				// $71 (113),$87 (135),$8d (141),$a9 (169),$c3 (195),$cf (207),$e7 (231),$f5 (245)
        }
    }

	.pc = * "Utils Char to Char Address"
	Char2CharAddr: {
			// Takes char index in A
			// Returns its font data addr as Y(LSB) A(MSB)
			sta LSB
			lda #$00
			asl LSB
			rol
			asl LSB
			rol
			asl LSB
			rol
			clc
			adc MSB: #$BEEF				// MSB of Target Address. Set this value prior to entering Function.
			ldy LSB: #$BEEF				// LSB of Target Address
			rts
	}
}
