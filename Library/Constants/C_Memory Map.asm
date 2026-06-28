// ++++ MEMORY MAP------------------------------------------------------------------------------------------------------

	.label _TABLES         		= $0700		// $0500 - $07ff Tables for screen address, POT and RPOT (768 bytes) 

	.label _MODULES        		= $080E		// $080E - $0FFF Utils, Multiplexor, IRQ (2033 bytes)

	.label _MUSIC_SFX      		= $1000 	// $1000 - $2FFF Music and Sound Effects (8192 Bytes)

	.label _GAME_CODE         	= $3000 	// $3000 - $9FFF (28671 Bytes)

	.label _ASSETS        		= $C000
	.label _SCREEN 				= $C000		// $C000 - $C3FF SCREEN (1024 bytes)
	.label _SPARE1				= $C400		// $C400 - $CFFF  (3071 BYTES)
	.label _SPRITE_BANK_1 		= $D000 	// $D000 - $DFFF Sprite Frames 00 to 127 (128 Sprites) (4098 Bytes)
	.label _CHARACTER_DATA 		= $E000 	// $E000 - $F7FF Character set for 256 characters (2048 Bytes)
	.label _SPARE2 				= $E800 	// $E800 - $EFFF (2048 Bytes)
	.label _SPARE4 				= $F000 	// $F000 - $FF00 (60 Sprites Frame 192 to 252) (4096 bytes)