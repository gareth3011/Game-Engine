	// Colour Charts
    // COLOUR           TITLE               		GAME                 		GAMEOVER
	// 00 - Black       End of routine
    // 01 - White       Title IRQ					GameMain IRQ				GameOver IRQ
    // 02 - Red         							IRQ2
    // 03 - Cyan        							Ball Update
    // 04 - Purple      							Power.Update
    // 05 - Green       							Multiplexer Sort
    // 06 - Blue        							Multiplexer DrawSprites
    // 07 - Yellow      Matrix Effect				Sprite Point Detect
    // 08 - Orange     								Sprite Detect
    // 09 - Brown	    XXX
    // 10 - LightRed    XXX
    // 11 - DarkGray    XXX
    // 12 - MediumGray  XXX
    // 13 - LightGreen  XXX                         Bat
    // 14 - LightBlue  	XXX                         Lives.Update
    // 15 - LightGray  	XXX

	#define DEBUG

	.macro Debug (Colour) {            // DEBUG Border set
		#if DEBUG
			lda #Colour                 // (2)
			sta VIC._BORDER              // (4)
		#endif
	}
