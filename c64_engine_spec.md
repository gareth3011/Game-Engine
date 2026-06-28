# C64 Large Map Engine — Technical Specification

**Project:** Multidirectional Scrolling Engine with Cartridge Storage  
**Platform:** Commodore 64 (PAL primary, NTSC compatible)  
**Cartridge Format:** EasyFlash (1MB, 64 banks × 16K)  
**Assembler:** Kick Assembler (KickAss)  
**CPU Budget:** PAL ~19,656 cycles/frame, NTSC ~17,095 cycles/frame  
**Version:** 4.1  

---

## Revision History

| Version | Changes |
|---------|---------|
| 1.0 | Initial specification |
| 2.0 | VIC relocated to bank 3 ($C000-$FFFF); KERNAL banked out; music/SFX placed $1000-$2FFF; charset count reduced to 2, freed space given to sprite frames (95 slots total); cartridge asset loading moved to between-levels only; all code examples converted to Kick Assembler syntax with preprocessor use throughout |
| 3.0 | Software sprite collision system added (Section 9); MAX_ACTIVE reduced to 8 as default budget; split-tick architecture defined (display 50fps, logic 25fps optional); collision group mask added to EnemyTypeDef; collision event queue added to RAM map; timing budget revised and expanded with per-scenario breakdown; cartridge-resident unrolled collision checker documented |
| 3.1 | Section 9.1 rewritten: five-stage collision cascade adopted from TNT/Paradroid Redux; AABB replaced with span mask pixel-exact geometry; symmetric table check added for common type pairs; signed 16-bit dx arithmetic; collision mask data format and budget documented; cost summary revised |
| 4.0 | FLD future-proofing notes added (ZP reservation, IRQ chain insertion point, Charset B dual-role annotation); VIC-II exploit evaluation documented (FLD adopted for Phase 3, VSP/Linecrunch explicitly rejected); build phase sequencing added (Section 14); project folder structure defined (Section 15) |
| 4.1 | Multicolour mode confirmed for tiles and sprites; VIC colour registers documented; TileDef updated for multicolour; Section 17 Asset Pipeline added covering CharPad Pro and SpritePad Pro export workflow, file naming convention, folder layout, and KickAssembler import stubs; folder structure in Section 15 expanded with full asset hierarchy |

---

## 1. System Overview

This specification defines a complete multidirectional scrolling engine for the C64,
comprising eight tightly integrated subsystems:

1. Cartridge bank manager
2. Map storage and ring buffer
3. Scroll engine (fine + coarse, 4-way)
4. World coordinate system
5. Sprite multiplexer
6. Object tracking and state management
7. Software collision detection
8. Between-levels asset loader

All subsystems share a common coordinate format and communicate through
well-defined RAM interfaces. The cartridge is treated as read-only backing
storage; all runtime processing operates from RAM. Asset transfers from
cartridge occur exclusively during level transitions — never during gameplay.
This eliminates raster timing pressure on cartridge access entirely.

The VIC-II is configured to use bank 3 ($C000-$FFFF), with the KERNAL
banked out to expose RAM at $E000-$FFFF for character sets and sprite frames.
Music and SFX data reside at $1000-$2FFF, freeing lower RAM for engine
and game logic.

**Active object budget: MAX_ACTIVE = 8.** This is a deliberate performance
decision driven by software collision detection costs (Section 9) and scroll
engine cycle pressure on worst-case frames. 8 active objects gives a
comfortable 50fps budget across all scroll modes. A split-tick architecture
(Section 13) is defined as an optional fallback if game requirements demand
more active objects or more complex AI — display updates remain at 50fps
while logic runs at 25fps.

---

## 2. Memory Map

### 2.1 Full RAM Layout

```
$0000-$00FF   Zero page
              $00-$01   CPU port / bank control (hardware)
              $02-$03   Map ring buffer pointer      (zp_map_ptr)
              $04-$05   Object data pointer          (zp_obj_ptr)
              $06-$07   General scratch pointer      (zp_scratch)
              $08       Camera X high (block units)
              $09       Camera X low  (sub-block)
              $0A       Camera Y high (block units)
              $0B       Camera Y low  (sub-block)
              $0C       Fine scroll X (0-7, written to $D016 bits 0-2)
              $0D       Fine scroll Y (0-7, written to $D011 bits 0-2)
              $0E       Scroll direction flags (bit0=R, bit1=L, bit2=D, bit3=U)
              $0F       Shift phase flag (0=first half, 1=second half)
              $10-$1F   Logical sprite X positions (16 entries)
              $20-$2F   Logical sprite Y positions
              $30       Multiplex sort temp
              $31       Frame counter (0-255, wraps)
              $32       NTSC flag (0=PAL, 1=NTSC)
              $33-$3F   Reserved / game-specific zero page
              $40       FLD parallax offset current  (RESERVED — Phase 3)
              $41       FLD parallax offset target   (RESERVED — Phase 3)
              $42       FLD scroll rate fraction     (RESERVED — Phase 3)
              $43       FLD state flags              (RESERVED — Phase 3)
              $44-$FF   Game-specific zero page

$0100-$01FF   Stack

$0200-$02FF   Sprite multiplexer sort buffer + raster IRQ vectors

$0300-$037F   Active object table (8 objects × 16 bytes, see Section 7)
$0380-$039F   Collision event queue (8 events × 4 bytes, see Section 9)
$03A0-$03FF   Reserved / game-specific object extension data

$0400-$0FFF   Engine code — scroll, multiplex, coordinate routines
              (copied from cartridge bank 00 at startup, ~3KB)

$1000-$2FFF   Music player code + SFX data + track data (8KB)
              SID player routine at $1000
              Track data follows, up to end of $2FFF

$3000-$3FFF   Lookup tables
              $3000   Row address table low  (256 entries)
              $3100   Row address table high (256 entries)
              $3200   Sin/cos table          (512 bytes)
              $3400   Bitmask table          (8 bytes, padded)
              $3500   Tile flags cache       (256 bytes — solid/hazard/anim)
              $3600   Sprite frame index     (per enemy type, see Section 3.4)
              $3700-$3FFF  Reserved lookups

$4000-$4FFF   Level data array — inactive objects (255 × 5 bytes, see Section 7.2)

$5000-$5FFF   Map ring buffer (64×32 tiles = 2048 bytes at $5000, rest spare)
              $5000-$57FF  Ring buffer (2KB)
              $5800-$5FFF  Ring buffer metadata + map descriptor

$6000-$7FFF   Game logic, AI routines, player code, HUD (~8KB)

$8000-$9FFF   EasyFlash cartridge window LOW  (controlled by $DE00)
$A000-$BFFF   EasyFlash cartridge window HIGH (controlled by $DE01)

$C000-$FFFF   VIC-II bank 3 (see Section 2.2)

$D000-$DFFF   I/O space — VIC-II, SID, CIA registers, colour RAM
              (always mapped regardless of bank 3 layout;
               VIC cannot see this range — blind spot for graphics data)
```

### 2.2 VIC Bank 3 Layout ($C000-$FFFF)

The VIC-II is configured to read from bank 3 ($C000-$FFFF) via $DD00.
The I/O window at $D000-$DFFF is a hardware blind spot — the VIC reads $00
there regardless of RAM contents. All graphics data must avoid this range.

```
$C000-$C3FF   1KB    Screen buffer A
$C400-$C7FF   1KB    Screen buffer B
$C800-$CFFF   2KB    Sprite frames 0-31   (32 slots × 64 bytes)

$D000-$DFFF   4KB    I/O BLIND SPOT — VIC reads $00 here
                     (CPU uses normally for VIC/SID/CIA registers,
                      colour RAM at $D800)

$E000-$E7FF   2KB    Charset A — world tileset (swapped per world)
$E800-$EFFF   2KB    Charset B — HUD / UI / font (persistent)
                     NOTE Phase 3: Charset B has a planned dual role —
                     background parallax tiles (upper screen rows) AND
                     HUD font (status bar rows), switched via raster split.
                     Tile artist should be aware both functions share this
                     2KB charset. Keep HUD characters in slots 0-63,
                     background tiles in slots 64-255 as a convention.
$F000-$FEFF   ~4KB   Sprite frames 32-94  (63 slots × 64 bytes)
$FF00-$FFFF   256B   IRQ/NMI vectors + minimal stub
                     (KERNAL banked out; vectors must remain valid)
```

**Total sprite frame slots: 95** (32 lower + 63 upper)  
**Character sets: 2** (Charset A swapped at world transitions; Charset B permanent)

### 2.3 VIC Register Configuration

```
$DD00 bits 0-1 = %00        VIC reads bank 3 ($C000-$FFFF)

$D016 bits 0-2: horizontal fine scroll (0-7)
$D016 bit  4:   multicolour mode enable (1 = MC char mode)
$D011 bits 0-2: vertical fine scroll (0-7)

$D018 screen/charset pointer:
  Screen A:    $D018 = %00010001  → screen at $C000, charset at $E000
  Screen B:    $D018 = %00010101  → screen at $C400, charset at $E000
  (charset B at $E800 selected by $D018 = %00010011 / %00010111 — HUD raster)

Multicolour character mode colour registers:
  $D021  Background colour 0  (shared by all MC chars)
  $D022  Multicolour 1        (shared by all MC chars — colour bits %01)
  $D023  Multicolour 2        (shared by all MC chars — colour bits %10)
  $D800+ Colour RAM           (per-character, nybble — colour bits %11)

  In MC mode each pixel is 2 bits wide (4 pixels per char row instead of 8).
  The four 2-bit codes map to colours:
    %00 = $D021 (background)
    %01 = $D022 (shared MC1)
    %10 = $D023 (shared MC2)
    %11 = colour RAM nybble (per tile/character, the "foreground" colour)

Multicolour sprite registers (per sprite):
  $D025  Sprite multicolour 0 (shared, colour bits %01)
  $D026  Sprite multicolour 1 (shared, colour bits %11)
  $D027+ Individual sprite colour (bits %10, per sprite)

  MC sprite pixel layout (2 bits per pixel, 12 pixels wide visible):
    %00 = transparent
    %01 = $D025 (shared MC0)
    %10 = individual sprite colour ($D027+N)
    %11 = $D026 (shared MC1)

Sprite pointers:
  Screen A sprites: $C3F8-$C3FF  (end of screen A page)
  Screen B sprites: $C7F8-$C7FF  (end of screen B page)

Sprite frame slot N address = $C800 + (N × 64)  for N = 0-31
                             = $F000 + ((N-32) × 64)  for N = 32-94
Sprite pointer value = address / 64  (VIC bank-relative)
```

Double-buffer swap = one write to $D018. Takes effect next raster line.

**Colour register initialisation (at startup and level load):**

```kickasm
// Multicolour character mode — tile background and shared colours
// These are set at level load from LevelDesc colour data

.const VIC_BGCOL0   = $D021     // background (all tiles)
.const VIC_MC1      = $D022     // shared multicolour 1
.const VIC_MC2      = $D023     // shared multicolour 2
.const VIC_BORDER   = $D020     // border colour

// Multicolour sprite shared colours
.const VIC_SPR_MC0  = $D025     // sprite shared MC0
.const VIC_SPR_MC1  = $D026     // sprite shared MC1

// Enable multicolour char mode
lda $D016
ora #%00010000                  // set bit 4 = MC char mode
sta $D016

// Enable multicolour for all sprites ($D01C — one bit per sprite)
lda #%11111111
sta $D01C
```

### 2.4 KERNAL Bank-Out

At startup, after copying all needed ROM routines to RAM:

```kickasm
// Bank out KERNAL, expose RAM at $E000-$FFFF
// CPU port at $01 controls memory map
// %00110101 = BASIC off, KERNAL off, I/O on, RAM under $E000-$FFFF

lda #%00110101
sta $01
```

The IRQ/NMI vectors at $FFFA-$FFFF must be written to RAM before banking
out, pointing to the engine's RAM-resident handlers.

---

## 3. Cartridge Bank Layout

### 3.1 EasyFlash Overview

EasyFlash provides 64 banks × 16KB = 1MB total.
Each bank is split: low 8KB at $8000 (via $DE00), high 8KB at $A000 (via $DE01).
Both windows can be set to the same bank for 16KB access, or independently
for separate low/high sources.

### 3.2 Bank Assignments

```
Bank 00 LOW    Engine bootstrap + startup code
Bank 00 HIGH   Lookup table data (copied to $3000-$3FFF at startup)

Bank 01 LOW    World 1 map data       (up to 8KB — 256×128 or 128×256 tiles)
Bank 01 HIGH   World 1 object data    (level object placement)

Bank 02 LOW    World 2 map data
Bank 02 HIGH   World 2 object data

Bank 03 LOW    World 3 map data
Bank 03 HIGH   World 3 object data

Bank 04 LOW    World 4 map data
Bank 04 HIGH   World 4 object data

Bank 05 LOW    World 1 Charset A      (2KB tileset — only low 8K needed)
Bank 06 LOW    World 2 Charset A
Bank 07 LOW    World 3 Charset A
Bank 08 LOW    World 4 Charset A
               (Charset B / HUD font is fixed — loaded once at startup,
                never replaced. Stored in Bank 05 HIGH.)

Bank 09 LOW    Enemy type definitions (copied to RAM at each level load)
Bank 09 HIGH   Item / collectable definitions

Bank 10        Music track data (all worlds, up to 16KB)
Bank 11        SFX data

Bank 12        Sprite frames — player + common enemies (all worlds)
Bank 13        Sprite frames — world 1 specific enemies + boss
Bank 14        Sprite frames — world 2 specific enemies + boss
Bank 15        Sprite frames — world 3 specific enemies + boss
Bank 16        Sprite frames — world 4 specific enemies + boss

Bank 17-19     Cutscene scripts, dialogue, story text

Bank 20-63     Reserved for expansion / additional worlds
```

### 3.3 Bank Switch — Kick Assembler Macros

All bank switching executes from RAM. The cartridge window is never executed
during gameplay — it is a data source only.

```kickasm
.const ENGINE_BANK = 0

// Switch both windows to same bank (full 16KB access)
.macro BankIn(bank) {
    lda #bank
    sta $DE00
    sta $DE01
}

// Switch low window only ($8000, 8KB)
.macro BankInLo(bank) {
    lda #bank
    sta $DE00
}

// Switch high window only ($A000, 8KB)
.macro BankInHi(bank) {
    lda #bank
    sta $DE01
}

// Restore engine bank (called after any cartridge access)
.macro BankOut() {
    lda #ENGINE_BANK
    sta $DE00
    sta $DE01
}
```

Bank switch costs ~9 cycles. During gameplay this never occurs — all
required data for the current level is already in RAM.

### 3.4 Sprite Frame Index Table

Loaded from Bank 09 HIGH at startup. Maps enemy type → cartridge location:

```kickasm
// Sprite frame index entry — one per enemy/object type
.struct SpriteIndex {
    cart_bank,          // which cartridge bank holds frames
    cart_offset_lo,     // address within bank (low byte)
    cart_offset_hi,     // address within bank (high byte)
    frame_count,        // number of 64-byte frames
    ram_slot_base       // assigned RAM slot (0-94), filled at level load
}

// Table lives at $3600, copied from cartridge at startup
SpriteIndexTable:
    // Player
    .fill SpriteIndex.size, SpriteIndex(12, <$8000, >$8000, 12, 0)
    // Enemy type 1
    .fill SpriteIndex.size, SpriteIndex(13, <$8300, >$8300,  4, 0)
    // Enemy type 2
    .fill SpriteIndex.size, SpriteIndex(13, <$8400, >$8400,  6, 0)
    // ... etc
```

### 3.5 Startup Sequence

