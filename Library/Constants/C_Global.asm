// ++++ SETUP ----------------------------------------------------------------------------------------------------------
	.const _VIC_BANK_0          = %00000011
	.const _VIC_BANK_1          = %00000010
	.const _VIC_BANK_2          = %00000001
	.const _VIC_BANK_3          = %00000000
	.const _CHAR_ROM_VISIBLE    = %00000000           	// Character ROM visible at $D000-$DFFF
	.const _IO_VISIBLE          = %00000100           	// I/O area visible at $D000-$DFFF
	.const _RAM_00            	= %00000000           	// RAM Visible in all 3 areas
	.const _RAM_01				= %00000001           	// RAM Visible at $A000-$BFFF and $E000-$FFFF
	.const _RAM_10				= %00000010           	// RAM Visible at $A000-$BFFF; KERNAL ROM visible at $E000-$FFFF
	.const _RAM_11				= %00000011           	// BASIC ROM Visible at $A000-$BFFF; KERNAL ROM visible at $E000-$FFFF

// ++++ COLOURS --------------------------------------------------------------------------------------------------------
    /*
    Black   White   Red     Cyan    Magenta Green   Blue    Yellow
    00 00   01 01   02 02   03 03   04 04   05 05   06 06   07 07
    08 08   09 09   10 0A   11 0B   12 0C   13 0D   14 0E   15 0F
    Orange  Brown   Pink    D Grey  M Grey  L Green L Blue  L Grey   
    */
    .const MC_BLACK             = 08
    .const MC_WHITE             = 09
    .const MC_RED               = 10
    .const MC_CYAN              = 11
    .const MC_PURPLE            = 12
    .const MC_GREEN             = 13
    .const MC_BLUE              = 14
    .const MC_YELLOW            = 15

// ++++ CHARACTERS -----------------------------------------------------------------------------------------------------
	.const _BYTES_PER_CHARACTER = 8

// ++++ MULTIPLEXER ----------------------------------------------------------------------------------------------------
    // _MAX_SPRITES is in C_ControlPanel.asm (tunable)
    .const _BORDER_OFFSET_X     = 24
    .const _BORDER_OFFSET_Y     = 50
	.const _SPRITE_HEIGHT    	= 21  					// Unexpanded hardware sprite height, in raster lines
	.const _HARDWARE_SPRITES 	= 8   					// Number of physical VIC sprite slots (0-7)

// ++++ TIMERS/SWITCHES ------------------------------------------------------------------------------------------------
	.const _MAX_ANIM_DELAY_SLOTS= 6						// Animation delay slots
	.const _020ms				= 01
	.const _060ms				= 03
	.const _080ms				= 04
	.const _100ms				= 05
	.const _140ms				= 07
	.const _300ms				= 15
	.const _620ms				= 31
    .const _1Sec                = 51
    .const _2Sec                = 102
    .const _3Sec                = 153
    .const _4Sec                = 204
    .const _5Sec                = 255
	.enum {_FORWARDS, _BACKWARDS}
	.enum {_OFF, _ON}
	.enum {_NO, _YES}
	.enum {_INACTIVE, _ACTIVE}
	.enum {_CLEAR,_SET}
	.enum {_POSITIVE, _NEGATIVE = $80}


// ++++ ANIMATIONS AND SPRITES -----------------------------------------------------------------------------------------
	.enum {_ONE_TIME,_LOOP,_PINGPONG}
    .const _FRAME_OFFSET        = 28
    .const _BLANK_FRAME         = 00 + _FRAME_OFFSET

// ++++ SCREEN ---------------------------------------------------------------------------------------------------------
    .const _TOTAL_COLUMNS       = 40
    .const _TOTAL_ROWS          = 25
    .const _COLOUR_RAM_OFFSET   = 24

// ++++ RASTER INTERRUPTS ----------------------------------------------------------------------------------------------
							                     	    // 63 cycles per line (504 pixels / 8 pixels per cycle)
                                                	    // 19656 cycles per frame (312 ($138) Scan Lines per frame x 63 cycles)
														// 985248 cycles per second => 50.125 times per second 
														// or 0.01996 second per frame
	.const _IRQ_LB              = $FFFE
	.const _IRQ_HB              = $FFFF

