.namespace STRUCTURE {

	*=* "Initialise"
    Initialise: {
			jsr IRQ.Initialise							// Initialise the IRQ
			jsr UTILS.Random.Initialise					// Init the random function
    }

	*=* "Engine Loop"
    EngineLoop: {
			resetCounters()								// Zero frame counter and frame flag
			sta VIC._BACKGROUND							// A = 0 from resetCounters — clear background and border
			sta VIC._BORDER

    	!engineLoop:
			debugStart("IRQ1", BLUE)

		!Wait:
			lda ZP.FrameFlag
			beq !Wait-              					// Set timing for game loop so that updates happen each frame
			dec ZP.FrameFlag
			
			frameCounter()								// Increment the frame counters
	
			debugEnd()

			jmp !engineLoop-  
    }

        #import "../Engine/IRQ/IRQ_Init.asm"    		// Interrupt routine
        #import "../Modules/Utils.asm"    				// Utils routines

}