```
POWER ON (EasyFlash maps bank 00 automatically)
  1.  SEI — disable interrupts
  2.  LDA #$FF : STA $01 — full ROM map initially
  3.  Copy engine code  $8000-$9FFF → $0400-$0FFF
  4.  Copy lookup tables $A000-$BFFF → $3000-$3FFF
  5.  Copy music player from Bank 10 → $1000
  6.  Copy HUD charset (Bank 05 HIGH) → $E800  (Charset B, permanent)
  7.  Copy sprite index table (Bank 09 HIGH) → $3600
  8.  Bank out KERNAL: LDA #%00110101 : STA $01
  9.  Write IRQ/NMI vectors to $FFFA-$FFFF (RAM now visible there)
  10. Initialise VIC-II for bank 3 (see Section 2.3)
  11. Silence SID
  12. Load world 1 assets (call LevelLoad routine, Section 11.2)
  13. Set up raster IRQ chain
  14. CLI — enable interrupts
  15. JMP to main game loop
```

---

## 4. Map System

### 4.1 Map Format (Cartridge)

One bank per world. Low 8KB = tile map data, High 8KB = object placement data.

**Map header (at $8000 in map bank):**

```kickasm
.struct MapHeader {
    width,          // map width in tiles  (1 byte, max 256)
    height,         // map height in tiles (1 byte, max 256)
    tile_count,     // distinct tiles used (1 byte, for validation)
    reserved,       // padding
    name            // 8-byte map name string
}
// Tile data begins at $8000 + MapHeader.size, row-major, 1 byte/tile
// Max map: 256×128 = 32768 tiles — fits in 8KB with header
```

### 4.2 Graphics Mode — Multicolour Characters

All tiles and sprites use **multicolour mode** throughout. This gives
richer visual appearance at the cost of halved horizontal resolution
(each MC pixel is 2 screen pixels wide = 4 unique pixels per char row
instead of 8).

In multicolour character mode the four pixel values per character are:

```
Pixel bits  Colour source          Register     Per
──────────────────────────────────────────────────────
%00         Background colour 0    $D021        Global
%01         Multicolour 1          $D022        Global
%10         Multicolour 2          $D023        Global
%11         Colour RAM nybble      $D800+       Per character
```

This gives each tile access to 3 shared colours + 1 per-character
foreground colour. The 3 shared colours ($D021, $D022, $D023) are set
at level load and define the world palette. Per-character colours are
stored in colour RAM and updated by the colour RAM shift routine during
scrolling.

**Practical colour allocation per world:**

```kickasm
// Set at level load — defines the world's shared palette
// Values stored in LevelDesc and written to VIC registers at load time

.const TILE_BGCOL  = $D021    // e.g. black (background of all tiles)
.const TILE_MC1    = $D022    // e.g. dark grey (shadow/shade colour)
.const TILE_MC2    = $D023    // e.g. dark blue (secondary fill)
// $D800 colour RAM = per-tile foreground (e.g. green for grass, brown for dirt)
```

Multicolour sprites use their own shared registers ($D025, $D026) plus
an individual colour per sprite ($D027+). See Section 2.3.

### 4.3 Tile Definition Table

Loaded from cartridge into RAM. Each tile is 2×2 characters = 16×16 pixels
(4 effective MC pixels wide × 16 pixels tall). Each tile entry stores
character indices and the per-character colour RAM value for each of its
4 cells. The global MC colours ($D021-$D023) are implicit and not stored
per tile.

Each tile = 5 bytes:

```kickasm
.struct TileDef {
    char_tl,        // character code top-left
    char_tr,        // character code top-right
    char_bl,        // character code bottom-left
    char_br,        // character code bottom-right
    flags           // bit0=solid, bit1=hazard, bit2=animated, bit3=special
                    // bits 4-7: material type (used for collision sorting)
}

// Colour RAM values are stored separately in the tile colour table
// (one byte per tile, the %11 colour RAM nybble value, 0-15)
// This matches CharPad Pro's "Per Tile" colour mode export

.struct TileColour {
    colour          // colour RAM value for all 4 chars of this tile
                    // (same colour applied to all 4 cells — Per Tile mode)
}

.const TILE_FLAG_SOLID   = %00000001
.const TILE_FLAG_HAZARD  = %00000010
.const TILE_FLAG_ANIM    = %00000100
.const TILE_FLAG_SPECIAL = %00001000

// Material type in bits 4-7 (matches CharPad material sort order)
.const TILE_MAT_WALL     = %00010000    // solid impassable
.const TILE_MAT_FLOOR    = %00100000    // walkable surface
.const TILE_MAT_HAZARD   = %00110000    // damages player
.const TILE_MAT_WATER    = %01000000    // special movement
.const TILE_MAT_LADDER   = %01010000    // climbable
```

Two RAM tables are maintained from cartridge data:

```kickasm
// At $3500: tile flag cache — 1 byte per tile index, fast collision lookup
TileFlagsCache: .fill 256, 0

// At $3600+ (in lookup table area): tile colour cache — 1 byte per tile
TileColourCache: .fill 256, 0

// Full tile definition table — loaded from cartridge at level start
// 5 bytes × 256 tiles = 1280 bytes
TileDefTable: .fill 256 * TileDef.size, 0
```

Tiles are 2×2 characters = 16×16 pixels.
Blocks (coordinate unit) are 2×2 tiles = 4×4 characters = 32×32 pixels.

### 4.4 Map Descriptor (RAM, in $5800 area)

```kickasm
// Populated at level load, used throughout gameplay
map_width:      .byte 0         // tiles across
map_height:     .byte 0         // tiles down
map_bank:       .byte 0         // cartridge bank (for ring buffer refills)

// Precomputed row start addresses (avoid multiply during gameplay)
// Index by tile-Y to get base address of that row in ring buffer
map_row_lo:     .fill 256, 0
map_row_hi:     .fill 256, 0
```

Row table built at level load:

```kickasm
BuildRowTable:
    ldx #0
    lda #<RingBuffer        // $5000
    sta zp_scratch
    lda #>RingBuffer
    sta zp_scratch+1

.row_loop:
    lda zp_scratch
    sta map_row_lo,x
    lda zp_scratch+1
    sta map_row_hi,x

    // advance by map_width bytes (ring buffer row stride = 64)
    clc
    lda zp_scratch
    adc #64                 // ring buffer is always 64 tiles wide
    sta zp_scratch
    bcc .no_carry
    inc zp_scratch+1
.no_carry:
    inx
    cpx map_height
    bne .row_loop
    rts
```

### 4.5 Map Ring Buffer

A 64×32 tile sliding window in RAM at $5000 (2048 bytes). Holds the
visible area plus margin, avoiding full map RAM storage for large maps.

```
Ring buffer: 64 tiles wide × 32 tiles tall = 2048 bytes
Visible screen: 20 tiles wide × 12 tiles tall
Margin: ~22 tiles horizontal, ~10 tiles vertical
Refill trigger: camera within 8 tiles of buffer edge
```

The buffer uses modular indexing — no data shifts on scroll. Two origin
bytes track where buffer[0][0] maps in world coordinates:

```kickasm
ring_origin_x:  .byte 0     // world tile X at buffer column 0
ring_origin_y:  .byte 0     // world tile Y at buffer row 0

// Tile lookup at world position (wx, wy):
// buf_col = (wx - ring_origin_x) & 63
// buf_row = (wy - ring_origin_y) & 31
// address = map_row_lo/hi[buf_row] + buf_col
```

Ring buffer refills (adding a new column or row from cartridge) happen
between frames when the camera approaches the margin. Because this is
triggered well in advance, there is no timing pressure — the refill
completes over one or two frames during normal scroll operation.

---

## 5. Scroll Engine

### 5.1 Architecture

Two-layer system:

**Fine layer** — VIC-II hardware registers, zero CPU cost per pixel:
- $D016 bits 0-2: horizontal offset (0-7 pixels)
- $D011 bits 0-2: vertical offset (0-7 pixels)

**Coarse layer** — screen RAM data shift + edge fill, triggered when
fine register wraps through 0 or 7:
- Shifts 1000 bytes of screen RAM in scroll direction
- Fills newly exposed column/row from ring buffer
- Split across 2 frames (horizontal or vertical), 3 frames (diagonal)

### 5.2 Scroll State (Zero Page)

```kickasm
// All in zero page for fast access
.label cam_x_hi    = $08    // camera world block X
.label cam_x_lo    = $09    // camera sub-block X
.label cam_y_hi    = $0A
.label cam_y_lo    = $0B
.label fine_x      = $0C    // current $D016 fine value (0-7)
.label fine_y      = $0D
.label scroll_flags= $0E    // direction bits
.label shift_phase = $0F    // 0=first half, 1=second half

// Velocity — set by game logic each frame
scroll_vx:  .byte 0         // signed pixels/frame (-4 to +4)
scroll_vy:  .byte 0

// Pending coarse shift flags
shift_pending:  .byte 0     // bit0=H needed, bit1=V needed
active_screen:  .byte 0     // 0=screen A, 1=screen B
```

### 5.3 Per-Frame Scroll Sequence

IRQ1 fires at raster line 250 (below active display):

```kickasm
ScrollIRQ:
    asl $D019               // acknowledge IRQ

    // 1. Update camera position
    clc
    lda cam_x_lo
    adc scroll_vx
    sta cam_x_lo
    lda cam_x_hi
    adc #0                  // propagate carry
    sta cam_x_hi
    // (repeat for Y)

    // 2. Extract fine scroll from sub-block (top 3 bits of cam_lo)
    lda cam_x_lo
    lsr : lsr : lsr : lsr : lsr    // >> 5, gives 0-7
    sta fine_x
    lda cam_y_lo
    lsr : lsr : lsr : lsr : lsr
    sta fine_y

    // 3. Detect wrap — compare with previous fine values
    //    (previous stored in temp; if crossed 0 or 7, set shift_pending)

    // 4. Write fine registers
    lda fine_x
    ora #%11000000          // preserve 25-col + multicolour bits
    sta $D016
    lda fine_y
    ora #%10011000          // preserve raster MSB + 25-row bit
    sta $D011

    // 5. Phase 0 coarse shift (rows 0-12 of hidden screen)
    lda shift_phase
    bne .skip_phase0
    lda shift_pending
    beq .skip_phase0
    jsr ShiftScreenHalf0    // shift rows 0-12
    inc shift_phase
.skip_phase0:

    // 6. Swap visible screen ($D018)
    //    (shows buffer completed last frame)
    jsr SwapScreenBuffer

    rti
```

IRQ2 fires at raster line ~280 (vertical blank):

```kickasm
ScrollIRQ2:
    asl $D019

    // Phase 1 — complete shift, fill edge, update colour RAM
    lda shift_phase
    beq .done
    jsr ShiftScreenHalf1    // rows 13-24
    jsr FillExposedEdge     // fill new column or row from ring buffer
    jsr UpdateColourRAM     // shift colour RAM to match
    lda #0
    sta shift_phase
    sta shift_pending

.done:
    // Reprogram IRQ1 for next frame
    lda #250
    sta $D012
    lda #<ScrollIRQ
    sta $FFFE
    lda #>ScrollIRQ
    sta $FFFF
    rti
```

### 5.4 Screen Shift Macros

Kick Assembler generates the unrolled inner loops at assemble time:

```kickasm
// Shift one page of screen left (scroll right)
// src_page/dst_page are assemble-time constants
.macro ShiftPageLeft(dst_page, src_page) {
    ldx #0
    .for (var i = 0; i < 32; i++) {    // 32 iterations × 4 bytes = 128 bytes
        lda src_page * 256 + (i*4) + 1, x
        sta dst_page * 256 + (i*4) + 0, x
        lda src_page * 256 + (i*4) + 2, x
        sta dst_page * 256 + (i*4) + 1, x
        lda src_page * 256 + (i*4) + 3, x
        sta dst_page * 256 + (i*4) + 2, x
        lda src_page * 256 + (i*4) + 4, x
        sta dst_page * 256 + (i*4) + 3, x
    }
}
```

Four directional shift routines exist (left, right, up, down). Each
operates on the hidden screen buffer only. Diagonal scrolling sets
both H and V shift_pending bits — phase 0 handles horizontal,
phase 1 handles vertical, requiring a 3-frame completion window.

### 5.5 Edge Fill

After shifting, the exposed column or row is filled from the ring buffer:

```kickasm
FillRightColumn:
    // Fill column 39 of hidden screen
    // World tile X = cam_x_hi + SCREEN_TILE_W (20 tiles)
    // World tile Y = cam_y_hi + row (for each row 0-24)

    ldx #0                  // row counter
.row_loop:
    // Compute ring buffer tile coords for this screen row
    clc
    lda cam_y_hi
    adc RowTileOffsets,x    // precomputed: 0,0,1,1,2,2... (tile row per char row)
    tay
    clc
    lda cam_x_hi
    adc #20                 // right edge tile
    // ring buffer lookup → tile index in A

    // Expand tile to 2 chars (right half of 2×2 tile)
    .var tile_def_base = TileDefTable
    asl : asl : asl : asl   // × 16 (stride of extended tile def)
    tay
    lda tile_def_base + 1, y    // char_tr
    // write to column 39 of this character row
    // (using row address table)

    inx
    cpx #25
    bne .row_loop
    rts
```

### 5.6 Colour RAM

Colour RAM ($D800) cannot be double-buffered. Updated during the safe
border/blank window using the same split strategy as screen RAM:

- Upper half (rows 0-12): updated in IRQ1 safe window
- Lower half (rows 13-24): updated in IRQ2 / next frame

If tiles use per-block colour (one colour per 2×2 chars), only 1 in 4
colour bytes changes per scroll step — a 4× speedup. Recommended for
most tile types; per-character colour reserved for special tiles only.

### 5.7 Scroll Speed Limits

| Mode | Max speed | Coarse shift frames |
|------|-----------|-------------------|
| Horizontal only | 4 px/frame | 2 |
| Vertical only | 4 px/frame | 2 |
| Diagonal | 4 px/frame each axis | 3 |

At 50fps PAL this gives 200 pixels/second maximum per axis.

---

## 6. World Coordinate System

### 6.1 Fixed-Point Format

All world positions use 16-bit values with this structure:

```
High byte: block position  (0-255 blocks)
Low byte:  sub-block       (0-255, where 256 = 1 full block)

1 block = 4 characters = 32 pixels
Low byte resolution = 32/256 = 0.125 pixels (1/8 pixel accuracy)
```

This format unifies position, velocity, and map lookup — no conversion
between systems. Block index = high byte directly. Sub-pixel smoothness
comes free from the low byte.

```kickasm
.const BLOCK_PIXELS = 32

// Coordinate constants
.const HALF_SCREEN_BLOCKS_X = 10    // screen is ~20 tiles = 10 blocks wide
.const HALF_SCREEN_BLOCKS_Y =  6    // screen is ~12 tiles = 6 blocks tall

.const SCREEN_TILE_W  = 20
.const SCREEN_TILE_H  = 12
.const SCREEN_BLOCK_W = 10
.const SCREEN_BLOCK_H =  6
```

### 6.2 World-to-Screen Conversion

```kickasm
// Convert object world X → VIC sprite X register value
// Input:  obj_x_hi/lo (world position)
//         cam_x_hi/lo (camera position)
//         fine_x      (current hardware fine scroll, 0-7)
// Output: A = VIC sprite X (add to $D000 etc.)

WorldToScreenX:
    sec
    lda obj_x_lo,x
    sbc cam_x_lo
    sta zp_scratch
    lda obj_x_hi,x
    sbc cam_x_hi
    sta zp_scratch+1        // zp_scratch:+1 = screen position (block.sub)

    // pixel = (screen_block × 32) + (screen_sub >> 3)
    lda zp_scratch+1        // block part
    asl : asl : asl : asl : asl  // × 32
    sta zp_scratch+2
    lda zp_scratch          // sub-block part
    lsr : lsr : lsr         // >> 3 = pixel within block
    clc
    adc zp_scratch+2        // + coarse pixel
    adc fine_x              // + fine scroll compensation (CRITICAL)
    adc #24                 // + VIC left border offset
    rts
```

