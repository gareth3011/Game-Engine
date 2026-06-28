//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++//
// Base Template
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++//
    #import "Library/Library Index.asm"							// Global Game Labels, constants and addresses
	#import "Modules/Debug.asm"							// Border Debug

BasicUpstart2(Entry)
* = $0810 "Entry Point"									// $0801 - $080D (13 bytes) Entry point
	Entry: {
		jmp STRUCTURE.Initialise						// Jump to Game routines
	}

* = $0820 "Tables"										// $0810 - $0FFF (2032 bytes)
    #import "Library/Tables.asm"    					// Lookup tables

* = $1000 "Music and SFX"				        		// $1000 - $2FFF (8192 bytes)

* = $3000 "Code"                       			        // $3000 - $7FFF (20480 Bytes)
	#import "Game Engine Structure.asm"						// Main Game loop

* = $C000
	#import "Assets/VIC Bank.asm"     					// Asset data
