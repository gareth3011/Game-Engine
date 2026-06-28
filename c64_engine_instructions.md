# Claude Code — C64 Engine Development Instructions

**Project:** C64 Large Map Engine  
**Spec document:** `c64_engine_spec.md` (read this first and refer back to it constantly)  
**Assembler:** Kick Assembler (KickAss) v5.x — `java -jar tools/KickAss.jar`  
**Emulator:** VICE x64sc (cycle-exact PAL mode)  
**Target hardware:** Commodore 64 PAL  

---

## 1. Your Role

You are implementing a Commodore 64 game engine in 6502 assembly using
Kick Assembler. The full engine specification is in `c64_engine_spec.md`.
Read it completely before writing any code. It contains all memory addresses,
data structures, constants, cycle budgets, and design decisions. Do not
deviate from the spec without flagging the conflict first.

You are building in phases. Each phase has a standalone test program that
proves one subsystem before the next phase begins. Never start a new phase
until the current phase passes all its verification criteria.

Your primary outputs are `.asm` source files. Your secondary outputs are
notes about problems found, timing measurements, and anything in the spec
that needs clarification or revision.

---

## 2. Environment and Tools

### 2.1 Build

```bash
# Build a phase test
./build.sh phase2

# Build the full engine
./build.sh

# Build and launch in VICE immediately
./test.sh phase2
```

Always build before running. Never assume the last build is current.
Check the build output for warnings — KickAss warnings about unreferenced
labels or overlapping memory regions are real problems, not noise.

### 2.2 VICE Configuration

Launch with cycle-exact PAL timing:

```bash
x64sc -model c64 -pal -truedrive -autostart build/phase2_test.prg
```

Enable these VICE monitors for verification:

```
Monitor → Open Monitor          (for memory inspection and breakpoints)
View → Sprites                  (verify sprite positions and shapes)
View → VIC-II State             (confirm register values)
Debug → CPU History             (cycle counting)
```

To measure IRQ cycle cost in VICE monitor:
```
; Set a breakpoint at IRQ entry
break [irq_address]
; Record cycle counter on entry and exit
; Difference = IRQ cost in cycles
```

### 2.3 Real Hardware Testing

After each phase passes in VICE, test on real hardware before sign-off.
Transfer `.prg` to real C64 via your preferred method (SD2IEC, 1541
Ultimate, or transfer cable). Test PAL hardware first. If NTSC hardware
is available, test that too — timing differences will surface here that
VICE does not always catch.

### 2.4 Directory Layout

All source files go in `src/` following the structure in `c64_engine_spec.md`
Section 15.1. Never put source files in `build/` — that folder is for
output only and should not be committed.

Binary asset files go in `data/` following the naming convention in
`c64_engine_spec.md` Section 17.5. When referencing asset files use
paths relative to the `src/` directory:

```kickasm
.import binary "../data/gfx/charset/charset_w1.bin"
```

---

## 3. Kick Assembler Conventions

### 3.1 Always Use Preprocessor Features

This is non-negotiable. Every constant must be a `.const`, not a magic
number. Every repeated pattern must be a `.macro`. Every data structure
must be a `.struct`. Every loop that can be unrolled at assemble time
must use `.for`. This is not style preference — it is how the engine
achieves its cycle targets.

```kickasm
// WRONG — never do this
lda #$D0
sta $D016

// RIGHT
.const VIC_CONTROL2 = $D016
.const MC_MODE_BIT  = %00010000
lda #MC_MODE_BIT
sta VIC_CONTROL2
```

### 3.2 File Header Convention

Every source file begins with:

```kickasm
//============================================================
// [filename].asm
// Part of: C64 Large Map Engine
// Phase: [N] — [phase name]
// Section: [spec section number]
// Description: [one line]
//============================================================
```

### 3.3 Label Conventions

```
GlobalLabels:       PascalCase — visible across files
.localLabels:       dot prefix — local to current scope
!anonLabels:        bang prefix — anonymous, reference with !label+ / !label-
zp_variables:       snake_case with zp_ prefix for zero page
CONSTANTS:          UPPER_SNAKE for .const values
```

