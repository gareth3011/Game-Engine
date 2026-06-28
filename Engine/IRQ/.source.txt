.namespace IRQ {
	.pc = * "IRQ Initialise"
    Initialise: {
			sei											// Disable Interrupts
			disableTimerInterrupts()					// Disable CIA timer interrupts

			enableRasterInterrupt()						// Enable VIC raster as interrupt source
			clearRasterBit8()							// Ensure raster targets lines 0-255 (bit 8 = 0)

			VICSetup(_IO_VISIBLE, _RAM_01, _VIC_BANK_3, VIC._SCREEN_RAM, _CHARACTER_DATA)

			setIRQ #_IRQ_1_RASTER : #<IRQ.IRQ1 : #>IRQ.IRQ1	// Set raster line and IRQ address

			cli                             			// Enable interrupts
			rts
    }

	.pc = * "IRQ 1"
    IRQ1: {
			enterIRQ()

			debugStart("IRQ1", CYAN)

			inc ZP.FrameFlag							// Set the frame flag

			debugEnd()

			exitIRQ()
			rti                             			// Return
    }


}
