//VIC BANK SETUP
* = $C000 "Screen"			        // $C000 - $C3FF (1024 bytes) Screen and Sprite Pointers

* = $C400 "Spare Slot V1"			// $C400 - $CFFF (3072 bytes)

* = $D000 "Sprite Data"                         // $D000 - $DFFF (4096 Bytes) Sprite Frames 64 to 127
        SPRITEDATA:
        .import binary "Assets/Sprites/sprites.bin"          

* = $E000 "Character Data"                      // $F000 - $F7FF (2048 Bytes) Character set for 256 characters
        CHARDATA:
        .import binary "Assets/Characters/Chars.bin"  

* = $E800 "Spare Slot V2"                       // $E800 - $EFFF (2048 Bytes)

* = $F000 "IRQ, Utils"		                // $F7FF - $FFF0 (2033 Bytes)
	