Fine scroll compensation on the last line is critical — without it,
sprites visually slide against the background during smooth scrolling.

### 6.3 Visibility Culling

Check block coordinates only — no pixel conversion needed:

```kickasm
.macro CullObject(obj_index) {
    // Horizontal check
    sec
    lda act_x_hi + obj_index
    sbc cam_x_hi
    cmp #(SCREEN_BLOCK_W + 2)   // screen width + 2 block margin
    bcs .off_screen

    // Vertical check
    sec
    lda act_y_hi + obj_index
    sbc cam_y_hi
    cmp #(SCREEN_BLOCK_H + 2)
    bcs .off_screen
    // visible — fall through
    jmp .visible
.off_screen:
    // set invisible flag, skip screen conversion
.visible:
}
```

### 6.4 Camera

Camera tracks player with optional lag. Clamped to map bounds.

```kickasm
UpdateCamera:
    // Target = player_x - half screen width
    sec
    lda player_x_lo
    sbc #$00
    sta cam_target_x_lo
    lda player_x_hi
    sbc #HALF_SCREEN_BLOCKS_X
    sta cam_target_x_hi

    // Simple snap (no lag) — replace with lerp for smooth follow
    lda cam_target_x_lo
    sta cam_x_lo
    lda cam_target_x_hi
    sta cam_x_hi

    // Clamp X to 0 .. (map_width_blocks - SCREEN_BLOCK_W)
    // (clamp Y similarly)
    rts
```

### 6.5 Background Collision

Direct map lookup from world coordinates — no screen conversion:

```kickasm
// Check solid tile at object's foot position
// Input: X = active object slot
// Output: Z=0 solid, Z=1 clear
CheckFloorCollision:
    lda act_y_hi,x
    clc
    adc #1                  // one block below object origin = feet
    tay
    lda map_row_lo,y
    sta zp_scratch
    lda map_row_hi,y
    sta zp_scratch+1        // point to correct ring buffer row

    ldy act_x_hi,x
    lda (zp_scratch),y      // tile index at foot position

    tay
    lda TileFlagsCache,y    // lookup cached flags byte ($3500)
    and #TILE_FLAG_SOLID    // Z=1 if not solid, Z=0 if solid
    rts
```

For objects wider than one block: check both act_x_hi and act_x_hi+1.
For tall objects: check multiple Y offsets.

---

## 7. Object Tracking System

### 7.1 Active Object Table (RAM, $0300)

Fixed pool of 16 objects processed every frame:

```kickasm
.const MAX_ACTIVE = 8   // hard budget — see Section 9 and 13

// Parallel arrays — indexed 0-15
// All at $0300 area for fast indexed access

act_x_hi:       .fill MAX_ACTIVE, 0    // world block X
act_x_lo:       .fill MAX_ACTIVE, 0    // sub-block X
act_y_hi:       .fill MAX_ACTIVE, 0
act_y_lo:       .fill MAX_ACTIVE, 0
act_vx:         .fill MAX_ACTIVE, 0    // velocity X (signed, same format)
act_vy:         .fill MAX_ACTIVE, 0    // velocity Y
act_type:       .fill MAX_ACTIVE, 0    // object type index
act_state:      .fill MAX_ACTIVE, 0    // AI state machine value
act_hp:         .fill MAX_ACTIVE, 0    // current hitpoints
act_timer:      .fill MAX_ACTIVE, 0    // general countdown
act_anim:       .fill MAX_ACTIVE, 0    // animation frame counter
act_spr_slot:   .fill MAX_ACTIVE, $FF  // logical sprite slot ($FF=none)
act_flags:      .fill MAX_ACTIVE, 0    // see below
act_lev_idx:    .fill MAX_ACTIVE, 0    // index back into level data array

// act_flags bit definitions
.const OBJ_FLAG_ACTIVE   = %10000000  // slot in use
.const OBJ_FLAG_VISIBLE  = %01000000  // on screen this frame
.const OBJ_FLAG_SOLID    = %00100000  // blocks player
.const OBJ_FLAG_DAMAGE   = %00010000  // damageable
.const OBJ_FLAG_FACE_R   = %00001000  // facing right (0=left)
.const OBJ_FLAG_INVIC    = %00000100  // invincible (hit flash)
.const OBJ_FLAG_HIT      = %00000010  // hit this frame
.const OBJ_FLAG_GROUND   = %00000001  // grounded
```

### 7.2 Level Data Array (RAM, $4000)

Persistent record for every object in the current level. Written from
cartridge at level load; survives for the level's duration. HP field
updated when active objects are deactivated.

```kickasm
.const MAX_LEVEL_OBJS = 255

lev_type:       .fill MAX_LEVEL_OBJS, 0    // object type
lev_x:          .fill MAX_LEVEL_OBJS, 0    // spawn block X
lev_y:          .fill MAX_LEVEL_OBJS, 0    // spawn block Y
lev_hp:         .fill MAX_LEVEL_OBJS, 0    // current HP (0=dead, never respawn)
lev_flags:      .fill MAX_LEVEL_OBJS, 0    // persistent flags

lev_count:      .byte 0     // total objects this level
lev_scan_ptr:   .byte 0     // rolling scan index (advances 16/frame)

.const LEV_FLAG_DEAD      = %10000000  // permanently dead/collected
.const LEV_FLAG_ACTIVATED = %01000000  // has been active at least once
```

### 7.3 Activation and Deactivation

Each frame, scan 16 level entries (rolling). Activate nearby objects
into the active table; deactivate distant active objects back to level data.

```kickasm
.const ACTIVATION_RADIUS_H   = 12  // blocks horizontal
.const ACTIVATION_RADIUS_V   =  8  // blocks vertical
.const DEACTIVATION_RADIUS   = 14  // slightly larger (prevents thrashing)

ScanLevelObjects:
    ldx lev_scan_ptr
    ldy #16

.scan_loop:
    // Skip permanently dead objects
    lda lev_flags,x
    bmi .next               // bit 7 = dead

    // Check horizontal block distance from camera
    sec
    lda lev_x,x
    sbc cam_x_hi
    cmp #ACTIVATION_RADIUS_H
    bcs .next

    // Check vertical block distance
    sec
    lda lev_y,x
    sbc cam_y_hi
    cmp #ACTIVATION_RADIUS_V
    bcs .next

    // In range — attempt activation (find free active slot)
    stx zp_scratch          // preserve scan index
    jsr ActivateObject
    ldx zp_scratch

.next:
    inx
    cpx lev_count
    bne .no_wrap
    ldx #0
.no_wrap:
    dey
    bne .scan_loop
    stx lev_scan_ptr
    rts

DeactivateObject:
    // X = active slot
    ldy act_lev_idx,x
    lda act_hp,x
    sta lev_hp,y            // write HP back to level data

    // Free sprite slot
    lda act_spr_slot,x
    cmp #$FF
    beq .no_sprite
    tay
    lda #0
    sta spr_active,y
.no_sprite:
    lda #0
    sta act_flags,x         // mark slot free
    rts
```

### 7.4 Persistent State — Three Tiers

**Tier 1 — Bitfield (collectables, destructible scenery)**

One bit per level object slot = 32 bytes covers 256 objects.

```kickasm
dead_flags: .fill 32, 0     // at $5210

// Bitmask table for bit extraction
bitmask_table: .byte $01,$02,$04,$08,$10,$20,$40,$80

// Set object N as dead/collected
// A = object index (0-255)
SetDeadFlag:
    pha
    and #%00000111          // bit index within byte
    tax
    lda bitmask_table,x     // bit mask
    sta zp_scratch
    pla
    lsr : lsr : lsr         // byte index (N / 8)
    tax
    lda dead_flags,x
    ora zp_scratch
    sta dead_flags,x
    rts
```

**Tier 2 — HP writeback (enemies)**

Handled automatically by DeactivateObject (above). Zero HP = permanent
death; object never reactivates.

**Tier 3 — Sparse change log (doors, switches, triggers)**

```kickasm
.const MAX_CHANGES = 64

chg_obj_id: .fill MAX_CHANGES, $FF
chg_value:  .fill MAX_CHANGES, 0
chg_count:  .byte 0

LookupChange:
    // Input: A = object index to look up
    // Output: carry set = found, A = stored value
    //         carry clear = not found (use level data default)
    ldx #0
.loop:
    cpx chg_count
    beq .not_found
    cmp chg_obj_id,x
    beq .found
    inx
    bne .loop
.not_found:
    clc
    rts
.found:
    lda chg_value,x
    sec
    rts
```

**Global flags (named bits, at $5220):**

```kickasm
global_flags_0: .byte 0
global_flags_1: .byte 0
global_flags_2: .byte 0

// Named constants — document per game
.const FLAG_RED_KEY     = %00000001    // global_flags_0
.const FLAG_BLUE_KEY    = %00000010
.const FLAG_DOOR_A_OPEN = %00000100
.const FLAG_BOSS_DEAD   = %00001000
.const FLAG_INTRO_DONE  = %00010000
```

### 7.5 AI State Dispatch

Two-level jump table: type → state handler.

```kickasm
UpdateActiveObjects:
    ldx #0
.loop:
    lda act_flags,x
    bpl .skip               // bit 7 clear = inactive slot

    // Dispatch on type
    lda act_type,x
    asl
    tay
    lda TypeHandlerHi,y
    pha
    lda TypeHandlerLo,y
    pha
    rts                     // jumps via stack trick

    // Handler returns here via RTS
.skip:
    inx
    cpx #MAX_ACTIVE
    bne .loop
    rts

// Within each type handler, dispatch on state:
GuardUpdate:
    lda act_state,x
    asl
    tay
    lda GuardStateHi,y
    pha
    lda GuardStateLo,y
    pha
    rts

// State constants for guard type
.const GUARD_IDLE    = 0
.const GUARD_PATROL  = 1
.const GUARD_ALERT   = 2
.const GUARD_CHASE   = 3
.const GUARD_ATTACK  = 4
.const GUARD_HURT    = 5
```

---

## 8. Sprite Multiplexer

### 8.1 Overview

VIC-II provides 8 hardware sprites. The multiplexer presents up to 24
logical sprites by reassigning hardware sprites between raster lines.

```
Hardware sprites: 8
Logical sprites:  24
Min raster gap between reuse of same hardware channel: ~42 lines
                 (sprite height 21 × 2 safety margin)
```

### 8.2 Logical Sprite Table

```kickasm
.const MAX_SPRITES = 24

spr_x:          .fill MAX_SPRITES, 0
spr_xhi:        .fill MAX_SPRITES, 0   // bit 0 = X MSB (9th bit)
spr_y:          .fill MAX_SPRITES, 0
spr_frame:      .fill MAX_SPRITES, 0   // slot index (0-94)
spr_colour:     .fill MAX_SPRITES, 0
spr_priority:   .fill MAX_SPRITES, 0   // 0=foreground, 1=behind bg
spr_active:     .fill MAX_SPRITES, 0   // 0=unused
spr_owner:      .fill MAX_SPRITES, $FF // which active object owns slot
```

### 8.3 Sort and IRQ Chain

Once per frame: insertion sort logical sprites by Y position.
Then set up raster IRQ chain — one IRQ per hardware sprite group:

```kickasm
// Multiplex IRQ — fires at precalculated raster line
MuxIRQ:
    asl $D019               // acknowledge

    ldx mux_group_ptr       // index into sorted sprite list

    // Write 8 hardware sprite Y positions (unrolled)
    lda spr_y,x   : sta $D001
    lda spr_y+1,x : sta $D003
    lda spr_y+2,x : sta $D005
    lda spr_y+3,x : sta $D007
    lda spr_y+4,x : sta $D009
    lda spr_y+5,x : sta $D00B
    lda spr_y+6,x : sta $D00D
    lda spr_y+7,x : sta $D00F

    // X positions and MSBs (packed into $D010)
    // Colours ($D027-$D02E)
    // Frame pointers ($C3F8-$C3FF or $C7F8-$C7FF per active screen)
    // Enable bits ($D015)
    // ... (similar unrolled writes)

    // Advance to next group
    lda mux_group_ptr
    clc
    adc #8
    sta mux_group_ptr

    // Set next IRQ line
    lda next_mux_line
    sta $D012

    rti
```

### 8.4 Sprite Frame RAM Slots

```
Slots  0-31: $C800-$CFFF  (32 × 64 bytes = 2KB)
Slots 32-94: $F000-$FEFF  (63 × 64 bytes = 4032 bytes)
Total: 95 slots

Slot N address:
  N < 32:  $C800 + (N × 64)
  N >= 32: $F000 + ((N - 32) × 64)

VIC pointer value = slot_address / 64  (relative to bank 3 base $C000)
```

### 8.5 Sprite Frame Budget (Per Level)

```kickasm
// Assemble-time budget check — assembler errors if exceeded
.const PLAYER_FRAMES   = 12
.const ENEMY_A_FRAMES  =  4
.const ENEMY_B_FRAMES  =  4
.const ENEMY_C_FRAMES  =  6
.const ENEMY_D_FRAMES  =  4
.const BOSS_FRAMES     =  8
.const FX_FRAMES       =  8
.const COLLECT_FRAMES  =  6
.const ENV_FRAMES      =  8
.const HUD_FRAMES      =  4
.const RESERVE_FRAMES  = 31  // unused this level

.const TOTAL_FRAMES = PLAYER_FRAMES + ENEMY_A_FRAMES + ENEMY_B_FRAMES
                    + ENEMY_C_FRAMES + ENEMY_D_FRAMES + BOSS_FRAMES
                    + FX_FRAMES + COLLECT_FRAMES + ENV_FRAMES
                    + HUD_FRAMES + RESERVE_FRAMES

.print "Sprite frame slots used: " + (TOTAL_FRAMES - RESERVE_FRAMES) + " / 95"

.if (TOTAL_FRAMES > 95) {
    .error "Sprite frame budget exceeded! Total=" + TOTAL_FRAMES
}
```

---


## 9. Object Type Definitions (Cartridge Bank 09)

Copied to RAM at level load. Defines behaviour parameters for all
enemy and item types. Up to 64 types in a 1KB table.

Two fields have been added relative to earlier versions: `coll_group`
and `coll_mask`, which drive the software collision system (Section 9.1).

```kickasm
.struct EnemyTypeDef {
    max_hp,             // maximum hitpoints
    move_speed,         // sub-block units per frame
    damage,             // damage dealt to player per hit
    score,              // score value div 10
    spr_index,          // index into SpriteIndexTable
    ai_flags,           // behaviour flags (see below)
    act_radius_h,       // activation radius override H (0=use default)
    act_radius_v,       // activation radius override V (0=use default)
    box_w,              // collision box width in blocks
    box_h,              // collision box height in blocks
    drop_type,          // item dropped on death (0=none)
    drop_prob,          // drop probability (0-255)
    coll_group,         // which collision group this type belongs to
    coll_mask,          // which collision groups this type responds to
    reserved0,
    reserved1           // pad to 16 bytes
}

// AI behaviour flags
.const AI_FLAG_PATROL   = %00000001
.const AI_FLAG_FLIES    = %00000010
.const AI_FLAG_SHOOTS   = %00000100
.const AI_FLAG_FOLLOWS  = %00001000
.const AI_FLAG_ARMOURED = %00010000

// Collision groups — one bit per category
.const CGROUP_PLAYER      = %00000001
.const CGROUP_ENEMY       = %00000010
.const CGROUP_PICKUP      = %00000100
.const CGROUP_PLAYER_PROJ = %00001000
.const CGROUP_ENEMY_PROJ  = %00010000

// Collision mask examples (what each type responds to):
// Player:      CGROUP_ENEMY | CGROUP_PICKUP | CGROUP_ENEMY_PROJ
// Enemy:       CGROUP_PLAYER_PROJ   (only hurt by player bullets)
// Pickup:      CGROUP_PLAYER        (only collected by player)
// Player proj: CGROUP_ENEMY         (hits enemies)

// Validation
.if (EnemyTypeDef.size != 16) {
    .error "EnemyTypeDef must be 16 bytes"
}
```

