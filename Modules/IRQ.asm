.namespace IRQ {
	.pc = * "IRQ Initialise"
    Initialise: {
			sei											// Disable Interrupts
			disableTimerInterrupts()					// Disable CIA timer interrupts

			lda VIC._IRQMSK
			ora #_BIT_0                     			// Set the raster as the interrupt source
			sta VIC._IRQMSK

			lda #$1B                  					// Raster bit 8 = 0, screen on, 25 rows, y-scroll = 3
			sta VIC._SCROLY

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
