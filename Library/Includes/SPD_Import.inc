// ---------------------------------------------------------------------------
// spritepad_import.inc
// SpritePad (.SPD binary export) → Kick Assembler importer
// For use in the IOTA build system
//
// IMPORTANT:
//   You MUST export from SpritePad using "Binary Export (.spd)".
//   This importer does NOT parse the .spd project format.
// ---------------------------------------------------------------------------
/* 
------------------------------------------------------------------------------
HOW TO USE
------------------------------------------------------------------------------
Include the converter
#import "../SPD_Import.inc"
.var SPD_SPRITE_SIZE = 64	 // set to 63 if using hi‑res sprites
.var SPD_HAS_COLOUR_TABLE = true

Single file:
Load the SPD file
.var powerups = SpdLoad("assets/sprites/powerups.spd")

Emit all sprites at $4000
SpdEmitAll(powerups, $4000)

Emit sprite #3 at $5000
SpdEmitSprite(powerups, 3, $5000)

Emit colour table at $6000
SpdEmitColours(powerups, $6000)

Multiple files:
LLoad the files
.var powerups = SpdLoad("assets/sprites/powerups.spd")
.var enemies  = SpdLoad("assets/sprites/enemies.spd")

SpdEmitAll(powerups, $4000)
SpdEmitAll(enemies,  $4800)

SpdEmitColours(powerups, $5000)
SpdEmitColours(enemies,  $5000 + powerups.get("count"))
*/
// ---------------------------------------------------------------------------
// CONFIGURATION
// ---------------------------------------------------------------------------

// Sprite size in bytes:
//   Hi‑res:      63 bytes
//   Multicolour: 64 bytes
//
// SpritePad always exports fixed‑size sprite blocks.
.var SPD_SPRITE_SIZE = 64     // set to 63 if using hi‑res sprites

// If your SPD export includes a colour table, enable this:
.var SPD_HAS_COLOUR_TABLE = true


// ---------------------------------------------------------------------------
// INTERNAL PARSER
// ---------------------------------------------------------------------------
//
// SPD binary export layout (SpritePad Pro):
//
//   Offset  Size    Description
//   -----------------------------------------
//   0       1       Sprite count (N)
//   1       N*S     Sprite data (each S bytes)
//   ...             Optional colour table (N bytes)
//
// ---------------------------------------------------------------------------

.function SpdLoad(fileName) {
    .var bin = LoadBinary(fileName)
    .var hash   = Hashtable()

    .eval hash.put("raw", bin)

    // Sprite count
    .var spriteCount = bin.get(0)
    .eval hash.put("count", spriteCount)

    // Sprite data block
    .var spriteDataStart = 1
    .var spriteDataSize  = spriteCount * SPD_SPRITE_SIZE
    .var sprites         = bin.slice(spriteDataStart, spriteDataSize)
    .eval hash.put("sprites", sprites)

    // Optional colour table
    .if (SPD_HAS_COLOUR_TABLE) {
        .var colourStart = spriteDataStart + spriteDataSize
        .var colours     = bin.slice(colourStart, spriteCount)
        .eval hash.put("colours", colours)
    }

    .return hash
}


// ---------------------------------------------------------------------------
// EMIT MACROS
// ---------------------------------------------------------------------------

// Emit ALL sprites at a given address
.macro SpdEmitAll(spd, addr) {
    * = addr
    .var s = spd.get("sprites")
    .fill s.size(), s.get(i)
}

// Emit a single sprite (index) at a given address
.macro SpdEmitSprite(spd, index, addr) {
    * = addr
    .var s = spd.get("sprites")
    .var start = index * SPD_SPRITE_SIZE
    .fill SPD_SPRITE_SIZE, s.get(start + i)
}

// Emit a range of sprites [first .. last] inclusive
.macro SpdEmitRange(spd, first, last, addr) {
    * = addr
    .var s = spd.get("sprites")
    .var count = (last - first + 1)
    .var start = first * SPD_SPRITE_SIZE
    .var size  = count * SPD_SPRITE_SIZE
    .fill size, s.get(start + i)
}

// Emit colour table (if present)
.macro SpdEmitColours(spd, addr) {
    .if (SPD_HAS_COLOUR_TABLE) {
        * = addr
        .var c = spd.get("colours")
        .fill c.size(), c.get(i)
    }
}