### 3.4 Zero Page Is Sacred

Every zero page byte is accounted for in `engine/zeropage.asm`. Before
using any zero page location, check it is allocated to you. If you need
scratch space inside a routine, save and restore whatever ZP bytes you
borrow:

```kickasm
// Save ZP scratch before using
lda zp_scratch
pha
lda zp_scratch2
pha
// ... use zp_scratch, zp_scratch2 ...
// Restore
pla
sta zp_scratch2
pla
sta zp_scratch
```

Do not use the stack for this if the routine can be interrupted — save
to dedicated temp locations in page 2 instead.

### 3.5 Cycle Counting

Every IRQ handler must have a cycle count comment. Count precisely:

```kickasm
MuxIRQ:
    asl $D019           // 6 cycles — acknowledge VIC IRQ
    jmp (zp_exec_ptr_lo)// 5 cycles — jump to display list
                        // TOTAL: 11 cycles overhead
```

When you are not sure of a cycle count, look it up. The 6502 instruction
timing reference is at: https://www.nesdev.org/wiki/6502_cycle_times
(Same timings apply to the 6510 in the C64.)

Key timings to know:
```
LDA immediate:  2 cycles
LDA absolute:   4 cycles
LDA absolute,X: 4 cycles (+1 if page crossed)
STA absolute:   4 cycles
STA zero page:  3 cycles
JSR:            6 cycles
RTS:            6 cycles
JMP absolute:   3 cycles
JMP indirect:   5 cycles
Branch taken:   3 cycles
Branch not taken: 2 cycles
RTI:            6 cycles
```

### 3.6 Import Order in Test Files

Each phase test file imports only what it needs:

```kickasm
// Phase 2 test — only imports mux-related modules
.import source "../engine/constants.asm"
.import source "../engine/zeropage.asm"
.import source "../engine/macros.asm"
.import source "../engine/irq/irq_init.asm"
.import source "../engine/irq/stable_raster.asm"
.import source "../engine/irq/mux_irq.asm"
.import source "../engine/irq/frame_irq.asm"
.import source "../engine/mux/mux_data.asm"
.import source "../engine/mux/mux_sort.asm"
.import source "../engine/mux/mux_builder.asm"
// NO scroll, map, object, collision, or cartridge modules
```

This enforces modularity — if a module compiles cleanly in isolation,
its dependencies are correctly bounded.

---

## 4. Working Method

### 4.1 Read the Spec Section First

Before writing a single line of code for any module, read its
corresponding spec section completely. Note:
- The exact RAM addresses it uses
- The zero page variables it reads and writes
- What it calls and what calls it
- The cycle budget it must meet
- The pass criteria for its phase test

If anything in the spec is ambiguous, note the ambiguity and make a
reasonable decision — but document the decision in a comment in the code:

```kickasm
// SPEC NOTE: Section 5.3 doesn't specify what happens when both H and V
// shift_pending bits are set simultaneously on the first frame after
// a diagonal direction change. Decision: process H first, V on next
// frame. This costs one extra frame of lag on diagonal start which is
// acceptable given the 3-frame total budget.
```

### 4.2 Write the Skeleton First

For each new module, write the full skeleton with all labels, empty
routines, and correct memory layout before filling in any logic:

```kickasm
//------------------------------------------------------------
// mux_sort.asm — Inverted Y-sort for sprite multiplexer
// Section 5 of mux_test_spec.md / Section 8 of c64_engine_spec.md
//------------------------------------------------------------

InsertSpriteY:
    // TODO: implement
    rts

RemoveSpriteY:
    // TODO: implement
    rts

BuildSortedList:
    // TODO: implement
    rts

ResetDirtyEntries:
    // TODO: implement
    rts
```

Build the skeleton. Fix any label conflicts or addressing errors.
Then fill in one routine at a time, building and testing after each.

### 4.3 Test Incrementally

Do not write 200 lines then build. Write 20-30 lines, build, check
for errors, then continue. On the C64 a bug in cycle timing or a
wrong address is invisible until runtime — catching errors early when
there is less to debug is essential.