---

## 9.1 Software Collision Detection

With the KERNAL banked out and a sprite multiplexer active, the VIC-II
hardware collision registers ($D01E sprite-sprite, $D01F sprite-background)
are unreliable. Physical hardware sprite assignments change every few raster
lines as the multiplexer reassigns them — a hardware collision between physical
sprites 2 and 5 carries no information about which logical sprites overlapped.

**Full software collision detection is mandatory.** Background collision
(object vs solid tile) is handled separately and cheaply via map lookup
(Section 6.5). This section covers sprite-sprite collision only.

The collision system is based on a five-stage cascade, informed by TNT's
implementation for Paradroid Redux — which demonstrated that per-sprite
span masks give exact pixel-level collision at acceptable cycle cost when
combined with aggressive early rejection. The approach is documented at
https://sid.fi/~tnt/c64/paradroid/coltest.html

The key insight from that work: most pairs are rejected in the first two
or three stages at very low cost; the expensive per-row span check fires
only when overlap is geometrically certain and the pair type requires it.
This means average-case cost is very low while worst-case is bounded and
predictable.

### 9.1.1 Why 8 Objects Is The Right Budget

Brute-force pairwise checking scales as O(n²):

```
 8 active objects:  8×7/2 =  28 pairs
16 active objects: 16×15/2 = 120 pairs
```

With the five-stage cascade, typical cost per pair is 35-60 cycles for
the vast majority of pairs that get rejected early. Only pairs that pass
all broad-phase filters reach the expensive geometry check (~450 cycles).
With 8 objects, total collision budget is comfortably under 1,200 cycles
at 50fps. 16 objects risks ~2,500 cycles on crowded frames.

### 9.1.2 Overview: Five-Stage Cascade

```
Stage 1  Activity check       ~8 cycles   skip inactive slots
Stage 2  Y broad phase        ~16 cycles  skip if Y gap > max sprite height
Stage 3  Group mask check     ~20 cycles  skip non-interacting type pairs
Stage 4  Signed dx/dy check   ~40 cycles  skip if outside sprite pixel bounds
Stage 5  Geometry check       ~10-450 c   type-dispatched (table or span mask)
```

Stages 1-4 together reject ~95% of pairs in typical gameplay.
Stage 5 fires only when actual pixel overlap is plausible.

### 9.1.3 Stage 1 — Activity Check

Inlined by KickAssembler's .for loop for each pair:

```kickasm
// Both slots must be active (bit 7 of act_flags set)
lda act_flags + i       // assemble-time constant i
bpl !skip+              // bit 7 clear = inactive
lda act_flags + j
bpl !skip+
// ~8 cycles if either slot inactive (common)
```

### 9.1.4 Stage 2 — Y Broad Phase

The inverted Y-sort (Section 5) keeps sprites ordered by screen Y.
Since j > i in the sorted list, j.y >= i.y always. The gap check
becomes a simple subtraction with an early-exit that breaks the
inner loop when the gap is too large:

```kickasm
.const MAX_SPR_HEIGHT_PX = 21   // C64 sprite is 21 pixels tall

// Y positions are screen pixels in act_y tables
sec
lda act_y + j           // j is always below or equal to i in sort
sbc act_y + i
cmp #MAX_SPR_HEIGHT_PX
bcs !skip+              // gap >= 21px — can't overlap
                        // AND since sorted, all further j also skip
// ~16 cycles
```

The break-inner-loop property of the Y sort is retained from the
original design — when the Y gap is too large, the remaining j
iterations for this i are skipped entirely, not just this one pair.

### 9.1.5 Stage 3 — Collision Group Mask

Each object type has a group (what it is) and a mask (what it
responds to). Encoded in EnemyTypeDef.coll_group and coll_mask.
The check is one AND and a branch:

```kickasm
// TypeCollGroup[type] = group bits for this type
// TypeCollMask[type]  = which groups this type responds to

lda act_type + i
tay
lda TypeCollGroup, y    // group of object i
ldy act_type + j
and TypeCollMask, y     // does i's group appear in j's mask?
beq !skip+              // no interaction between these types

// Symmetrically: also check j's group against i's mask
// (one type may respond to the other but not vice versa)
lda TypeCollGroup - MAX_ACTIVE, y   // TypeCollGroup[type_j]
ldy act_type + i
and TypeCollMask, y
beq !skip+
// ~20 cycles total
```

Group constants (same as Section 9):

```kickasm
.const CGROUP_PLAYER      = %00000001
.const CGROUP_ENEMY       = %00000010
.const CGROUP_PICKUP      = %00000100
.const CGROUP_PLAYER_PROJ = %00001000
.const CGROUP_ENEMY_PROJ  = %00010000
```

Type dispatch index is extracted from the type pair for Stage 5:

```kickasm
// Build 4-bit dispatch index from two type bits each
// Following TNT's technique: extract bits 5-6 of each type byte
// and combine into a 4-bit index into a jump offset table

lda act_type + j        // 0YY.....
lsr : lsr
eor act_type + i        // 0XXy y...
and #$18
eor act_type + i        // 0XXYY...
lsr : lsr : lsr         // 0000XXYY
tax
lda CollTypeJumpLo, x
sta zp_coll_jmp
lda CollTypeJumpHi, x
sta zp_coll_jmp+1
// type dispatch pointer ready for Stage 5
```

### 9.1.6 Stage 4 — Signed dx/dy Range Check

Sprite pixel overlap is impossible if the absolute X distance exceeds
23 pixels (sprite width) or absolute Y distance exceeds 20 pixels
(sprite height). This check uses proper signed 16-bit X arithmetic
following TNT's method, correcting the approximate absolute value
used in the earlier AABB design:

```kickasm
// --- X distance (signed 16-bit, since X spans 0-320+) ---
sec
lda act_x_lo + i        // low byte of world X (sub-block precision)
sbc act_x_lo + j
sta zp_dx
lda act_x_hi + i        // block X (high byte)
sbc act_x_hi + j
bcc .dx_neg             // result negative

bne !skip+              // high byte non-zero and positive = dx > 255, skip
lda zp_dx
cmp #24                 // dx in [0,23]?
bcs !skip+              // no
bcc .dx_ok

.dx_neg:
cmp #$FF                // high byte must be $FF for dx in [-23,-1]
bne !skip+
lda zp_dx
cmp #<(-23)             // dx in [-23,-1]?
bcc !skip+
eor #$FF
clc
adc #1                  // abs(dx) now in A
.dx_ok:
sta zp_abs_dx

// --- Y distance (8-bit — screen Y fits in one byte) ---
sec
lda act_y + i
sbc act_y + j
bcc .dy_neg
cmp #21                 // dy in [0,20]?
bcs !skip+
bcc .dy_ok
.dy_neg:
cmp #<(-21)             // dy in [-21,-1]?
bcc !skip+
eor #$FF
clc
adc #1
.dy_ok:
sta zp_abs_dy
// ~40 cycles total — exact signed arithmetic, no approximation
```

### 9.1.7 Stage 5 — Type-Dispatched Geometry Check

The dispatch pointer built in Stage 3 now jumps to one of three handlers:

```kickasm
jmp (zp_coll_jmp)       // dispatch to geometry handler for this type pair

// Handler addresses in CollTypeJumpLo/Hi table (16 entries):
// Index = 4-bit type pair code from Stage 3
// 0: explosion-explosion  → skip (handled earlier by group mask)
// 1: droid-explosion      → SymmetricTableCheck (DroidXplosDX table)
// 2: droid-droid          → SymmetricTableCheck (DroidDroidDX table)
// 3: droid-bullet         → SpanMaskCheck
// 4: bullet-explosion     → SpanMaskCheck
// 5: bullet-bullet        → skip (bullets don't interact)
// ... (fill remaining entries per game design)
```

**Handler A — Symmetric Table Check (~10 cycles)**

For type pairs where both sprites are rotationally symmetrical
(same shape mirrored), a 21-entry lookup table gives the minimum
non-colliding abs(dx) at each abs(dy) row. One compare and done:

```kickasm
// DroidDroidDX: minimum non-colliding dx at each dy row (21 entries)
// DroidXplosDX: same for droid-explosion pairs
// Values derived from actual sprite pixel masks

DroidDroidDX:
    .byte 23,23,23,23,22,22,21,21,20,19
    .byte 18,17,16,15,13,11, 7, 3, 0, 0, 0

DroidXplosDX:
    .byte 19,19,19,19,18,18,17,17,16,15
    .byte 14,13,12,10, 8, 4, 0, 0, 0, 0, 0

SymmetricTableCheck:
    // zp_abs_dx and zp_abs_dy already computed in Stage 4
    ldx zp_abs_dy
    lda zp_abs_dx
    cmp CollTablePtr, x     // CollTablePtr set to DroidDroidDX or DroidXplosDX
    bcs !skip+              // dx >= table value = no collision
    jmp LogCollision        // collision confirmed
    // ~10 cycles on collision path, ~8 on no-collision
```

Add new table entries for each symmetrical sprite type pair in the
game. Two bytes × 21 rows = 42 bytes per table. Each world's enemy
types get their own tables, stored in cartridge Bank 09 and loaded
at level start.

**Handler B — Span Mask Check (~100-450 cycles)**

For asymmetric or complex shape pairs. Each sprite type has a
collision mask describing the filled horizontal span on each row:

```kickasm
// Collision mask format per sprite type (following TNT):
// empty_top[type]:    rows to skip at top of sprite
// height[type]:       number of non-empty rows
// minxskip[type]:     minimum empty pixels on left (for fast X pre-reject)
// collmask[type]:     array of (empty_left, span_width) pairs, one per row

// Pre-reject: if abs(dx) + minxskip[i] + minxskip[j] >= 24, no collision
// (sprites too narrow to overlap even at best alignment)
clc
lda zp_abs_dx
adc MinXSkip, x         // MinXSkip[type_i]
adc MinXSkip, y         // MinXSkip[type_j]
cmp #24
bcs !skip+              // too narrow — exit (~15 cycles)

// Compute real_dy = dy + empty_top[type_i] - empty_top[type_j]
// Determines which sprite's mask starts higher on screen
clc
lda zp_dy               // signed dy (i relative to j)
adc EmptyTop, x         // + empty_top[type_i]
sec
sbc EmptyTop, y         // - empty_top[type_j]
bpl .spr_j_higher       // sprite j's content starts higher

// Sprite i is higher — check if it reaches j's content
clc
adc Height, x           // + height[type_i] - 1
bmi !skip+              // i doesn't reach j — no collision
sta zp_num_lines        // number of overlapping rows - 1

// Set mask pointers:
// pt1 → collmask[type_i] + skip*2  (skip lines of i above j)
// pt2 → collmask[type_j]           (j starts from its top)
// ... (pointer arithmetic as shown in TNT's implementation)
jmp .check_rows

.spr_j_higher:
// Mirror case: j higher than i
// ... symmetric pointer setup
// fall through to .check_rows

// Per-row span overlap check:
.check_rows:
    ldx zp_num_lines
    ldy #0
.row_loop:
    clc
    lda zp_dx               // signed x distance
    adc (zp_pt1), y         // + empty_left[mask_i, row]
    sec
    sbc (zp_pt2), y         // - empty_left[mask_j, row]
    bpl .span_j_left        // mask_i starts right of mask_j

    // mask_i starts left of mask_j — does it reach?
    iny
    clc
    adc (zp_pt1), y         // + span_width[mask_i, row] - 1
    bmi .next_row           // no overlap on this row

    // Overlap confirmed on this row — collision
    jmp LogCollision

.span_j_left:
    // mask_j starts left — does it reach mask_i?
    iny
    clc
    sbc (zp_pt2), y         // - span_width[mask_j, row]
    bmi .coll_found         // overlap

    jmp .next_row

.coll_found:
    jmp LogCollision

.next_row:
    iny                     // advance past width byte to next row's data
    dex
    bpl .row_loop
    // No collision on any row
    jmp !skip+
    // ~38 cycles per row, only overlapping rows checked
```

### 9.1.8 Collision Mask Data

Mask data is stored in cartridge Bank 09 alongside enemy type
definitions, loaded into RAM at level start.

```kickasm
// Per sprite type — collision mask descriptor (5 bytes + mask data)
.struct CollMaskDef {
    empty_top,          // rows to skip at top
    height,             // non-empty row count
    minxskip,           // minimum left margin (for fast pre-reject)
    mask_lo,            // address of (empty_left, span_width) pairs, low
    mask_hi             // address of (empty_left, span_width) pairs, high
}

// RAM tables (loaded from cartridge at level start):
EmptyTop:   .fill MAX_ENEMY_TYPES, 0
Height:     .fill MAX_ENEMY_TYPES, 0
MinXSkip:   .fill MAX_ENEMY_TYPES, 0
MaskPtrLo:  .fill MAX_ENEMY_TYPES, 0
MaskPtrHi:  .fill MAX_ENEMY_TYPES, 0

// Actual mask row data — variable length, packed
// 2 bytes per row: (empty_left, span_width)
// Total per type: height[type] * 2 bytes
// 16 types × avg 14 rows × 2 = ~448 bytes
// Stored contiguously; MaskPtrLo/Hi index into this block
CollMaskData: .fill 512, 0   // loaded from cartridge
```

Data budget:

```
Per type:  empty_top + height + minxskip = 3 bytes
           mask_ptr lo + hi              = 2 bytes
           mask row data (avg 14 rows)   = 28 bytes
           Total per type:               = 33 bytes

16 types:  ~528 bytes
Symmetric tables (2 × 21 bytes):          42 bytes
Type dispatch jump table (16 × 2 bytes):  32 bytes
─────────────────────────────────────────────────
Total collision data:                    ~602 bytes
```

All collision data fits within Bank 09 alongside EnemyTypeDef.

### 9.1.9 Unrolled Outer Loop

The full five-stage cascade is generated by KickAssembler for all 28
pairs at assemble time. No loop overhead — each pair is an inline
block of code:

```kickasm
.const COLL_PAIRS = MAX_ACTIVE * (MAX_ACTIVE - 1) / 2

CheckAllCollisions:
    .for (var i = 0; i < MAX_ACTIVE; i++) {
        .for (var j = i + 1; j < MAX_ACTIVE; j++) {

            // Stage 1: activity
            lda act_flags + i
            bpl !skip+
            lda act_flags + j
            bpl !skip+

            // Stage 2: Y broad phase
            sec
            lda act_y + j
            sbc act_y + i
            cmp #MAX_SPR_HEIGHT_PX
            bcs !skip+

            // Stage 3: group mask + build dispatch index
            lda act_type + i
            tay
            lda TypeCollGroup, y
            ldy act_type + j
            and TypeCollMask, y
            beq !skip+
            // (dispatch index built here — see 9.1.5)

            // Stage 4: signed dx/dy
            // (inline code from 9.1.6)

            // Stage 5: dispatch
            jmp (zp_coll_jmp)

        !skip:
        }
    }
    rts
```

Generated code size: ~1,200 bytes for 8 objects (larger than AABB
version due to Stage 4 signed arithmetic, but still well within the
engine block on cartridge).

### 9.1.10 Collision Event Queue

Detection logs pairs to a deferred queue. Response (damage, pickup
collection, projectile destruction) is processed after the full
detection pass, keeping the inner checker clean:

