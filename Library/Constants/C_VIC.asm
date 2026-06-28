.namespace VIC {
    // MAPPING THE C64 LABELS
    .label _D6510     	 	= $00   	// 6510 On Chip I/O Data Direction Register.
										/*	Bit #x:	0 = Bit #x in processor port can only be read; 
													1 = Bit #x in processor port can be read and written.
											Default: $2F, %00101111.  */
    .label _R6510         	= $01   	// 6510 On-Chip I/O Port
										/*	Bits #0-#2: Configuration for memory areas $A000-$BFFF, $D000-$DFFF and $E000-$FFFF. Values:
											%x00: RAM visible in all three areas.
											%x01: RAM visible at $A000-$BFFF and $E000-$FFFF.
											%x10: RAM visible at $A000-$BFFF; KERNAL ROM visible at $E000-$FFFF.
											%x11: BASIC ROM visible at $A000-$BFFF; KERNAL ROM visible at $E000-$FFFF.
											%0xx: Character ROM visible at $D000-$DFFF. (Except for the value %000, see above.)
											%1xx: I/O area visible at $D000-$DFFF. (Except for the value %100, see above.)
											Bit #3: Datasette output signal level.
											Bit #4: Datasette button status; 
											0 = One or more of PLAY, RECORD, F.FWD or REW pressed; 1 = No button is pressed.
											Bit #5: Datasette motor control; 0 = On; 1 = Off.
											Default: $37, %00110111. */

    .label _SCREEN_RAM  	= $C000 	// Start of screen memory
    .label _SP0_POINTER  	= _SCREEN_RAM + $03F8 // Sprite 0 pointer
    .label _SP1_POINTER  	= _SCREEN_RAM + $03F9 // Sprite 1 pointer
    .label _SP2_POINTER  	= _SCREEN_RAM + $03FA // Sprite 2 pointer
    .label _SP3_POINTER  	= _SCREEN_RAM + $03FB // Sprite 3 pointer
    .label _SP4_POINTER  	= _SCREEN_RAM + $03FC // Sprite 4 pointer
    .label _SP5_POINTER  	= _SCREEN_RAM + $03FD // Sprite 5 pointer
    .label _SP6_POINTER  	= _SCREEN_RAM + $03FE // Sprite 6 pointer 
    .label _SP7_POINTER  	= _SCREEN_RAM + $03FF // Sprite 7 pointer

	.label _SP0X         	= $D000 	// Sprite 0 X Coordinate (24-344 visible)
	.label _SP0Y         	= $D001 	// Sprite 0 Y Coordinate (50-230 visible)
	.label _SP1X         	= $D002 	// Sprite 1 X Coordinate
	.label _SP1Y         	= $D003 	// Sprite 1 Y Coordinate
	.label _SP2X         	= $D004 	// Sprite 2 X Coordinate
	.label _SP2Y         	= $D005 	// Sprite 2 Y Coordinate
	.label _SP3X         	= $D006 	// Sprite 3 X Coordinate
	.label _SP3Y         	= $D007 	// Sprite 3 Y Coordinate
	.label _SP4X         	= $D008 	// Sprite 4 X Coordinate
	.label _SP4Y         	= $D009 	// Sprite 4 Y Coordinate
	.label _SP5X         	= $D00A 	// Sprite 5 X Coordinate
	.label _SP5Y         	= $D00B 	// Sprite 5 Y Coordinate
	.label _SP6X         	= $D00C 	// Sprite 6 X Coordinate
	.label _SP6Y         	= $D00D 	// Sprite 6 Y Coordinate
	.label _SP7X         	= $D00E 	// Sprite 7 X Coordinate
	.label _SP7Y         	= $D00F 	// Sprite 7 Y Coordinate
	.label _MSIGX        	= $D010 	// MSB of sprite 0-7 X Coordinate - #0=Sprite0, #1=Sprite1, etc
	.label _SCROLY       	= $D011 	// Screen control register #1
										/*	Bits #0-#2: Vertical raster scroll.
											Bit #3: Screen height; 0 = 24 rows; 1 = 25 rows.
											Bit #4: 0 = Screen off, complete screen is covered by border; 1 = Screen on, normal screen contents are visible.
											Bit #5: 0 = Text mode; 1 = Bitmap mode.
											Bit #6: 1 = Extended background mode on.
											Bit #7: Read: Current raster line (bit #8).
											Write: Raster line to generate interrupt at (bit #8).
											Default: $1B, %00011011.	*/
	.label _RASTER       	= $D012 	// Read/write current raster scan line (50-249 are visible. Max 312 lines)
	.label _LPENX        	= $D013 	// Light Pen Horizontal Coordinate (Range from 0 to 160) 2 pixels per Coordinate
	.label _LPENY        	= $D014 	// Light Pen Vertical Coordinate (Range from 0 to 200)
	.label _SPENA        	= $D015 	// Sprite enable register (#0 Sprite 0, #1 sprite 1, etc..)
	.label _SCROLX       	= $D016 	// Screen control register #2
										/*  Bits #0-#2: Horizontal raster scroll.
											Bit #3: Screen width; 0 = 38 columns; 1 = 40 columns.
											Bit #4: 1 = Multicolor mode on.
											efault: $C8, %11001000.	*/
	.label _YXPAND       	= $D017 	// Sprite Vertical Expansion Register (#0 Sprite 0, #1 sprite 1, etc..)
	.label _VMCSB        	= $D018 	// Memory setup register
										/*  Bits #1-#3: In text mode, pointer to character memory (bits #11-#13), 
											relative to VIC bank, memory address $DD00. Values:
											%000, 0: $0000-$07FF, 0-2047.
											%001, 1: $0800-$0FFF, 2048-4095.
											%010, 2: $1000-$17FF, 4096-6143.
											%011, 3: $1800-$1FFF, 6144-8191.
											%100, 4: $2000-$27FF, 8192-10239.
											%101, 5: $2800-$2FFF, 10240-12287.
											%110, 6: $3000-$37FF, 12288-14335.
											%111, 7: $3800-$3FFF, 14336-16383.
											Values %010 and %011 in VIC bank #0 and #2 select Character ROM instead.
											In bitmap mode, pointer to bitmap memory (bit #13), relative to VIC bank, memory address $DD00. Values:
											%0xx, 0: $0000-$1FFF, 0-8191.
											%1xx, 4: $2000-$3FFF, 8192-16383.

											Bits #4-#7: Pointer to screen memory (bits #10-#13), relative to VIC bank, memory address $DD00. Values:
											%0000, 0: $0000-$03FF, 0-1023.
											%0001, 1: $0400-$07FF, 1024-2047.
											%0010, 2: $0800-$0BFF, 2048-3071.
											%0011, 3: $0C00-$0FFF, 3072-4095.
											%0100, 4: $1000-$13FF, 4096-5119.
											%0101, 5: $1400-$17FF, 5120-6143.
											%0110, 6: $1800-$1BFF, 6144-7167.
											%0111, 7: $1C00-$1FFF, 7168-8191.
											%1000, 8: $2000-$23FF, 8192-9215.
											%1001, 9: $2400-$27FF, 9216-10239.
											%1010, 10: $2800-$2BFF, 10240-11263.
											%1011, 11: $2C00-$2FFF, 11264-12287.
											%1100, 12: $3000-$33FF, 12288-13311.
											%1101, 13: $3400-$37FF, 13312-14335.
											%1110, 14: $3800-$3BFF, 14336-15359.
											%1111, 15: $3C00-$3FFF, 15360-16383. */
	.label _VICIRQ       	= $D019 	// Interrupt status register
										/* 	Bit #0: 1 = Current raster line is equal to the raster line to generate interrupt at.
											Bit #1: 1 = Sprite-background collision occurred.
											Bit #2: 1 = Sprite-sprite collision occurred.
											Bit #3: 1 = Light pen signal arrived.
											Bit #7: 1 = An event (or more events), that may generate an interrupt, occurred and it has not been (not all of them have been) acknowledged yet.

											Write bits:
											Bit #0: 1 = Acknowledge raster interrupt.
											Bit #1: 1 = Acknowledge sprite-background collision interrupt.
											Bit #2: 1 = Acknowledge sprite-sprite collision interrupt.
											Bit #3: 1 = Acknowledge light pen interrupt. */	
	.label _IRQMSK       	= $D01A 	// Interrupt control register
										/*	Bit #0: 1 = Raster interrupt enabled.
											Bit #1: 1 = Sprite-background collision interrupt enabled.
											Bit #2: 1 = Sprite-sprite collision interrupt enabled.
											Bit #3: 1 = Light pen interrupt enabled.	*/
	.label _SPBGPR       	= $D01B 	// Sprite priority register
										/*	Bit #x:	0 = Sprite #x is drawn in front of screen contents; 
													1 = Sprite #x is behind screen contents. */
	.label _SPMC         	= $D01C 	// Sprite Multicolour Register (#0 Sprite 0, #1 sprite 1, etc..)
	.label _XXPAND       	= $D01D 	// Sprite Horizontal Expansion Register (#0 Sprite 0, #1 sprite 1, etc..)
	.label _SPSPCL       	= $D01E 	// Sprite to Sprite Collision register
										/*	Bit #x: 1 = Sprite #x collided with background.
											Write: Enable further detection of sprite-background collisions. */
	.label _SPBGCL       	= $D01F 	// Sprite to Foreground Collision register (#0 Sprite 0, #1 sprite 1, etc..) #1=yes
	.label _BORDER       	= $D020 	// Border colour register
	.label _BACKGROUND   	= $D021 	// Background colour 0 (Multicolour 0,0)
	.label _BGCOL1       	= $D022 	// Background colour 1 (Multicolour 0,1)
	.label _BGCOL2       	= $D023 	// Background colour 2 (Multicolour 1,0)
	.label _BGCOL3       	= $D024 	// Background colour 3
	.label _SPMC0        	= $D025 	// Sprite multicolour 0
	.label _SPMC1        	= $D026 	// Sprite multicolour 1
	.label _SP0COL       	= $D027 	// Sprite 0 colour
	.label _SP1COL       	= $D028 	// Sprite 1 colour
	.label _SP2COL       	= $D029 	// Sprite 2 colour
	.label _SP3COL       	= $D02A 	// Sprite 3 colour
	.label _SP4COL       	= $D02B 	// Sprite 4 colour
	.label _SP5COL       	= $D02C 	// Sprite 5 colour
	.label _SP6COL       	= $D02D 	// Sprite 6 colour
	.label _SP7COL       	= $D02E 	// Sprite 7 colour
	.label _COLOUR_RAM   	= $D800 	// Screen colour RAM Bits 0-3 (Multicolour 1,1)
}