### 4.4 Use VICE Monitor Extensively

The VICE monitor is your debugger. Use it proactively:

```
; Inspect zero page variables
m 00 3f

; Inspect a RAM table
m 3800 38ff

; Set a breakpoint at a specific address
break c000

; Watch a memory location for writes
watch store d016

; Check current register state
r

; Disassemble around current PC
d .pc-10 .pc+20

; Check cycle counter
; (available via CPU History window)
```

Before declaring a phase complete, use the monitor to verify every
data structure matches the spec:
- Walk the y_to_slot table and confirm it matches visible sprite positions
- Confirm display list buffers contain expected opcodes
- Verify sorted_slots is in ascending Y order each frame

### 4.5 When Something Doesn't Work

Work through this in order:

1. **Check the build output** — did it actually build without warnings?
2. **Check addresses** — is the code at the address you think it is?
   Use `d [label]` in VICE monitor to disassemble and confirm.
3. **Check zero page** — is a ZP variable being clobbered by another
   routine? Set a watch: `watch store [zp_address]`
4. **Check IRQ timing** — is an IRQ firing at the wrong raster line?
   Set a breakpoint at the IRQ handler and check $D012 on entry.
5. **Check register state** — at the point of failure, what are A, X,
   Y, SP, and the flags? Use `r` in the monitor.
6. **Reduce to minimum** — comment out everything except the failing
   part. If a 5-line routine doesn't work, isolate it completely.
7. **Check the spec** — re-read the relevant section. The spec may
   say something you missed on first reading.

Do not guess. Every bug on the C64 has a specific cause. Find it.

---

## 5. Phase-by-Phase Guidance

### Phase 1 — IRQ Foundation

**Goal:** Stable raster IRQ chain. Display list execution mechanism.
8 static sprites using pre-baked display list data.

**Start here:**

1. Write `engine/constants.asm` — all `.const` values from spec Section 13
2. Write `engine/zeropage.asm` — all `.label` aliases from spec Section 3
3. Write `engine/macros.asm` — `BankIn`, `BankOut`, `BankSwitch` macros
4. Write `engine/irq/irq_init.asm` — CIA disable, VIC IRQ enable, vector setup
5. Write `engine/irq/stable_raster.asm` — two-stage stable raster
6. Write `engine/mux/mux_data.asm` — pre-baked display list buffer skeletons
7. Write `engine/irq/mux_irq.asm` — the 11-cycle display list executor
8. Write `engine/irq/frame_irq.asm` — frame reset, buffer flip, frame_count
9. Write `src/tests/phase1_irq_test.asm` — hardcoded display list for 8 sprites

**The stable raster is the critical piece.** Get it right before
anything else. In VICE, open the raster display and confirm the IRQ
fires at the same raster line every frame with zero jitter. If there
is one-line jitter, the NOP count in StableRasterIRQ needs adjusting.

**Common Phase 1 problems:**

- CIA interrupts not disabled — the CIA fires timer IRQs by default and
  will fight your raster IRQ. Always write $7F to $DC0D and $DD0D at init,
  then read them to clear pending interrupts.

- Wrong $D011/$D012 for raster line — bit 8 of the raster line goes into
  bit 7 of $D011. For lines 0-255 clear this bit. For lines 256+ set it.
  In PAL the visible area is lines 0-311 but sprites are at 50-250.

- IRQ vector written to wrong location — with KERNAL mapped (Phase 1
  test keeps KERNAL for simplicity), IRQ vector is at $FFFE/$FFFF.
  In later phases when KERNAL is banked out, RAM at $FFFE/$FFFF must
  be initialised before banking out.

- Display list RTI at wrong offset — the pre-baked buffer skeleton must
  end with exactly one RTI ($40). Verify with `d [buffer_address]` in
  VICE monitor.

**Phase 1 pass criteria (from spec Section 16):**
- 8 sprites visible at correct positions, no flicker
- Stable raster confirmed over 60 seconds
- Buffer A/B alternating (check `active_buf` ZP byte in monitor)
- IRQ overhead ≤ 250 cycles measured in VICE