```kickasm
.const MAX_COLL_EVENTS = 8

// At $0380 in RAM (see Section 2.1)
coll_obj_a:     .fill MAX_COLL_EVENTS, $FF  // active slot i
coll_obj_b:     .fill MAX_COLL_EVENTS, $FF  // active slot j
coll_count:     .byte 0

LogCollision:
    lda coll_count
    cmp #MAX_COLL_EVENTS
    bcs .full               // queue full — drop (very rare with 8 objects)
    tax
    lda #i                  // assemble-time literal from .for context
    sta coll_obj_a, x
    lda #j
    sta coll_obj_b, x
    inc coll_count
.full:
    rts

ProcessCollisionEvents:
    ldx #0
.loop:
    cpx coll_count
    beq .done
    lda coll_obj_a, x
    tay
    lda act_type, y         // type of object i
    // dispatch to response handler based on type pair
    // player + enemy_proj  → apply damage, SFX
    // player + pickup      → collect, update persistent flags
    // enemy  + player_proj → damage enemy, check death, spawn FX
    inx
    bne .loop
.done:
    lda #0
    sta coll_count
    rts
```

### 9.1.11 Background Collision — Separate and Cheaper

Background collision (object vs solid tile) is O(n) and unaffected
by the multiplexer. Each object independently checks corner points
against the tile flag cache:

```
8 objects × 4 corner checks × ~20 cycles = 640 cycles
```

See Section 6.5 for the tile lookup implementation.

### 9.1.12 Collision Cost Summary

```
Stage               Cycles    Cumulative    Notes
────────────────────────────────────────────────────────────────────
1. Activity           8           8         Very common rejection
2. Y broad phase     16          24         Common rejection
3. Group mask        20          44         Frequent rejection
4. dx/dy range       40          84         Occasional rejection
5a. Sym table        10          94         Fast exact check
5b. Span mask       450         534         Full pixel accuracy
                                            ~38 cycles/row × 14 rows
────────────────────────────────────────────────────────────────────

8 objects, 28 pairs — typical gameplay distribution:
  16 pairs rejected stages 1-2:   16 × 24  =   384 cycles
   8 pairs rejected stages 3-4:    8 × 64  =   512 cycles
   3 pairs → symmetric table:      3 × 94  =   282 cycles
   1 pair  → span mask (10 rows):  1 × 474 =   474 cycles
────────────────────────────────────────────────────────────────────
Typical sprite-sprite total:                 ~1,652 cycles   (8.4%)
Worst case (many close sprites):            ~2,800 cycles  (14.2%)

Background collision (8 obj × 4 pts):          640 cycles   (3.3%)
Collision response processing:                  200 cycles   (1.0%)
────────────────────────────────────────────────────────────────────
TOTAL collision budget (typical):            ~2,492 cycles  (12.7%)
TOTAL collision budget (worst case):         ~3,640 cycles  (18.5%)
────────────────────────────────────────────────────────────────────
```

The cycle cost is higher than the original AABB design (~1,496 cycles
typical) but eliminates false positives entirely — no phantom hits
in sprite corners. For an action game, collision accuracy is worth
the additional ~1,000 cycles.

At worst case (18.5% of frame), combined with diagonal scroll
(27.1% headroom remaining from Section 11), the engine remains
within the 50fps budget. The split-tick fallback (Section 12)
is available if specific levels prove unusually collision-intensive.

## 10. Between-Levels Asset Loader

All cartridge asset transfers happen exclusively during level transitions.
No raster timing constraints apply — the screen is blanked during the load.

### 10.1 Level Descriptor Table

```kickasm
.struct LevelDesc {
    map_bank,           // cartridge bank: tile map (low) + objects (high)
    tileset_bank,       // cartridge bank: Charset A (low 2KB)
    sprite_bank_common, // cartridge bank: player + common sprite frames
    sprite_bank_world,  // cartridge bank: world-specific sprite frames
    music_track,        // SID track index to initialise
    start_x,            // player spawn block X
    start_y,            // player spawn block Y
    flags,              // bit0=clear dead_flags (new world)
    col_bg,             // $D021 background colour for this level
    col_mc1,            // $D022 shared multicolour 1
    col_mc2,            // $D023 shared multicolour 2
    col_border,         // $D020 border colour
    col_spr_mc0,        // $D025 sprite shared multicolour 0
    col_spr_mc1         // $D026 sprite shared multicolour 1
}

LevelTable:
    //              map  tiles  spr_c  spr_w  mus  sx  sy  fl   bg  mc1  mc2  brd  sm0  sm1
    .fill LevelDesc.size, LevelDesc( 1,  5,  12,  13,  0,  2,  4, %00000001,  0,  11,   9,  0,   1,  2)
    .fill LevelDesc.size, LevelDesc( 2,  6,  12,  14,  1,  1,  2, %00000000,  0,   5,   6,  0,   1,  2)
    .fill LevelDesc.size, LevelDesc( 3,  7,  12,  15,  1,  4,  1, %00000000,  0,   9,  10,  0,   1,  2)
    .fill LevelDesc.size, LevelDesc( 4,  8,  12,  16,  2,  2,  3, %00000001,  0,   8,  12,  0,   1,  2)
    // Colours: 0=black, 1=white, 2=red, 5=green, 6=blue, 8=orange,
    //          9=brown, 10=lt.red, 11=dk.grey, 12=grey
```

### 10.2 Copy Macro

```kickasm
// Copy N bytes from cartridge $8000+offset → dest in RAM
// Unrolls page loop at assemble time for efficiency
.macro CopyFromCart(dest, bytes) {
    .const pages = bytes / 256
    .const tail  = bytes - (pages * 256)

    .for (var p = 0; p < pages; p++) {
        ldx #0
    !:  lda $8000 + (p * 256),x
        sta dest  + (p * 256),x
        inx
        bne !-
    }

    .if (tail > 0) {
        ldx #(tail - 1)
    !:  lda $8000 + (pages * 256),x
        sta dest  + (pages * 256),x
        dex
        bpl !-
    }
}
```

### 10.3 Level Load Routine

```kickasm
// Input: Y = level index (0-based)
LevelLoad:
    // --- Fade to black ---
    jsr FadeOut             // decrements border/bg colours over 8 frames

    // --- Disable IRQ chain during load ---
    sei
    lda #<SimpleIRQAck
    sta $FFFE
    lda #>SimpleIRQAck
    sta $FFFF
    cli

    // --- Read level descriptor ---
    tya
    .var stride = LevelDesc.size
    // multiply Y by stride via lookup table
    lda LevelDescLo,y
    sta zp_ptr
    lda LevelDescHi,y
    sta zp_ptr+1

    ldy #LevelDesc.map_bank
    lda (zp_ptr),y
    sta current_map_bank

    ldy #LevelDesc.tileset_bank
    lda (zp_ptr),y
    sta current_tileset_bank

    ldy #LevelDesc.sprite_bank_common
    lda (zp_ptr),y
    sta current_spr_bank_c

    ldy #LevelDesc.sprite_bank_world
    lda (zp_ptr),y
    sta current_spr_bank_w

    // --- Load Charset A (world tileset, 2KB) ---
    BankInLo(current_tileset_bank)
    CopyFromCart($E000, 2048)
    BankOut()

    // --- Load sprite frames lower block (32 slots = 2KB) ---
    BankInLo(current_spr_bank_c)
    CopyFromCart($C800, 2048)
    BankOut()

    // --- Load sprite frames upper block (63 slots = 4032 bytes) ---
    BankInLo(current_spr_bank_w)
    CopyFromCart($F000, 4032)
    BankOut()

    // --- Load map data ---
    BankIn(current_map_bank)    // low=map, high=objects
    jsr LoadMapHeader           // reads $8000, builds row table
    jsr LoadTileDefinitions     // reads tile defs, builds flags cache
    jsr LoadLevelObjects        // reads $A000, populates $4000 level array
    BankOut()

    // --- Optionally clear dead_flags (new world) ---
    ldy #LevelDesc.flags
    lda (zp_ptr),y
    and #%00000001
    beq .keep_flags
    ldx #31
!:  sta dead_flags,x
    dex
    bpl !-
.keep_flags:

    // --- Reset active object table ---
    ldx #(MAX_ACTIVE - 1)
    lda #0
!:  sta act_flags,x
    dex
    bpl !-

    // --- Set player spawn position ---
    ldy #LevelDesc.start_x
    lda (zp_ptr),y
    sta act_x_hi            // player is always slot 0
    ldy #LevelDesc.start_y
    lda (zp_ptr),y
    sta act_y_hi

    // --- Initialise camera at player position ---
    jsr UpdateCamera

    // --- Start music ---
    ldy #LevelDesc.music_track
    lda (zp_ptr),y
    jsr MusicInit

    // --- Restore full IRQ chain ---
    jsr SetupIRQChain

    // --- Fade in ---
    jsr FadeIn

    rts
```

---

---

## 11. Timing Budget (PAL Frame)

### 11.1 Baseline Frame (Horizontal Scroll, 8 Active Objects)

```
Subsystem                              Cycles      % of frame
─────────────────────────────────────────────────────────────
Fine register update                       20         0.1%
Screen RAM shift (half, 500 bytes)       3500        17.8%
Edge fill (1 column or row)               400         2.0%
Colour RAM shift (half)                  1800         9.2%
IRQ overhead (4 IRQs x 30 cycles)         120         0.6%
Sprite sort (24 sprites)                  400         2.0%
Multiplex IRQ bodies (x3)                 600         3.1%
Object visibility cull (8 objects)        100         0.5%
Active object AI update (8)              1000         5.1%
World-to-screen conversion (8)            200         1.0%
Level data scan (16 entries/frame)        300         1.5%
Player input + physics                    300         1.5%
Camera update                             100         0.5%
Music player (SID)                        500         2.5%
Sprite-sprite collision (typical)         656         3.3%
Background collision (8 obj x 4 pts)      640         3.3%
Collision response processing             200         1.0%
─────────────────────────────────────────────────────────────
TOTAL baseline frame                     10836        55.1%
Remaining headroom                        8820        44.9%
```

### 11.2 Per-Scenario Breakdown

```
Scenario                                  Cycles      % frame    Headroom
──────────────────────────────────────────────────────────────────────────
Idle (fine scroll only, no coarse shift)   7336        37.3%      62.7%
Horizontal scroll (typical)               10836        55.1%      44.9%
Vertical scroll (typical)                 10836        55.1%      44.9%
Diagonal scroll phase 0                   14336        72.9%      27.1%
Diagonal scroll phase 1                   14336        72.9%      27.1%
Diagonal scroll phase 2 (H only)          10836        55.1%      44.9%
Horizontal + worst-case collision         11836        60.2%      39.8%
Diagonal + worst-case collision           15336        78.0%      22.0%
──────────────────────────────────────────────────────────────────────────
```

Diagonal scroll with worst-case collision (78%) is the tightest scenario.
~4,320 cycles of headroom remain for game-specific logic — enough for
simple game state updates, HUD rendering, and special effects, but tight.
This is the scenario that motivates the split-tick fallback (Section 13).

### 11.3 NTSC Considerations

NTSC frames are ~13% shorter (17,095 cycles vs 19,656). Key impacts:

- Colour RAM safe window shrinks: ~64 lines vs ~77 lines PAL
- Diagonal worst-case on NTSC: ~91% frame usage — over budget
- Horizontal typical on NTSC: ~64% — acceptable

NTSC detection at startup sets flag at $32. IRQ raster lines are adjusted
and colour RAM split timing tightened. Diagonal scroll speed may need to be
capped at 2px/frame on NTSC to stay within budget.

### 11.4 No Cartridge Bank Switches During Gameplay

All assets are loaded at level transition. No bank switches occur during
the game loop. Ring buffer refills (if map exceeds direct RAM) cost a
single ~9-cycle bank switch during a scroll slack window — negligible.

---

## 12. Split-Tick Architecture (Optional Fallback)

If game requirements push the cycle budget beyond comfortable limits —
more active objects, more complex AI, additional systems — a split-tick
architecture separates display update rate from logic update rate.

### 12.1 Concept

```
Display tick: every PAL frame (50fps) — VIC registers, sprite positions,
              scroll fine/coarse update, multiplex IRQ chain. Always runs.

Logic tick:   every 2nd PAL frame (25fps) — AI update, physics, collision
              detection, event processing, level scan. Runs on alternate frames.
```

The player sees smooth scrolling and smooth sprite movement at 50fps.
Enemies think and collide at 25fps. In practice this is nearly imperceptible
in action games — the visual smoothness dominates perception.

### 12.2 Implementation

```kickasm
// In zero page
.label logic_tick_flag = $31    // reuse frame counter — odd/even

MainLoop:
    // Always: wait for IRQ, update scroll, update sprite positions
    jsr WaitForFrame
    jsr UpdateScrollRegisters
    jsr UpdateSpriteScreenPositions
    jsr RunMultiplexer

    // Logic tick — alternate frames only
    lda logic_tick_flag
    and #%00000001
    bne .skip_logic         // odd frame — skip logic

    jsr UpdateAllAI
    jsr CheckAllCollisions
    jsr ProcessCollisionEvents
    jsr UpdatePhysics
    jsr ScanLevelObjects
    jsr UpdateCamera
    jsr ProcessEventQueue

.skip_logic:
    inc logic_tick_flag
    jmp MainLoop
```

### 12.3 Split-Tick Cycle Budget

```
Display tick (every frame, 50fps):        Cycles      % of frame
───────────────────────────────────────────────────────────────
Scroll + colour RAM + IRQs                 6040        30.7%
Sprite position updates (8 objects)         200         1.0%
Multiplex IRQ bodies                        600         3.1%
Music player                                500         2.5%
───────────────────────────────────────────────────────────────
Display tick total                         7340        37.3%
Remaining for game-specific display work  12316        62.7%

Logic tick (every 2nd frame, 25fps):     Cycles      % of frame
───────────────────────────────────────────────────────────────
AI update (8 objects)                      1000         5.1%
Collision detection (typical)               656         3.3%
Background collision                        640         3.3%
Collision response                          200         1.0%
Physics                                     400         2.0%
Level scan                                  300         1.5%
Camera update                               100         0.5%
Event queue                                 200         1.0%
───────────────────────────────────────────────────────────────
Logic tick additional cost                 3496        17.8%

Worst frame (diagonal + logic tick):      10836        55.1%
───────────────────────────────────────────────────────────────
```

Split-tick brings even the diagonal worst-case to 55% — comfortably
within budget. With split-tick, MAX_ACTIVE could be raised to 12 or
even 16 without exceeding the logic-tick frame budget, at the cost of
the 25fps logic rate perception trade-off.

---

## 13. Key Constants Summary

