	.macro setScreenColourVectors (screen, colour) {	// Set Screen and colour vectors
			lda #<[screen]
			sta ZP.ScreenVector + 0
			sta ZP.ColourVector + 0               
	
			lda #>[screen]
			sta ZP.ScreenVector + 1
			lda #>[colour]
			sta ZP.ColourVector + 1
	}

	.macro screenOff () {
			lda VIC._SCROLY								// Blank the screen
			and #_R_BIT_4
			sta VIC._SCROLY
	}

	.macro screenOn () {
			lda VIC._SCROLY								// Turn on the screen
			ora #_BIT_4									// Set #4
			and #_R_BIT_7								// Ensure #7 is set to 0
			sta VIC._SCROLY
	}

	.macro setCharMC1 (colour) {						// Set Character Multicolour 1
			lda #colour
			sta VIC._BGCOL1
	}

	.macro setCharMC2 (colour) {						// Set Character Multicolour 2 
			lda #colour
			sta VIC._BGCOL2
	}