---

### Phase 2 — Sprite Multiplexer

**Goal:** 24 logical sprites via inverted Y-sort and display list builder.
This is the mux_test_spec.md deliverable.

**Read `mux_test_spec.md` completely.** It is a complete standalone
spec for this phase with its own memory layout, test patterns, and
verification checklist. Follow it exactly.

**Key implementation notes:**

The `BuildSortedList` routine has a register pressure problem described
in mux_test_spec.md Section 5.5. The outer loops use X (byte index into
dirty_y_bits) and Y (bit index within byte). The chain walk at each Y
position needs both registers for different purposes. Use `zp_scratch`
and `zp_scratch2` to save/restore outer loop state. Do not use the
stack inside this routine — it is called from the main loop where IRQs
may fire and corrupt the stack state.

The `BuildDisplayListA` and `BuildDisplayListB` routines are the most
complex part of this phase. They are separate routines (not a shared
routine with a runtime base pointer) because the performance goal
requires static addresses. Use KickAssembler's `.for` loop to generate
all 8×4 = 32 sprite register patches per IRQ group, per buffer:

```kickasm
BuildDisplayListA:
    .for (var group = 0; group < 3; group++) {
        .for (var hw = 0; hw < 8; hw++) {
            // Patch sprite hw in group into buffer A
            // All addresses are assemble-time constants
        }
    }
    rts
```

**Common Phase 2 problems:**

- y_to_slot chain corruption — if InsertSpriteY doesn't correctly
  handle the case where the slot being inserted is already the head
  of a chain, you get circular links. Add a loop counter to BuildSortedList
  and assert it never exceeds MAX_SPRITES.

- Display list buffer not patching the right byte — the operand byte
  of `LDA immediate` is at offset +1 from the opcode. If you patch
  the opcode byte instead, you corrupt the buffer. Verify with
  `d [buffer_address]` after BuildDisplayListA runs.

- Stable raster NOP count wrong for this configuration — Phase 2 adds
  more code before the first IRQ fires. Recheck the NOP count after
  adding the builder. Adjust until sprites don't drift vertically.

- spr_next chain not terminated — every InsertSpriteY must set
  spr_next[new_slot] = $FF if the chain was empty. Forgetting this
  causes BuildSortedList to walk off the end of the chain.

**Phase 2 pass criteria (from spec Section 16):**
- All 24 sprites visible and moving (sine, bounce, drift modes)
- No flicker on raster boundaries
- Two sprites at same Y both render
- sorted_slots in ascending Y order (verify in VICE monitor)
- y_to_slot empty after ResetDirtyEntries (verify frame by frame)
- Total mux cost ≤ 1,200 cycles

---

### Phase 3 — Scroll Engine

**Goal:** 4-way smooth scrolling against a static test map. Prove
fine + coarse shift, double buffer swap, colour RAM update, and edge fill.

**The colour RAM update is the hardest timing constraint.** It must
complete within the border/blank window. On PAL this is raster lines
235-311 — approximately 4,851 cycles. Half the colour RAM update must
fit in the window after the scroll IRQ at line 250, with the other half
deferred to the next frame's IRQ at line 280.

Implement and test colour RAM separately from screen RAM. Get the
screen shift working first (colour RAM can be a flat test colour
initially), then add colour RAM.

**Test map for Phase 3:**

Use `data/gfx/charset/charset_test.bin` and `data/levels/map_test.bin`.
If these don't exist yet, create a minimal test map in CharPad (any
graphics will do — a simple checkerboard is fine). The important thing
is that the map is large enough to scroll in all 4 directions without
hitting edges immediately (128×64 tiles minimum).

**Common Phase 3 problems:**

- Screen tearing on buffer swap — $D018 must be written outside the
  active display area. The buffer swap happens in the IRQ at line 250.
  If sprites appear torn (top half from buffer A, bottom from B) the
  IRQ is firing too early. Push it to line 252 or later.

- Colour RAM corruption — colour RAM at $D800 is being written while
  VIC is reading it for display. Move the write to line 260+.