```kickasm
// --- Geometry ---
.const TILE_SIZE_CHARS     = 2      // chars per tile edge
.const BLOCK_SIZE_TILES    = 2      // tiles per block edge
.const BLOCK_SIZE_CHARS    = 4      // chars per block edge
.const BLOCK_SIZE_PIXELS   = 32     // pixels per block
.const MAX_MAP_WIDTH       = 256    // tiles
.const MAX_MAP_HEIGHT      = 256    // tiles

// --- Screen ---
.const SCREEN_COLS         = 40
.const SCREEN_ROWS         = 25
.const SCREEN_TILE_W       = 20
.const SCREEN_TILE_H       = 12
.const SCREEN_BLOCK_W      = 10
.const SCREEN_BLOCK_H      =  6

// --- Objects ---
.const MAX_ACTIVE          = 8    // default; see Section 13 for split-tick alternative
.const MAX_LEVEL_OBJS      = 255
.const MAX_SPRITES         = 24
.const SPR_FRAME_SLOTS     = 95
.const ACTIVATION_RADIUS_H = 12
.const ACTIVATION_RADIUS_V =  8
.const DEACTIVATION_RADIUS = 14
.const MAX_OBJECT_HEIGHT_BLOCKS = 2

// --- Collision ---
.const MAX_COLL_EVENTS     = 8
.const COLL_PAIRS          = MAX_ACTIVE * (MAX_ACTIVE - 1) / 2

.const CGROUP_PLAYER       = %00000001
.const CGROUP_ENEMY        = %00000010
.const CGROUP_PICKUP       = %00000100
.const CGROUP_PLAYER_PROJ  = %00001000
.const CGROUP_ENEMY_PROJ   = %00010000

// --- VIC ---
.const SCREEN_A_ADDR       = $C000
.const SCREEN_B_ADDR       = $C400
.const SPR_FRAMES_LO_ADDR  = $C800
.const CHARSET_A_ADDR      = $E000
.const CHARSET_B_ADDR      = $E800
.const SPR_FRAMES_HI_ADDR  = $F000
.const VIC_VECTORS_ADDR    = $FF00

// --- Cartridge ---
.const ENGINE_BANK         = 0
.const CHARSET_B_BANK      = 5      // high window — permanent HUD font
.const ENEMY_DEF_BANK      = 9
.const MUSIC_BANK          = 10
.const SFX_BANK            = 11
.const SPR_COMMON_BANK     = 12
.const SPR_WORLD_BANK_BASE = 13     // banks 13-16 for worlds 1-4

// --- Timing (PAL) ---
.const CYCLES_PER_FRAME    = 19656
.const CYCLES_PER_FRAME_NTSC = 17095
.const SCROLL_IRQ_LINE     = 250
.const MUX_IRQ_LINE_1      =  50
.const FLD_IRQ_LINE        =  44    // RESERVED Phase 3 — FLD parallax IRQ fires here
                                    // Must be above MUX_IRQ_LINE_1
                                    // IRQ chain is dynamically linked (see Section 8)
                                    // — inserting FLD IRQ requires changing only the
                                    //   FrameResetIRQ next-pointer, not the mux chain
.const MUX_IRQ_LINE_2      =  90
.const MUX_IRQ_LINE_3      = 130

// --- Budget validation ---
.const COLL_PAIRS_ACTUAL   = MAX_ACTIVE * (MAX_ACTIVE - 1) / 2
.print "Collision pairs to check: " + COLL_PAIRS_ACTUAL
.if (COLL_PAIRS_ACTUAL > 28) {
    .print "WARNING: >28 collision pairs. Consider split-tick architecture."
}
```

---

*End of specification. Version 4.0*

---

## 14. VIC-II Exploit Evaluation

Several advanced VIC-II techniques were evaluated for potential use in
this engine. Decisions are recorded here so future maintainers understand
what was considered and why each was accepted or rejected.

### 14.1 FLI (Flexible Line Interpretation)

**Decision: Rejected.**

FLI achieves per-character-row colour independence by rapidly cycling the
screen RAM pointer on every raster line. The CPU cost is nearly total
during the active display area — almost every cycle is consumed maintaining
the FLI illusion. Incompatible with a sprite multiplexer, scroll engine,
and AI system all sharing the same frame budget. Suitable for still images
and loading screens only. Not used in any phase of this engine.

### 14.2 VSP (Variable Screen Position / DMA Delay)

**Decision: Rejected — hardware safety risk.**

VSP manipulates $D011 at cycle-exact timing to shift screen RAM reading
by an arbitrary horizontal offset, effectively providing free hardware
horizontal scroll without CPU shifting cost. Highly appealing on paper.

However VSP is known to crash and potentially corrupt RAM on a minority
of real C64 hardware (particularly C64C models with later MOS silicon
revisions). A "Safe VSP" workaround exists but severely constrains
usable screen RAM addresses, making it impractical with a dynamic
scrolling tile engine. A cartridge product must run reliably on all
hardware. VSP is explicitly not used in any phase of this engine.

Any future maintainer should not introduce VSP without full understanding
of the crash mechanism and a tested safe implementation.

### 14.3 Linecrunch

**Decision: Rejected as scroll technique. Permitted for transitions.**

Linecrunch collapses character rows to single-pixel height by triggering
a bad line at the wrong time, pulling everything below it upward without
CPU memory moves. The unavoidable side effect is a black artifact band
at the top of the screen for every crunched row, and heavy constraints
on screen layout above the crunch point.

Not suitable as part of the main scroll engine. May be used in Phase 3
for screen wipe transitions or special effect sequences where the
artifact is acceptable or can be hidden.

### 14.4 FLD (Flexible Line Distance)

**Decision: Deferred to Phase 3. IRQ chain reserved.**

FLD suppresses bad lines by keeping YSCROLL mismatched with the current
raster line, effectively pushing the visible display down by N scan lines.
Cost is low — approximately N×10 cycles per frame, firing every ~6 lines
rather than every line. No CPU shifting, no screen RAM involvement.

Primary use case: parallax background layer. A sky/distant terrain layer
in Charset B (upper screen rows) scrolling at a fraction of the foreground
rate, with FLD providing per-frame vertical offset control.

**What is reserved now for Phase 3 compatibility:**
- Zero page $40-$43: FLD state variables (do not use for other purposes)
- Raster line $44 (FLD_IRQ_LINE): reserved slot in IRQ chain before MUX_LINE_1
- Charset B slots 64-255: background parallax tiles (0-63 = HUD font)
- IRQ chain is dynamically linked — inserting FLD IRQ requires one
  pointer change in FrameResetIRQ, no other modifications

### 14.5 Border Opening

**Decision: Deferred to Phase 3. No reservation needed.**

Opening the top and bottom borders via $D011/$D016 timing extends the
visible display area. Bottom border opening adds ~3-4 extra character
rows of game world. Top border opening provides a HUD zone above the
play area without consuming play rows. Both are stable techniques with
no hardware compatibility risk.

No reservation needed now — border opening is additive and does not
conflict with any current engine design. It will be implemented in
Phase 3 as a display enhancement.

### 14.6 Raster Charset Split

**Decision: Planned for Phase 3. Partially reserved (Charset B).**

Switching $D018 mid-frame to select a different charset for different
screen regions is a standard, stable VIC-II technique. Used in Phase 3
to give the FLD parallax layer its own charset (Charset B upper slots)
while the HUD uses Charset B lower slots and the play area uses Charset A.

---

## 15. Project Structure and Folder Layout

The engine is built as a set of independently testable modules, each
in its own source file and folder. Kick Assembler's `.import` directive
includes modules into a master build file. This structure enforces
separation of concerns and allows each phase to be proved before the
next begins.

### 15.1 Folder Structure

```
project/
│
├── build/                      Output folder — .prg files, never committed
│
├── src/
│   ├── main.asm                Master build file — imports all modules
│   │                           Sets origin, imports in dependency order
│   │
│   ├── engine/
│   │   ├── constants.asm       All .const definitions — shared across modules
│   │   ├── zeropage.asm        Zero page .label aliases — single source of truth
│   │   ├── macros.asm          Shared macros (BankIn, BankOut, CopyFromCart etc.)
│   │   │
│   │   ├── irq/
│   │   │   ├── irq_init.asm    IRQ chain initialisation, CIA disable, vectors
│   │   │   ├── stable_raster.asm  Stable raster first/second stage handlers
│   │   │   ├── mux_irq.asm     Display list executor (MuxIRQ — jmp via ZP ptr)
│   │   │   └── frame_irq.asm   FrameResetIRQ — buffer flip, dirty reset, sync
│   │   │
│   │   ├── scroll/
│   │   │   ├── scroll.asm      Fine register update, coarse shift dispatch
│   │   │   ├── shift_left.asm  Screen RAM shift routines (left/right/up/down)
│   │   │   ├── shift_right.asm
│   │   │   ├── shift_up.asm
│   │   │   ├── shift_down.asm
│   │   │   ├── edge_fill.asm   Fill exposed column/row from ring buffer
│   │   │   └── colour_ram.asm  Colour RAM split update
│   │   │
│   │   ├── mux/
│   │   │   ├── mux_builder.asm Display list builder (BuildDisplayListA/B)
│   │   │   ├── mux_sort.asm    Inverted Y-sort (InsertSpriteY, RemoveSpriteY,
│   │   │   │                   BuildSortedList, ResetDirtyEntries)
│   │   │   └── mux_data.asm    Display list buffer skeletons, sprite tables
│   │   │
│   │   ├── map/
│   │   │   ├── map.asm         Map descriptor, row table builder, ring buffer
│   │   │   ├── ring_buffer.asm Ring buffer lookup, refill scheduling
│   │   │   └── tile_defs.asm   Tile definition table, flag cache
│   │   │
│   │   ├── coords/
│   │   │   ├── camera.asm      Camera update, clamp to map bounds
│   │   │   ├── world_to_screen.asm  WorldToScreenX/Y, visibility cull
│   │   │   └── bg_collision.asm    Background (tile) collision checks
│   │   │
│   │   ├── objects/
│   │   │   ├── object_table.asm    Active table, parallel arrays
│   │   │   ├── activation.asm      ScanLevelObjects, Activate, Deactivate
│   │   │   ├── ai_dispatch.asm     UpdateActiveObjects, type jump table
│   │   │   ├── physics.asm         Gravity, velocity, ground check
│   │   │   └── persistence.asm     Dead flags bitfield, HP writeback,
│   │   │                           sparse change log, global flags
│   │   │
│   │   ├── collision/
│   │   │   ├── collision.asm       CheckAllCollisions (unrolled outer loop)
│   │   │   ├── coll_geometry.asm   AABBCheck, SymmetricTableCheck, SpanMaskCheck
│   │   │   ├── coll_data.asm       CollMaskData, EmptyTop, Height, MinXSkip
│   │   │   └── coll_events.asm     LogCollision, ProcessCollisionEvents
│   │   │
│   │   └── cart/
│   │       ├── bank_manager.asm    BankIn/Out routines, safety wrappers
│   │       └── level_load.asm      LevelLoad, asset copy routines, LevelTable
│   │
│   ├── game/                   Game-specific code (not part of engine)
│   │   ├── player.asm          Player input, movement, state machine
│   │   ├── enemies/
│   │   │   ├── guard.asm       Guard AI states
│   │   │   ├── flyer.asm       Flyer AI states
│   │   │   └── boss.asm        Boss AI states
│   │   ├── hud.asm             Status bar, score, lives display
│   │   └── game_init.asm       Game-specific initialisation
│   │
│   ├── data/                   Asset data — binary exports from CharPad/SpritePad
│   │   │                       All .bin files imported via .import binary
│   │   │                       See Section 17 for full naming convention
│   │   │
│   │   ├── gfx/                Graphics assets (CharPad Pro exports)
│   │   │   ├── charset/
│   │   │   │   ├── charset_w1.bin      World 1 charset (2KB, 256 chars × 8 bytes)
│   │   │   │   ├── charset_w2.bin      World 2 charset
│   │   │   │   ├── charset_w3.bin      World 3 charset
│   │   │   │   ├── charset_w4.bin      World 4 charset
│   │   │   │   └── charset_hud.bin     HUD/UI charset — Charset B (2KB, permanent)
│   │   │   │
│   │   │   ├── tiles/
│   │   │   │   ├── tiles_w1.bin        World 1 tile set (char indices, 2×2 tiles)
│   │   │   │   ├── tiles_w2.bin        World 2 tile set
│   │   │   │   ├── tiles_w3.bin        World 3 tile set
│   │   │   │   └── tiles_w4.bin        World 4 tile set
│   │   │   │
│   │   │   ├── tileflags/
│   │   │   │   ├── tileflags_w1.bin    World 1 tile material/flags (1 byte/tile)
│   │   │   │   ├── tileflags_w2.bin    World 2 tile flags
│   │   │   │   ├── tileflags_w3.bin    World 3 tile flags
│   │   │   │   └── tileflags_w4.bin    World 4 tile flags
│   │   │   │
│   │   │   └── tilecolours/
│   │   │       ├── tilecolours_w1.bin  World 1 per-tile colour RAM values
│   │   │       ├── tilecolours_w2.bin  World 2 tile colours
│   │   │       ├── tilecolours_w3.bin  World 3 tile colours
│   │   │       └── tilecolours_w4.bin  World 4 tile colours
│   │   │
│   │   ├── sprites/            Sprite assets (SpritePad Pro exports)
│   │   │   ├── spr_player.bin          Player sprite frames (63 bytes × N frames)
│   │   │   ├── spr_enemy_guard.bin     Guard enemy frames
│   │   │   ├── spr_enemy_flyer.bin     Flyer enemy frames
│   │   │   ├── spr_enemy_heavy.bin     Heavy enemy frames
│   │   │   ├── spr_boss_w1.bin         World 1 boss frames
│   │   │   ├── spr_boss_w2.bin         World 2 boss frames
│   │   │   ├── spr_boss_w3.bin         World 3 boss frames
│   │   │   ├── spr_boss_w4.bin         World 4 boss frames
│   │   │   ├── spr_projectiles.bin     Bullet / projectile frames
│   │   │   ├── spr_fx.bin              Explosion / effect frames
│   │   │   ├── spr_collectables.bin    Pickup / collectable frames
│   │   │   └── spr_hud.bin             HUD icon sprites
│   │   │
│   │   ├── levels/             Map and object data (CharPad Pro map exports)
│   │   │   ├── map_w1_l1.bin           World 1 Level 1 map (tile indices, raw)
│   │   │   ├── map_w1_l2.bin           World 1 Level 2 map
│   │   │   ├── map_w2_l1.bin           World 2 Level 1 map
│   │   │   ├── map_w2_l2.bin           World 2 Level 2 map
│   │   │   ├── map_w3_l1.bin           World 3 Level 1 map
│   │   │   ├── map_w4_l1.bin           World 4 Level 1 map
│   │   │   ├── objs_w1_l1.asm          World 1 Level 1 object placement (KickASM)
│   │   │   ├── objs_w1_l2.asm          World 1 Level 2 object placement
│   │   │   └── ...                     (one objs_ file per level)
│   │   │
│   │   └── music/
│   │       ├── music_tracks.bin        All SID music tracks (loaded to $1000)
│   │       └── sfx_data.bin            Sound effect data
│   │
│   └── tests/                  Standalone test programs (one per phase)
│       ├── phase1_scroll_test.asm
│       ├── phase2_mux_test.asm
│       ├── phase3_map_test.asm
│       ├── phase4_objects_test.asm
│       └── phase5_collision_test.asm
│
├── build.sh                    Build script — calls KickAss, outputs to build/
├── test.sh                     Build and launch specific test in VICE
└── README.md                   Project overview, build instructions
```

### 15.2 Master Build File (main.asm)

```kickasm
// main.asm — top-level build entry point
// Import order reflects dependency: constants first, then low-level
// modules, then higher-level systems that depend on them.

// --- Foundation ---
.import source "engine/constants.asm"
.import source "engine/zeropage.asm"
.import source "engine/macros.asm"

// --- IRQ system (must be first executable code) ---
* = $0400
.import source "engine/irq/irq_init.asm"
.import source "engine/irq/stable_raster.asm"
.import source "engine/irq/mux_irq.asm"
.import source "engine/irq/frame_irq.asm"

// --- Scroll engine ---
.import source "engine/scroll/scroll.asm"
.import source "engine/scroll/shift_left.asm"
.import source "engine/scroll/shift_right.asm"
.import source "engine/scroll/shift_up.asm"
.import source "engine/scroll/shift_down.asm"
.import source "engine/scroll/edge_fill.asm"
.import source "engine/scroll/colour_ram.asm"

// --- Multiplexer ---
.import source "engine/mux/mux_data.asm"
.import source "engine/mux/mux_sort.asm"
.import source "engine/mux/mux_builder.asm"

// --- Map system ---
.import source "engine/map/tile_defs.asm"
.import source "engine/map/map.asm"
.import source "engine/map/ring_buffer.asm"

// --- Coordinate system ---
.import source "engine/coords/camera.asm"
.import source "engine/coords/world_to_screen.asm"
.import source "engine/coords/bg_collision.asm"

// --- Object system ---
.import source "engine/objects/object_table.asm"
.import source "engine/objects/activation.asm"
.import source "engine/objects/physics.asm"
.import source "engine/objects/persistence.asm"
.import source "engine/objects/ai_dispatch.asm"

// --- Collision ---
.import source "engine/collision/coll_data.asm"
.import source "engine/collision/coll_geometry.asm"
.import source "engine/collision/coll_events.asm"
.import source "engine/collision/collision.asm"

// --- Cartridge ---
.import source "engine/cart/bank_manager.asm"
.import source "engine/cart/level_load.asm"

// --- Game-specific ---
.import source "game/game_init.asm"
.import source "game/player.asm"
.import source "game/hud.asm"
.import source "game/enemies/guard.asm"
.import source "game/enemies/flyer.asm"
.import source "game/enemies/boss.asm"
```