// ++++ JOYSTICK INPUT -------------------------------------------------------------------------------------------------
    // Basic movement
    .const _JOY_UP              = %00000001
    .const _JOY_DN              = %00000010
    .const _JOY_LT              = %00000100
    .const _JOY_RT              = %00001000
    .const _JOY_FR              = %00010000
    // Diagonals
    .const _JOY_UR              = %00001001
    .const _JOY_DR              = %00001010
    .const _JOY_DL              = %00000110
    .const _JOY_UL              = %00000101
    // With Firebutton
    .const _JOY_FUP             = %00010001
    .const _JOY_FDN             = %00010010
    .const _JOY_FLT             = %00010100
    .const _JOY_FRT             = %00011000

// ++++ BIT MASKS ------------------------------------------------------------------------------------------------------
    .const _NO_BITS             = %00000000         	// No Bits Mask (0, $00)
	.const _LOWER_NYBBLE        = %00001111         	// Lower nibble mask (15, $0F)
	.const _UPPER_NYBBLE        = %11110000         	// Upper nibble mask (240, $F0)
    .const _ALL_BITS            = %11111111         	// All Bits Mask (255, $FF)

    // Powers of 2: Use Or for setting bits
	.const _BIT_0               = %00000001         	// Bit #0 mask (1, $01) 
    .const _BIT_1               = %00000010         	// Bit #1 mask (2, $02)
    .const _BIT_2               = %00000100         	// Bit #2 mask (4, $04)
    .const _BIT_3               = %00001000         	// Bit #3 mask (8, $08)
    .const _BIT_4               = %00010000         	// Bit #4 mask (16, $10)
    .const _BIT_5               = %00100000         	// Bit #5 mask (32, $20
    .const _BIT_6               = %01000000         	// Bit #6 mask (64, $40)
    .const _BIT_7               = %10000000         	// Bit #7 mask (128, $80)
    // Reverse powers of 2: Use And for clearing bits
	.const _R_BIT_0             = %11111110         	// Bit #0 mask (254, $FE)
    .const _R_BIT_1             = %11111101         	// Bit #1 mask (253, $FD)
    .const _R_BIT_2             = %11111011         	// Bit #2 mask (251, $FB)
    .const _R_BIT_3             = %11110111         	// Bit #3 mask (247, $F7)
    .const _R_BIT_4             = %11101111         	// Bit #4 mask (239, $EF)
    .const _R_BIT_5             = %11011111         	// Bit #5 mask (223, $DF)
    .const _R_BIT_6             = %10111111         	// Bit #6 mask (191, $BF)
    .const _R_BIT_7             = %01111111         	// Bit #7 mask (127, $7F)

// ++++ SFX ------------------------------------------------------------------------------------------------------------
	.const _SID_VOICE1			= $00
	.const _SID_VOICE2			= $07
	.const _SID_VOICE3			= $0E
	.const _VOICE1				= $00
	.const _VOICE2				= $01
	.const _VOICE3				= $02
	.const _DOWN_WIBBLE			= $00
	.const _UP_WIBBLE			= $01
	.const _DECREASE_PULSE		= $00
	.const _INCREASE_PULSE		= $01
	.const _SFX_STD_BRICK		= 00
	.const _SFX_EXTRA_LIFE		= 15
	.const _SFX_ENEMY_DEATH		= 16
	.const _SFX_ENEMY_SPAWN		= 17
	.const _SFX_PUP_COLLECT		= 18
	.const _SFX_PUP_SPAWN		= 19
	.const _SFX_LEVEL_COMPLETE	= 20
	.const _SFX_GAME_OVER		= 21
	.const _SFX_LOSE_LIFE		= 22
	.const _SFX_ROUND_NUMBER	= 23
	.const _SFX_PORTAL_OPEN		= 24