- Edge fill shows wrong tiles — the ring buffer origin variables
  (ring_origin_x, ring_origin_y) are not being updated when the
  camera position crosses a tile boundary. Update these in the coarse
  shift routine.

- Diagonal shift phase counter wrong — the 3-frame diagonal shift
  uses shift_phase to track progress. If shift_phase is not reset
  to 0 after phase 2 completes, the next diagonal shift starts
  mid-sequence and produces garbage.

**Phase 3 pass criteria (from spec Section 16):**
- Smooth scroll all 4 directions at 1-4 px/frame
- Diagonal completes cleanly (3-frame shift)
- No screen tearing or colour corruption
- Phase 2 sprites unaffected by scroll engine
- Frame budget ≤ 75% on diagonal (measure in VICE)

---

### Phase 4 — Map System and World Coordinates

**Goal:** Real tile map with world coordinates. Player sprite collides
with solid tiles. World-to-screen conversion correct during scroll.

**The fine scroll compensation in WorldToScreenX is critical.** If
`fine_x` is not added to the sprite's computed screen X, the sprite
will appear to slide horizontally against the background by up to 7
pixels during smooth scroll. This is very visible and must be fixed
before the phase can be considered working.

Test this specifically: hold the joystick right so the scroll is moving
continuously. Watch the player sprite relative to a tile edge. It must
appear perfectly stationary relative to the background. Any sliding
indicates the fine scroll compensation is wrong.

**Tile flag cache access pattern:**

```kickasm
// Fast solid tile check
lda tile_index      // tile at position being checked
tay
lda TileFlagsCache, y
and #TILE_FLAG_SOLID
bne .its_solid
```

This is a single indexed load — the flags cache is optimised for exactly
this access pattern. Do not use the full TileDefTable for collision
checks.

**Common Phase 4 problems:**

- Wrong tile at screen edge after scroll — the edge fill routine is
  computing the wrong world tile coordinate. The rightmost visible
  tile column is `cam_x_hi + SCREEN_TILE_W`, not `cam_x_hi + SCREEN_TILE_W - 1`.
  Off-by-one errors in edge coordinates are very common here.

- Player passes through solid tile — the collision check is using the
  wrong foot position. The foot check should be at `act_y_hi + 1`
  (one block below origin), not `act_y_hi`. For objects taller than
  one block, check at `act_y_hi + height_in_blocks`.

- Ring buffer lookup returns wrong tile — the ring buffer modular
  index calculation has a bug. Verify with a known position: at
  ring_origin_x=0, ring_origin_y=0, world position (5, 3) should
  return ring buffer byte at offset 3*64 + 5 = 197. Check in VICE monitor.

---

### Phase 5 — Object System and AI

**Goal:** Active/inactive object pool, AI dispatch, HP writeback,
persistent state. One enemy type (guard) as test case.

**The activation scan runs 16 entries per frame (rolling).** This means
a level with 32 objects takes 2 frames to fully scan. Objects near the
activation boundary may take up to 2 frames to activate after entering
range. This is acceptable and by design — the activation radius (12 blocks)
is large enough that the delay is imperceptible.

**The HP writeback on deactivation is the persistence mechanism.** Test
this explicitly: damage a guard to reduce HP, walk far enough away that
it deactivates (> 14 blocks), return within activation range, verify
the guard has the reduced HP from your last visit.

**Guard AI minimum implementation for Phase 5:**

```
State 0 IDLE:    stand still, timer counts down, transition to PATROL
State 1 PATROL:  walk in current direction, reverse at wall/edge
State 2 CHASE:   move toward player if within detection radius
State 3 HURT:    brief invincibility period, return to PATROL
```

Keep AI simple in Phase 5. The goal is proving the dispatch mechanism
and state persistence, not behaviour richness. Behaviour is refined in
Phase 8.

**Common Phase 5 problems:**

- Active slot count exceeds MAX_ACTIVE — the activation routine must
  check that a free slot exists before activating. Add an assertion:
  if no free slot found, log the rejection (increment a counter visible
  in VICE monitor) and skip activation.