### 15.3 Build Script (build.sh)

```bash
#!/bin/bash
# build.sh — build full engine or a named test file
# Usage: ./build.sh            (builds main.prg)
#        ./build.sh phase1     (builds tests/phase1_scroll_test.prg)

TARGET=${1:-main}

if [ "$TARGET" = "main" ]; then
    SRC="src/main.asm"
    OUT="build/engine.prg"
else
    SRC="src/tests/${TARGET}_test.asm"
    OUT="build/${TARGET}_test.prg"
fi

java -jar tools/KickAss.jar "$SRC" -o "$OUT" -showmem
if [ $? -eq 0 ]; then
    echo "Build OK: $OUT"
else
    echo "Build FAILED"
    exit 1
fi
```

### 15.4 Test Launch Script (test.sh)

```bash
#!/bin/bash
# test.sh — build and launch a phase test in VICE
# Usage: ./test.sh phase1

TARGET=${1:-phase1}
./build.sh "$TARGET" && x64sc "build/${TARGET}_test.prg"
```

Each test file is fully self-contained — it imports only the engine
modules it needs, sets up its own test data and demo movement, and
can be built and run independently of the full engine. This is the
primary verification mechanism for each phase.

---

## 16. Build Phases

Each phase has a clear goal, a defined set of source files, a
standalone test program, and explicit pass/fail criteria. No phase
begins until the previous phase's criteria are fully met on both
VICE (cycle-exact emulation) and real hardware.

**Real hardware testing is mandatory before phase sign-off.**
Emulators do not catch all timing edge cases, particularly around
raster IRQ jitter, colour RAM update windows, and NTSC compatibility.

---

### Phase 1 — IRQ Foundation and Stable Raster

**Goal:** Establish the IRQ chain infrastructure. Prove stable raster
timing. Prove the display list execution mechanism works correctly
with a minimal fixed display.

**Files introduced:**
```
engine/constants.asm
engine/zeropage.asm
engine/macros.asm
engine/irq/irq_init.asm
engine/irq/stable_raster.asm
engine/irq/mux_irq.asm
engine/irq/frame_irq.asm
engine/mux/mux_data.asm         (pre-baked buffer skeletons)
tests/phase1_irq_test.asm
```

**Test program:** Display 8 static sprites at fixed screen positions
using the display list mechanism. No movement. No sort. Hardcode
display list data for one IRQ group. Measure IRQ firing cycle
accuracy using VICE monitor.

**Pass criteria:**
- [ ] 8 sprites visible at correct positions, no flicker
- [ ] Stable raster confirmed — sprites do not drift vertically
  across frames (test 60 seconds in VICE)
- [ ] Display list buffer A/B alternating correctly (VICE monitor)
- [ ] IRQ overhead ≤ 250 cycles per firing (measure in VICE)
- [ ] Runs correctly on real hardware (PAL C64)
- [ ] No crash after 10 minutes real hardware run

---

### Phase 2 — Sprite Multiplexer (24 Logical Sprites)

**Goal:** Prove the inverted Y-sort and full 24-logical-sprite
multiplexer. This is the mux_test_spec.md deliverable.

**Files introduced:**
```
engine/mux/mux_sort.asm         (InsertSpriteY, RemoveSpriteY,
                                 BuildSortedList, ResetDirtyEntries)
engine/mux/mux_builder.asm      (BuildDisplayListA, BuildDisplayListB)
tests/phase2_mux_test.asm       (24 sprites, 3 movement modes)
```

**Test program:** As defined in mux_test_spec.md — 24 logical sprites
with sine wave, bounce, and diagonal drift movement. Colour-coded
for visual verification. Cycle counter overlay.

**Pass criteria:**
- [ ] All 24 logical sprites visible and moving
- [ ] No sprite flicker on raster boundaries
- [ ] Two sprites at same Y position both render (chain test)
- [ ] Sorted order correct every frame (VICE memory monitor)
- [ ] y_to_slot empty after ResetDirtyEntries (verified each frame)
- [ ] Total multiplexer cost ≤ 1,200 cycles/frame (VICE monitor)
- [ ] Runs 10 minutes on real hardware without crash or glitch

---

### Phase 3 — Scroll Engine (Fine + Coarse, 4-Way)

**Goal:** Prove smooth 4-way scrolling at up to 4px/frame in all
directions including diagonal. Prove double-buffer swap, colour RAM
split, and edge fill from a static test map.

**Files introduced:**
```
engine/scroll/scroll.asm
engine/scroll/shift_left.asm
engine/scroll/shift_right.asm
engine/scroll/shift_up.asm
engine/scroll/shift_down.asm
engine/scroll/edge_fill.asm
engine/scroll/colour_ram.asm
engine/coords/camera.asm
tests/phase3_scroll_test.asm
```

**Test program:** A static test map (checkerboard or numbered tile
pattern) filling 128×64 tiles. Player-controlled scroll direction
via joystick. Sprites from Phase 2 multiplexer running simultaneously
(prove scroll + mux coexist). Display scroll mode and fine register
values as overlay.

**Pass criteria:**
- [ ] Smooth scroll all 4 directions at 1, 2, 3, 4 px/frame
- [ ] Diagonal scroll completes cleanly (3-frame shift)
- [ ] No screen tearing on buffer swap
- [ ] No colour corruption during colour RAM split update
- [ ] Edge fill correct — no garbage column/row on coarse step
- [ ] Phase 2 sprites unaffected by scroll engine activity
- [ ] Frame budget ≤ 75% on diagonal scroll (VICE cycle counter)
- [ ] NTSC: scroll runs without crash (may be limited to 2px/frame)
- [ ] Real hardware: 10 minutes, all scroll modes, no glitch

---

### Phase 4 — Map System and World Coordinates

**Goal:** Prove the tile map, ring buffer, row address table, and
world coordinate system. Prove world-to-screen conversion and
visibility culling. Prove background (tile) collision.

**Files introduced:**
```
engine/map/tile_defs.asm
engine/map/map.asm
engine/map/ring_buffer.asm
engine/coords/world_to_screen.asm
engine/coords/bg_collision.asm
tests/phase4_map_test.asm
```

**Test program:** Load a real 128×64 tile map from a hardcoded data
block (no cartridge yet). Scroll the map with joystick. Display a
single player sprite that collides correctly with solid tiles (cannot
walk through walls). Display world coordinates and current tile
under player as overlay. Ring buffer refill visible in VICE memory
monitor as player approaches edges.

**Pass criteria:**
- [ ] Map scrolls correctly — tiles appear in correct world positions
- [ ] Ring buffer refills without visual glitch as camera moves
- [ ] Row address table produces correct map lookups (spot-check
      20 random positions against expected tile data)
- [ ] Player sprite blocked by solid tiles on all 4 sides
- [ ] Player sprite passes through non-solid tiles correctly
- [ ] World-to-screen conversion places sprite correctly vs background
  (no misalignment during scroll)
- [ ] Fine scroll compensation correct — sprite doesn't slide
      against background during sub-character movement
- [ ] Real hardware: full map traversal without glitch

---

### Phase 5 — Object System and AI

**Goal:** Prove the active object table, level data array, activation/
deactivation radius, HP writeback, persistent state, and AI dispatch.
No cartridge yet — level data hardcoded.

**Files introduced:**
```
engine/objects/object_table.asm
engine/objects/activation.asm
engine/objects/physics.asm
engine/objects/persistence.asm
engine/objects/ai_dispatch.asm
game/enemies/guard.asm          (simple patrol AI as test case)
tests/phase5_objects_test.asm
```

**Test program:** A 128×64 tile map with 32 hardcoded objects — mix
of patrolling guards, static pickups, and a trigger door. Player
can move and interact. Guards activate as player approaches, deactivate
when distant. Pickups persist as collected (dead_flags bitfield).
Door opens when switch is hit (sparse change log). HP writeback
verified by damaging a guard, leaving area, returning — guard has
reduced HP.

**Pass criteria:**
- [ ] Objects activate within ACTIVATION_RADIUS of player
- [ ] Objects deactivate outside DEACTIVATION_RADIUS
- [ ] MAX_ACTIVE (8) never exceeded — log if activation rejected
- [ ] HP writeback correct — guard retains damage after deactivation
- [ ] Dead pickups stay dead after player leaves and returns
- [ ] Door state persists correctly via sparse change log
- [ ] AI patrol state machine runs correctly (guard walks, turns,
      chases player on proximity)
- [ ] Physics: player and enemies obey gravity, land on tiles
- [ ] Real hardware: extended play session, no corruption of object
      state tables

---

### Phase 6 — Collision Detection

**Goal:** Prove the five-stage collision cascade. Prove group mask
filtering, span mask geometry, symmetric table check, and event queue.

**Files introduced:**
```
engine/collision/coll_data.asm
engine/collision/coll_geometry.asm
engine/collision/coll_events.asm
engine/collision/collision.asm
tests/phase6_collision_test.asm
```

**Test program:** Extend Phase 5 test. Player fires projectiles
(player_proj group). Guards are damageable (respond to player_proj).
Pickups collected on player contact. Guards do not damage each other.
Collision event queue displayed as overlay (event count per frame).
VICE monitor used to verify span mask check fires only when geometry
warrants it.

**Pass criteria:**
- [ ] Player projectile hits guard → guard loses HP → dies at 0
- [ ] Player touches pickup → collected, dead_flags set
- [ ] Guard does not register collision with other guard
  (group mask filtering confirmed)
- [ ] No false positives — projectile passing edge of guard sprite
      does NOT register as hit (span mask accuracy)
- [ ] Collision event queue never overflows (8 slots sufficient)
- [ ] Stage 1-4 rejections confirmed: VICE breakpoint on SpanMaskCheck
      fires rarely (< 5% of pairs reaching it)
- [ ] Total collision cost ≤ 2,500 cycles (VICE cycle counter)
- [ ] Real hardware: no phantom hits observed in 10 minute session

---

### Phase 7 — Cartridge Integration

**Goal:** Move all level data, assets, and engine code to EasyFlash
cartridge. Prove between-levels load sequence. Prove asset streaming
(charset swap, sprite frame reload). Prove ring buffer refill from
cartridge for maps larger than RAM.

**Files introduced:**
```
engine/cart/bank_manager.asm
engine/cart/level_load.asm
data/levels/level1_map.asm      (now targeting cartridge bank layout)
data/levels/level1_objs.asm
data/sprites/player_frames.asm
src/main.asm                    (full build, first time)
```

**Test program:** Full engine running from cartridge. Two levels with
distinct tilesets and object sets. Level transition on reaching exit
trigger — fade, load, fade in. Confirm charset A swaps correctly.
Confirm sprite frames reload. Confirm map refills from cartridge.

**Pass criteria:**
- [ ] Level 1 loads and plays correctly from cartridge
- [ ] Level transition completes — level 2 loads with correct assets
- [ ] Charset A visually distinct between levels (confirmed different
      tileset loaded)
- [ ] Sprite frames reload — enemy sprites correct for each world
- [ ] Ring buffer refills from cartridge without glitch for large maps
- [ ] No bank switch occurs during gameplay (VICE monitor: $DE00
      write breakpoint should never fire during play, only on load)
- [ ] Real hardware: both levels playable on real EasyFlash cartridge

---

### Phase 8 — Integration and Polish

**Goal:** Full game integration. All systems running together.
Performance profiling on real hardware. NTSC compatibility pass.
Split-tick fallback validated if needed.

**Activities:**
- Profile frame budget across all scroll modes and enemy counts
- Validate NTSC timings (reduce diagonal speed cap if needed)
- Add remaining enemy AI types (flyer, boss)
- Implement HUD (score, lives, power-ups)
- Add SID music and SFX (music player at $1000)
- Consider border opening for extra display rows (Phase 8 optional)
- Implement split-tick if any phase 7 profiling shows budget overrun

**Pass criteria:**
- [ ] Full game loop playable — start to end of all levels
- [ ] 50fps maintained across all gameplay scenarios (VICE profiler)
- [ ] NTSC: playable at reduced scroll speed, no crash
- [ ] SID music plays without interruption during gameplay
- [ ] All object state persists correctly across full play session
- [ ] Real hardware: complete play-through on PAL C64 and C64C
- [ ] Real hardware: NTSC C64 boots and is playable

---

### Phase 9 (Optional) — FLD Parallax Background

**Goal:** Add FLD-based parallax background layer using the reserved
IRQ slot and Charset B background tiles.

**Precondition:** Phase 8 signed off. Full game stable on real hardware.

**Activities:**
- Implement FLD IRQ at raster line 44 (FLD_IRQ_LINE constant)
- Use ZP $40-$43 for FLD state
- Design background tiles in Charset B slots 64-255
- Implement FLD offset calculation from camera_y at fractional rate
- Verify cycle budget unaffected (FLD cost ~100 cycles)
- Add raster split to switch Charset B for HUD rows vs parallax rows

**Pass criteria:**
- [ ] Background layer visible and scrolling at different rate
      from foreground
- [ ] No interference with multiplexer or scroll engine
- [ ] Frame budget unchanged from Phase 8
- [ ] Real hardware: parallax effect visible, no glitch

---

### Phase Summary

```
Phase   Subsystem               Test Focus              Key Risk
───────────────────────────────────────────────────────────────────────
  1     IRQ + stable raster     Timing accuracy         Raster jitter
  2     Sprite multiplexer      24 sprites, Y-sort      IRQ chain timing
  3     Scroll engine           4-way smooth scroll     Colour RAM window
  4     Map + coordinates       Ring buffer, collision  Fine scroll align
  5     Object system           AI, persistence         State corruption
  6     Collision detection     Accuracy, cycle cost    False positives
  7     Cartridge integration   Asset loading, banking  Bank switch safety
  8     Integration + polish    Full game, NTSC, SID    Budget overrun
  9*    FLD parallax            Background layer        IRQ chain insert
───────────────────────────────────────────────────────────────────────
* Optional
```

Each phase test program remains in `src/tests/` and continues to build
cleanly throughout the project. Regression testing later phases means
running all earlier test programs and verifying they still pass —
a quick check that integration hasn't broken any subsystem.


---

## 17. Asset Pipeline — CharPad Pro and SpritePad Pro

All graphical assets are produced in **CharPad Pro** (tiles, charsets, maps)
and **SpritePad Pro** (sprites, animations), both by Subchrist Software.
Both tools export raw binary files that KickAssembler imports directly
with `.import binary` — no intermediate conversion or custom parser needed.

---

### 17.1 Graphics Mode Decisions

**Tiles: Multicolour character mode (2×2 chars per tile)**

- Tile size in CharPad: **2×2 characters** (16×16 pixels effective, 8×16 MC pixels)
- VIC mode: Multicolour text mode ($D016 bit 4 set)
- Colour mode in CharPad: **Per Tile** — one colour RAM value per tile,
  same colour applied to all 4 characters in the tile
- Three shared colours ($D021, $D022, $D023) define the world palette
- Colour RAM value per tile maps to the %11 pixel code (foreground)

**Sprites: Multicolour**

- All sprites in SpritePad: **Multicolour** mode
- Two shared sprite colours ($D025, $D026) plus one individual colour
  per sprite ($D027+N)
- MC sprites are 12 effective pixels wide × 21 pixels tall
- $D01C set to $FF (all 8 hardware sprites in MC mode)

---

### 17.2 CharPad Pro Project Settings

