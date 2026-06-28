// MATHS AND UTILS
	.macro rng (mask) {									// Simple rng
			lda VIC._RASTER								// (4) first we read the current raster line (0-255)
			eor ZP.Counter + 1							// (4) then we xor it with timer A (low byte)
			sbc CIA._TIMAHI								// (4) then we subtract it with timer A (high byte)
		.if(mask != null) {
			and #mask									// (2) finally we mask it so we can have a number between 0 and bits^2
		}
	}

	.macro getRandomNumber () {
			jsr UTILS.Random.Get
	}

	.macro xor (carry) {        						// (6) Flip a byte
		.if(carry <1) {
			clc
		}
			eor #_ALL_BITS
			adc #$01
	}

	.macro subtract (value, carry) {					// Subtract an Amount
		.if(carry != null) {							// Enables us to lda prior to calling if we require some calculated value
			sec
		}
			sbc #value
	}

	.macro subtract_X (value) {         				// Subtract an Amount from X Register (A is destroyed)
			txa
			sbx #value
	}

	.macro add (value, carry) {       					// Add an amount
		.if(carry != null) {							// Enables us to lda prior to calling if we require some calculated value
			clc
		}
			adc #value
	}

	.macro rangeCheckSet (carry, from, to) {			// Takes value in A and checks if in the range n to m (A destroyed)
														// Syntax: rangeCheckSet(Yes,10,20); rangeCheckSet(null,10,20)
		.if(carry != null) {
			clc											// Clear carry for add
		}
			adc	#[$FF - to]								// Make to = $FF
			adc	#[to - from + 1]						// carry set if in range n to m
	}

	.macro rangeCheckClear (carry, from, to) {			// Takes value in A and checks if in the range n to m (A destroyed)
														// Syntax: rangeCheckClear(Yes,10,20); rangeCheckSet(null,10,20)
		.if(carry != null) {
			sec 										// Clear carry for add
		}
			sbc	#from									// Make from = $00
			sbc	#[to - from + 1]						// carry clear if in range n to m
	}

	.pseudocommand dec16Bit lsb:msb { 					// A smart way to decrement a 2-byte number:
			lda #$FF
			dcm lsb
			bne !Skip+
			dec msb
		!Skip:											// Carry is always set
	}

	.pseudocommand inc16Bit lsb:msb {					// A smart way to increment a 2-byte number:
			inc lsb
			bne !Skip+
			inc msb
		!Skip:
	}

	.pseudocommand add9Bit lsb:msb:carry:value {
		.if(carry != null) {
			clc
		}	
			lda lsb
			adc #value
			sta lsb
			bcc !+             
			inc msb
		!:
	}

	.pseudocommand subtract9Bit lsb:msb:carry:value {
		.if(carry != null) {
			sec
		}	
			lda lsb
			sbc #value
			sta lsb
			bcs !+             
			dec msb
		!:
	}
	
	.macro SaveA () {
			sta ZP.TempA
	}

	.macro RestoreA () {
			lda ZP.TempA
	}

	.macro SaveX () {
			stx ZP.TempX
	}

	.macro RestoreX () {
			ldx ZP.TempX
	}

	.macro SaveY () {
			sty ZP.TempY
	}

	.macro RestoreY () {
			ldy ZP.TempY
	}

    // getJoystick_1 / resetJoystick_1 disabled — requires PLAYER namespace (not yet defined)
    // Restore these when the PLAYER module is implemented.