- Dead objects reactivate — lev_flags bit 7 (LEV_FLAG_DEAD) must be
  checked before activation attempt. If lev_hp is 0 at deactivation,
  set this bit. The scan routine checks this bit first.

- act_lev_idx not set on activation — when copying a level object into
  an active slot, `act_lev_idx` must record which level array entry it
  came from. This is needed for HP writeback on deactivation. Forgetting
  this causes HP writeback to corrupt a random level entry.

---

### Phase 6 — Collision Detection

**Goal:** Five-stage collision cascade. Span mask geometry for common
pairs. Event queue and response dispatch.

**Verify each stage independently before combining.** Add a counter
per stage that increments when that stage rejects a pair. In VICE monitor
confirm the distribution matches expectations:
- Stages 1-2 should reject ~70% of pairs
- Stage 3 (group mask) should reject ~20% more
- Stage 4 (dx/dy) should reject most of the remainder
- Stage 5 (geometry) should fire rarely

If Stage 5 fires on every frame for all pairs, stages 1-4 are not working.

**Collision mask data for Phase 6 test:**

For the guard enemy and player, create minimal span mask data by hand
(not from SpritePad yet). A simple rectangular approximation is fine
for proving the mechanism:

```kickasm
// Guard collision mask — simple rectangle approximation
// empty_top=3, height=15, minxskip=4
GuardCollMask:
    .byte 3, 15, 4          // empty_top, height, minxskip
    // 15 rows of (empty_left, span_width):
    .byte 4, 16   // row 0 (3 pixels from left, 16 wide)
    .byte 3, 18   // row 1
    .byte 3, 18   // rows 2-12 (typical body width)
    // ... etc
```

Replace with SpritePad-derived accurate masks in Phase 8.

**Common Phase 6 problems:**

- Span mask row count off — if empty_top + height > 21, the mask walk
  reads beyond the mask data into adjacent memory. Always validate
  empty_top + height <= 21 at assemble time for each mask definition.

- Collision event queue overflow — 8 slots is enough for typical play
  but a frame where 8 simultaneous collisions occur is theoretically
  possible. The LogCollision routine must silently drop events when
  the queue is full (increment a `coll_dropped` counter for debugging).
  Never write beyond coll_obj_a + MAX_COLL_EVENTS.

- Group mask check not symmetric — check is required in both directions
  (i responds to j's group AND j responds to i's group). If only one
  direction is checked, player-enemy collisions work but enemy-player
  collisions (taking damage) may not.

---

### Phase 7 — Cartridge Integration

**Goal:** All assets from EasyFlash cartridge. Two levels with distinct
tilesets. Full level transition sequence.

**This is the first phase requiring real EasyFlash hardware or an
emulated cartridge in VICE.** VICE supports EasyFlash via `.crt` image
files. Build the cartridge image using the EasyFlash developer tools
or a custom script that assembles the bank layout defined in spec
Section 3.2.

**The bank switch safety rule is absolute:** No bank switch ($DE00 or
$DE01 write) must occur during gameplay. Set a VICE watchpoint:

```
watch store de00
```

This breakpoint must never fire during the game loop (only during
level load). If it fires during gameplay, a bank switch is happening
where it should not.

**Level transition sequence order matters.** The screen must be fully
blanked before any asset copy begins. The colour RAM fill must happen
after the new tile colour data is loaded, not before. The IRQ chain
must be reduced to a simple ACK-only handler during the load. Restore
the full IRQ chain only after all assets are in place and colour RAM
is filled.

---

### Phase 8 — Integration and Polish

**Goal:** Full engine running. All systems together. Profiling.
NTSC compatibility. SID music.

**Profiling method in VICE:**

Use a raster colour trick to measure frame budget visually:

```kickasm
// At start of main loop work:
lda #14         // light blue
sta $D020       // border colour

// ... all main loop work ...

// At end of main loop work (just before wait for frame):
lda #0          // black
sta $D020
```

The width of the coloured border in a PAL raster display shows exactly
how much of the frame the main loop consumed. If the border colour
extends into the active display area, you are over budget.

