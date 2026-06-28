// COUNTERS AND DELAYS
	.macro resetCounters () {							// Reset the game counters
			lda #_OFF
			sta ZP.Counter + 0
			sta ZP.Counter + 1
			sta ZP.FrameFlag
	}

	.macro resetFrameCounter () {						// Reset the frame counter
			lda #_OFF
			sta ZP.Counter + 0
			sta ZP.Counter + 1
	}

	.macro frameCounter () { 							// Game timing counter updated once per frame
			inc ZP.Counter + 1
			bne !Skip+
			inc ZP.Counter + 0
		!Skip:
	}

	.macro getFrameCounterLSB (mask) {					// Get the frame counter LSB value
			lda ZP.Counter + 1
		.if(mask != null) {								// If required, mask it out.
			and #mask
		}
	}

	.macro getFrameCounterMSB (mask) {					// Get the frame counter MSB value
			lda ZP.Counter + 0
		.if(mask != null) {								// If required, mask it out.
			and #mask
		}
	}

	.macro setBitCounter_1 (value) {
			lda #value
			sta ZP.BitCounter1
	}

		.macro nextBitCounter_1 () {
			lsr ZP.BitCounter1
		}

	.macro resetBitCounter_1 () {
		    ror ZP.BitCounter1          				// Reset Counter
	}

	.macro waitFrameFlag () {							// Wait for next screen frame 
		!Wait:
			lda ZP.FrameFlag
			bne !Wait-
			inc ZP.FrameFlag							// Increment the update flag which will be read by IRQ's
	}

	.macro wait (delay)	{								// Wait time in frames - 255 = 5 seconds 
			lda ZP.Counter + 1
			and #delay
	}

	.macro Wait5 (delay) {								// Wait time in 5 second intervals 1 = 5 seconds, 255 = 1275 seconds
			lda ZP.Counter + 0
			and #delay
	}