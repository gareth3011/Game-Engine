.namespace STRUCTURE {

	*=* "Initialise"
    Initialise: {
			jsr IRQ.Initialise					// Initialise the IRQ
			jsr UTILS.Random.Initialise			// Init the random function
    }

	*=* "Game TitleScreen"
    TitleScreen: {
			lda #$00
			sta ZP.Counter + 0
			sta ZP.Counter + 1
			sta ZP.FrameFlag
			sta VIC._BACKGROUND
			sta VIC._BORDER

    	!TitleLoop:
			debugStart("IRQ1", BLUE)

		!Wait:
			lda ZP.FrameFlag
			beq !Wait-              	// Set timing for game loop so that updates happen each frame
			dec ZP.FrameFlag
			
			frameCounter()					// Increment the frame counters
	
			debugEnd()

			jmp !TitleLoop-  
    }

        #import "Modules/IRQ.asm"    		// Interrupt routine
        #import "Modules/Utils.asm"    		// Utils routines

}