**NTSC compatibility check:** The `NTSC_flag` at ZP $32 is set during
init. Every timing-critical value (IRQ raster lines, colour RAM split
position) must use conditional values based on this flag:

```kickasm
lda NTSC_flag
bne .ntsc
lda #250            // PAL scroll IRQ line
bne .set_line
.ntsc:
lda #235            // NTSC scroll IRQ line (earlier — shorter frame)
.set_line:
sta $D012
```

Test NTSC in VICE by launching with `-ntsc` flag.

---

## 6. Common 6502 / C64 Pitfalls

These are errors that appear regularly in C64 assembly development.
Check for them when debugging.

### 6.1 Page Crossing Penalty

`LDA absolute,X` takes 4 cycles normally but 5 if the address + X
crosses a page boundary ($xxFF → $xx00+). If your table straddles a
page boundary, lookup times are inconsistent. For timing-critical
tables, ensure they are page-aligned:

```kickasm
.align 256          // force next label to page boundary
MyTable: .fill 256, 0
```

### 6.2 Indirect JMP Bug ($6C)

`JMP ($xxFF)` on the 6502 (not 65C02) reads the low byte from $xxFF
and the high byte from $xx00 (not $0100 as you might expect). This
is the indirect JMP page boundary bug. Avoid placing jump vectors at
$xxFF addresses. The ZP indirect JMP `JMP (zp_ptr)` is safe as long as
the ZP pointer does not live at $FF.

### 6.3 BCD Mode Persistence

If any code executes with the Decimal flag set (after a SED instruction),
ADC and SBC operate in BCD mode and give wrong results for binary
arithmetic. Always CLD at startup and after any code that might set
the D flag. The C64 KERNAL does not CLD on IRQ entry.

### 6.4 Sprite X Position MSB

Sprite X positions use 9 bits. Bits 0-7 go to $D000, $D002, etc.
Bit 8 (the MSB for X > 255) goes to the corresponding bit in $D010.
If a sprite disappears when moving past X=255, the MSB is not being
set. The display list builder handles this via `d010_accum` — verify
it is being patched into the buffer correctly.

### 6.5 VIC Bad Lines

The VIC-II steals 40-43 cycles from the CPU on every "bad line" —
every 8th raster line during the active display area (approximately
lines where raster_line & 7 == YSCROLL). This means your IRQ handler
may take up to 43 extra cycles longer than expected if it fires on
or near a bad line. The stable raster technique avoids this for the
first IRQ, but subsequent IRQs in the chain should be timed to fire
between bad lines where possible.

### 6.6 Stack Depth

The 6502 stack is only 256 bytes ($0100-$01FF). Each JSR uses 2 bytes,
each IRQ saves 3 bytes (PC lo, PC hi, flags). Deeply nested calls
inside an IRQ can overflow the stack silently — the return address
just wraps around and the program jumps to a nonsensical address.
Keep IRQ handlers flat (no JSR to routines that themselves call JSR).
The display list approach in this engine avoids this by using JMP
not JSR for display list execution.

### 6.7 Colour RAM Is Nybble-Wide

Colour RAM at $D800-$DBFF stores only 4 bits per location (0-15).
Writes of values > 15 are silently masked to the lower 4 bits. This
is not a problem if colours are validated, but if you accidentally
write a tile index (0-255) to colour RAM instead of a colour value,
only the lower 4 bits take effect — which happens to work for tiles
0-15 but gives wrong colours for tiles 16+. A common debugging mistake
is loading colour RAM with tile indices during development.

### 6.8 The Accumulator After Compare

`CMP` does not change the accumulator. But `AND`, `ORA`, `EOR`, `ASL`,
`LSR`, `ROL`, `ROR` do. A very common bug is:

```kickasm
cmp #VALUE
bcc somewhere       // OK — carry set by CMP
asl                 // BUG — now A has been shifted, not compared
```

If you need the original value after a shift or logical operation,
save it first.

---

## 7. Asset Integration Notes

### 7.1 CharPad Binary Layout

