//VIC BANK SETUP — Bank 3 ($C000-$FFFF)
// VIC cannot see $D000-$DFFF (I/O blind spot) — never place graphics data there.

* = $C000 "Screen A"                            // $C000-$C3FF (1KB) Screen buffer A + sprite pointers at $C3F8
* = $C400 "Screen B"                            // $C400-$C7FF (1KB) Screen buffer B + sprite pointers at $C7F8

* = $C800 "Sprite Frames 0-31"                 // $C800-$CFFF (2KB) 32 sprite frame slots × 64 bytes
        SPRITEDATA:
        .import binary "Data/Sprites/sprites.bin"

                                                // $D000-$DFFF  I/O BLIND SPOT — VIC reads $00 here
                                                //              CPU uses normally for VIC/SID/CIA registers

* = $E000 "Character Data A"                   // $E000-$E7FF (2KB) Charset A — world tileset
        CHARDATA:
        .import binary "Data/GFX/Charset/Chars.bin"

* = $E800 "Character Data B"                   // $E800-$EFFF (2KB) Charset B — HUD/UI font (reserved)

* = $F000 "Sprite Frames 32-94"                // $F000-$FEFF (4KB) 63 sprite frame slots × 64 bytes (reserved)
