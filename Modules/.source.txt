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

			// Bank out KERNAL so RAM at $E000-$FFFF is visible (our IRQ vectors at $FFFE/$FFFF take effect)
			lda VIC._R6510
			and #%11111000
			ora #(_IO_VISIBLE | _RAM_01)				// I/O at $D000, RAM at $A000 and $E000
			sta VIC._R6510

			setIRQ #_IRQ_1_RASTER : #<IRQ.IRQ1 : #>IRQ.IRQ1	// Set raster line and IRQ address

			cli                             			// Enable interrupts
			rts
    }

	.pc = * "IRQ 1"
    IRQ1: {
			enterIRQ()

			debugStart("IRQ1", BLUE)

			inc ZP.FrameFlag							// Set the frame flag

			debugEnd()

			exitIRQ()
			rti                             			// Return
    }


}