When you import `charset_w1.bin` with `.import binary`, KickAssembler
places the raw bytes sequentially starting at the current assembly
address. The format is exactly what the VIC-II expects: 8 bytes per
character, character 0 first, character 255 last, top row to bottom
row within each character.

The tile set export from CharPad (2×2 tile mode) is:
```
4 bytes per tile: [char_tl, char_tr, char_bl, char_br]
NUM_TILES tiles sequentially
```
This maps directly to the `TileDef.char_tl` through `char_br` fields.

The tile attributes export is:
```
1 byte per tile: material/flag value as assigned in CharPad
NUM_TILES bytes
```
Maps directly to `TileFlagsCache`.

The tile colours export (Per Tile mode) is:
```
1 byte per tile: colour RAM nybble value (0-15)
NUM_TILES bytes
```
Maps directly to `TileColourCache`.

The map export is:
```
MAP_WIDTH × MAP_HEIGHT bytes, row-major (left to right, top to bottom)
1 byte per tile index (8-bit export)
```

**There is no header.** Dimensions must be stored separately as constants.

### 7.2 SpritePad Binary Layout

Sprite frame export from SpritePad:
```
63 bytes per frame (3 bytes × 21 rows)
Frames packed sequentially
No header
```

The VIC-II expects 64-byte alignment for sprite data (the pointer
value × 64 = sprite data address). SpritePad exports 63 bytes (the
actual sprite data), not 64. The engine's sprite frame slots are 64
bytes each. When copying SpritePad data into sprite RAM, copy 63 bytes
and leave the 64th byte unchanged (or set to 0). Do not copy 64 bytes
from a 63-byte frame — that reads 1 byte from the next frame.

```kickasm
.macro CopySpriteFrame(src_label, dest_slot) {
    .var dest = $C800 + dest_slot * 64  // or $F000 area for slot >= 32
    ldx #62             // 63 bytes (indices 0-62)
.loop:
    lda src_label, x
    sta dest, x
    dex
    bpl .loop
    // byte 63 (the 64th) left as-is
}
```

### 7.3 Multicolour Tile Rendering During Scroll

When the scroll engine fills an exposed column or row, it must write
both the character codes (to screen RAM) AND the colour values (to
colour RAM) for the new tiles. The character codes come from the
TileDefTable (via ring buffer tile lookup → char codes). The colour
values come from TileColourCache (tile index → colour nybble).

The colour RAM write for edge fill tiles happens in the colour RAM
update routine (engine/scroll/colour_ram.asm), not in edge_fill.asm.
The two are synchronised by the shift_phase flag — edge fill runs in
phase 1, colour RAM edge fill runs in the same phase 1 IRQ immediately
after.

---

## 8. When to Ask for Help

If you encounter any of the following, stop and document the issue
rather than working around it:

- A spec section that contradicts another section
- A cycle budget that cannot be met even with full optimisation
- A hardware behaviour that doesn't match the spec's assumptions
- A KickAssembler limitation that prevents implementing the spec as written
- Real hardware behaviour that doesn't match VICE

In each case write a clear description:
```
ISSUE: [section X] — [what the spec says]
OBSERVED: [what actually happens]
IMPACT: [what this prevents]
OPTIONS: [possible resolutions]
```

This document will be reviewed and the spec updated if needed.

---

## 9. Definition of Done

A phase is **not** done until:

- [ ] Builds cleanly with zero warnings in KickAss
- [ ] All pass criteria from spec Section 16 are met in VICE
- [ ] All pass criteria met on real PAL C64 hardware
- [ ] VICE monitor verification completed (tables match spec, cycle
      counts within budget)
- [ ] Code is commented — every non-obvious instruction has a comment,
      every routine has a header comment with cycle cost where relevant
- [ ] All labels follow the naming convention (Section 3.3)
- [ ] Zero page usage matches `engine/zeropage.asm` — no unregistered ZP use
- [ ] No magic numbers — every constant has a `.const` name

Do not move to the next phase until every item above is checked.

---

*These instructions should be read alongside `c64_engine_spec.md`.
The spec defines what to build. These instructions define how to build it.*