When creating or importing a CharPad project for this engine:

```
Mode:           Multicolour text
Tile size:      2 × 2 characters
Colour mode:    Per Tile
Map export:     8-bit (one byte per tile index)
```

The three shared colours ($D021-$D023) are defined per world in the
LevelDesc table (Section 10.1), not exported from CharPad. Set them
visually in CharPad's colour palette for accurate preview, but the
runtime values come from LevelDesc.

Material codes (tile flags) are assigned in CharPad's tile editor
using the material/attribute field. Assign values matching the engine
constants before exporting:

```
Material 1  ($01) = TILE_FLAG_SOLID   — walls, impassable blocks
Material 2  ($02) = TILE_FLAG_HAZARD  — spikes, lava, damage areas
Material 4  ($04) = TILE_FLAG_ANIM    — animated tiles (water, flames)
Material 8  ($08) = TILE_FLAG_SPECIAL — doors, triggers, special exits
Material 0  ($00) = passable (default — floor, background, sky)
```

Enable **Sort by Material** in CharPad's compression options to group
solid tiles first in the charset — this allows a range check for
collision (tile index < SOLID_TILE_MAX) rather than a table lookup.

---

### 17.3 CharPad Pro Export Procedure

For each world, open the CharPad project and export the following
via **File → Export Binary** (select RAW format, no load address):

| Export item | CharPad menu option | Output filename |
|-------------|-------------------|-----------------|
| Charset | Export Binary → Charset | `charset_wN.bin` |
| Tile set | Export Binary → Tile Set (8-bit) | `tiles_wN.bin` |
| Tile attributes | Export Binary → Tile Attribs | `tileflags_wN.bin` |
| Tile colours | Export Binary → Tile Colours | `tilecolours_wN.bin` |
| Map data | Export Binary → Map (8-bit) | `map_wN_lM.bin` |

Where N = world number (1-4) and M = level number within world.

**Record map dimensions separately** — they are not embedded in the
binary export. Add them as constants in the object placement `.asm`
file for each level:

```kickasm
// objs_w1_l1.asm — object placement + map metadata for World 1 Level 1
.const W1L1_MAP_WIDTH   = 128   // tiles across (from CharPad project)
.const W1L1_MAP_HEIGHT  = 64    // tiles down
.const W1L1_TILE_COUNT  = 96    // distinct tiles (from CharPad status bar)
```

---

### 17.4 SpritePad Pro Project Settings

```
Mode:       Multicolour
Overlay:    As required per sprite type (player may use overlay for detail)
Animation:  Define sequences per enemy type
Export:     Binary — Sprite Set (raw, 63 bytes per frame)
```

Organise sprites in SpritePad with one project per logical group
(player, common enemies, world-specific enemies). Each export
produces one binary file with frames packed sequentially.

Record the frame count and animation sequences for each sprite type.
These feed into the SpriteIndex table (Section 3.4) and EnemyTypeDef
(Section 9):

```kickasm
// In enemy type definitions — update these to match SpritePad exports
// spr_player.bin:   12 frames (indices 0-11)
//   0-3:  walk right (4 frames)
//   4-7:  walk left  (4 frames)
//   8-9:  jump/fall  (2 frames)
//   10:   hurt        (1 frame)
//   11:   idle        (1 frame)
```

---

### 17.5 File Naming Convention

All binary asset files follow this naming pattern:

```
{type}_{scope}.bin

type:
  charset      — character set graphics (256 chars × 8 bytes = 2048 bytes)
  tiles        — tile character index data (CharPad tile set export)
  tileflags    — tile material/flag bytes (CharPad tile attribs export)
  tilecolours  — tile colour RAM values (CharPad tile colours export)
  map          — map tile indices, row-major (CharPad map export)
  spr          — sprite frame data (SpritePad export, 63 bytes/frame)
  music        — SID music data
  sfx          — sound effect data

scope:
  wN           — world N (1-4)
  wN_lM        — world N, level M
  player       — player character (not world-specific)
  enemy_{name} — specific enemy type (guard, flyer, heavy, shooter)
  boss_wN      — boss for world N
  projectiles  — all projectile types
  fx           — explosion/effect sprites
  collectables — pickup/item sprites
  hud          — HUD icon sprites
  hud          — HUD charset (for charset_ prefix)
```

Full file list:

```
data/gfx/charset/
  charset_w1.bin          2048 bytes   World 1 tileset charset
  charset_w2.bin          2048 bytes   World 2 tileset charset
  charset_w3.bin          2048 bytes   World 3 tileset charset
  charset_w4.bin          2048 bytes   World 4 tileset charset
  charset_hud.bin         2048 bytes   HUD/UI font — Charset B

data/gfx/tiles/
  tiles_w1.bin            ~384 bytes   World 1 tiles (96 tiles × 4 chars)
  tiles_w2.bin            ~384 bytes
  tiles_w3.bin            ~384 bytes
  tiles_w4.bin            ~384 bytes

data/gfx/tileflags/
  tileflags_w1.bin        256 bytes    World 1 tile material flags
  tileflags_w2.bin        256 bytes
  tileflags_w3.bin        256 bytes
  tileflags_w4.bin        256 bytes

data/gfx/tilecolours/
  tilecolours_w1.bin      256 bytes    World 1 per-tile colour RAM values
  tilecolours_w2.bin      256 bytes
  tilecolours_w3.bin      256 bytes
  tilecolours_w4.bin      256 bytes

data/sprites/
  spr_player.bin          756 bytes    12 frames × 63 bytes
  spr_enemy_guard.bin     252 bytes    4 frames × 63 bytes
  spr_enemy_flyer.bin     252 bytes    4 frames × 63 bytes
  spr_enemy_heavy.bin     378 bytes    6 frames × 63 bytes
  spr_enemy_shooter.bin   252 bytes    4 frames × 63 bytes
  spr_boss_w1.bin         504 bytes    8 frames × 63 bytes
  spr_boss_w2.bin         504 bytes
  spr_boss_w3.bin         504 bytes
  spr_boss_w4.bin         504 bytes
  spr_projectiles.bin     252 bytes    4 frames × 63 bytes
  spr_fx.bin              504 bytes    8 frames × 63 bytes
  spr_collectables.bin    378 bytes    6 frames × 63 bytes
  spr_hud.bin             252 bytes    4 frames × 63 bytes

data/levels/
  map_w1_l1.bin           variable     128×64 = 8192 bytes typical
  map_w1_l2.bin           variable
  map_w2_l1.bin           variable
  map_w2_l2.bin           variable
  map_w3_l1.bin           variable
  map_w4_l1.bin           variable
  objs_w1_l1.asm          KickASM      Object placement + map dimension constants
  objs_w1_l2.asm          KickASM
  ... (one objs_ per level)

data/music/
  music_tracks.bin        variable     All SID tracks packed sequentially
  sfx_data.bin            variable     Sound effect data
```

---

### 17.6 KickAssembler Import Stubs

Each asset category has a corresponding import wrapper. These live in
`src/data/` and are imported by the main build or the relevant
cartridge bank assembly file.

**Charset imports (src/data/gfx/charsets.asm):**

```kickasm
// charsets.asm — charset binary imports
// Placed at cartridge bank positions by cart/bank_layout.asm
// During testing (Phase 3/4), may be loaded directly into $E000

// World charsets — Charset A (2KB each, loaded per world at level transition)
Charset_W1: .import binary "data/gfx/charset/charset_w1.bin"
Charset_W2: .import binary "data/gfx/charset/charset_w2.bin"
Charset_W3: .import binary "data/gfx/charset/charset_w3.bin"
Charset_W4: .import binary "data/gfx/charset/charset_w4.bin"

// HUD charset — Charset B (permanent, loaded at startup)
Charset_HUD: .import binary "data/gfx/charset/charset_hud.bin"

// Assemble-time validation
.if (* - Charset_W1 != 2048) { .error "charset_w1.bin wrong size" }
.if (* - Charset_HUD != 2048) { .error "charset_hud.bin wrong size" }
```

**Tile data imports (src/data/gfx/tiledata.asm):**

```kickasm
// tiledata.asm — tile set, flags, and colour imports

// Tile set data (character indices, 4 per tile for 2×2 tiles)
// Loaded into TileDefTable at level start
TileSet_W1: .import binary "data/gfx/tiles/tiles_w1.bin"
TileSet_W2: .import binary "data/gfx/tiles/tiles_w2.bin"
TileSet_W3: .import binary "data/gfx/tiles/tiles_w3.bin"
TileSet_W4: .import binary "data/gfx/tiles/tiles_w4.bin"

// Tile flags — material codes, 1 byte per tile (256 max)
// Loaded into TileFlagsCache at level start
TileFlags_W1: .import binary "data/gfx/tileflags/tileflags_w1.bin"
TileFlags_W2: .import binary "data/gfx/tileflags/tileflags_w2.bin"
TileFlags_W3: .import binary "data/gfx/tileflags/tileflags_w3.bin"
TileFlags_W4: .import binary "data/gfx/tileflags/tileflags_w4.bin"

// Tile colour RAM values — 1 byte per tile (Per Tile colour mode)
// Loaded into TileColourCache at level start
TileColours_W1: .import binary "data/gfx/tilecolours/tilecolours_w1.bin"
TileColours_W2: .import binary "data/gfx/tilecolours/tilecolours_w2.bin"
TileColours_W3: .import binary "data/gfx/tilecolours/tilecolours_w3.bin"
TileColours_W4: .import binary "data/gfx/tilecolours/tilecolours_w4.bin"
```

**Map imports (src/data/levels/maps.asm):**

```kickasm
// maps.asm — map binary imports and dimension constants

// World 1 Level 1
.const W1L1_MAP_WIDTH   = 128
.const W1L1_MAP_HEIGHT  = 64
Map_W1L1: .import binary "data/levels/map_w1_l1.bin"
.if (* - Map_W1L1 != W1L1_MAP_WIDTH * W1L1_MAP_HEIGHT) {
    .error "map_w1_l1.bin size mismatch — check CharPad export dimensions"
}

// World 1 Level 2
.const W1L2_MAP_WIDTH   = 96
.const W1L2_MAP_HEIGHT  = 48
Map_W1L2: .import binary "data/levels/map_w1_l2.bin"
.if (* - Map_W1L2 != W1L2_MAP_WIDTH * W1L2_MAP_HEIGHT) {
    .error "map_w1_l2.bin size mismatch"
}
// ... repeat for all levels
```

**Sprite imports (src/data/sprites/sprites.asm):**

```kickasm
// sprites.asm — sprite frame binary imports

// Frame counts as constants for validation and SpriteIndex table
.const FRAMES_PLAYER        = 12
.const FRAMES_ENEMY_GUARD   =  4
.const FRAMES_ENEMY_FLYER   =  4
.const FRAMES_ENEMY_HEAVY   =  6
.const FRAMES_ENEMY_SHOOTER =  4
.const FRAMES_BOSS_W1       =  8
.const FRAMES_BOSS_W2       =  8
.const FRAMES_BOSS_W3       =  8
.const FRAMES_BOSS_W4       =  8
.const FRAMES_PROJECTILES   =  4
.const FRAMES_FX            =  8
.const FRAMES_COLLECTABLES  =  6
.const FRAMES_HUD           =  4

// Player
Sprites_Player: .import binary "data/sprites/spr_player.bin"
.if (* - Sprites_Player != FRAMES_PLAYER * 63) {
    .error "spr_player.bin frame count mismatch"
}

// Common enemies (present in all worlds)
Sprites_Guard:    .import binary "data/sprites/spr_enemy_guard.bin"
Sprites_Flyer:    .import binary "data/sprites/spr_enemy_flyer.bin"
Sprites_Heavy:    .import binary "data/sprites/spr_enemy_heavy.bin"
Sprites_Shooter:  .import binary "data/sprites/spr_enemy_shooter.bin"

// World-specific bosses
Sprites_Boss_W1:  .import binary "data/sprites/spr_boss_w1.bin"
Sprites_Boss_W2:  .import binary "data/sprites/spr_boss_w2.bin"
Sprites_Boss_W3:  .import binary "data/sprites/spr_boss_w3.bin"
Sprites_Boss_W4:  .import binary "data/sprites/spr_boss_w4.bin"

// Effects and pickups
Sprites_Proj:     .import binary "data/sprites/spr_projectiles.bin"
Sprites_FX:       .import binary "data/sprites/spr_fx.bin"
Sprites_Collect:  .import binary "data/sprites/spr_collectables.bin"
Sprites_HUD:      .import binary "data/sprites/spr_hud.bin"

// Total sprite frame budget check
.const TOTAL_SPR_FRAMES = FRAMES_PLAYER + FRAMES_ENEMY_GUARD +
    FRAMES_ENEMY_FLYER + FRAMES_ENEMY_HEAVY + FRAMES_ENEMY_SHOOTER +
    FRAMES_BOSS_W1 + FRAMES_PROJECTILES + FRAMES_FX +
    FRAMES_COLLECTABLES + FRAMES_HUD
.print "Total sprite frames: " + TOTAL_SPR_FRAMES + " / 95"
.if (TOTAL_SPR_FRAMES > 95) {
    .error "Sprite frame budget exceeded: " + TOTAL_SPR_FRAMES
}
```

---

### 17.7 Level Load — Asset Copy Sequence

At level transition, the load routine copies each asset from cartridge
into its RAM destination. The colour registers are written immediately
from LevelDesc fields:

```kickasm
// Extract and apply level colour registers
ldy #LevelDesc.col_bg
lda (zp_ptr), y
sta $D021               // background colour 0

ldy #LevelDesc.col_mc1
lda (zp_ptr), y
sta $D022               // shared multicolour 1

ldy #LevelDesc.col_mc2
lda (zp_ptr), y
sta $D023               // shared multicolour 2

ldy #LevelDesc.col_border
lda (zp_ptr), y
sta $D020               // border colour

ldy #LevelDesc.col_spr_mc0
lda (zp_ptr), y
sta $D025               // sprite shared MC0

ldy #LevelDesc.col_spr_mc1
lda (zp_ptr), y
sta $D026               // sprite shared MC1

// Then copy assets from cartridge:
// 1. Charset A (2KB) → $E000
// 2. Tile set, flags, colours → TileDefTable, TileFlagsCache, TileColourCache
// 3. Sprite frames → $C800 / $F000
// 4. Map header + data → ring buffer / RAM
// 5. Object data → level array at $4000
// (Full sequence in Section 10.3)
```

After the colour RAM values are loaded into TileColourCache, the initial
colour RAM fill (before scrolling begins) writes the per-tile colours
to $D800:

```kickasm
// Initial colour RAM fill from tile colour cache
// Called once after level load, before gameplay starts
// Subsequent updates handled by colour RAM shift routine during scroll

FillColourRAM:
    // Walk the ring buffer, look up tile colour, write to colour RAM
    // Each tile covers 2×2 chars = 4 colour RAM cells
    // ... (full implementation in engine/scroll/colour_ram.asm)
    rts
```

---

### 17.8 Test Asset Setup (Phases 3 and 4)

During engine testing (before real game assets exist), a minimal test
asset set provides enough content to verify the scroll and map systems.
These live alongside the main assets in the same folder structure,
named with a `test_` prefix:

```
data/gfx/charset/charset_test.bin     — simple test tileset
                                         (checkerboard + numbered tiles)
data/gfx/tiles/tiles_test.bin         — minimal 2×2 tile definitions
data/gfx/tileflags/tileflags_test.bin — half solid (tiles 0-63), half open
data/gfx/tilecolours/tilecolours_test.bin — distinct colour per tile band
data/levels/map_test.bin              — 128×64 test map
data/sprites/spr_test.bin             — single diamond sprite (as per
                                        mux_test_spec.md Phase 2 shape)
```

These are created directly in CharPad and SpritePad using the engine's
multicolour settings, giving early validation that the complete asset
pipeline works before game-specific content is produced.

