# Claude Code Instructions

## Project Technical Specs

- **Target:** Commodore 64, 6510 CPU, 64KB RAM, PAL/NTSC
- **Assembler:** Kick Assembler 5.24 (case-sensitive for macro and pseudocommand names)
- **Full KA manual:** `D:\Development\Reference\C64\KickAssembler.pdf`
- **Reference library:** `D:\Development\Reference\C64`
- **Engine spec:** [c64_engine_spec.md](c64_engine_spec.md) — read this before writing any engine code
- **Build instructions:** [c64_engine_instructions.md](c64_engine_instructions.md) — phase-by-phase implementation guide
- **Entry point:** [Game Engine Entry.asm](Game Engine Entry.asm) — `BasicUpstart2(Entry)` → `jmp STRUCTURE.Initialise`

---

## Verification Process

Before reporting any code change as complete:

1. **Build check (always).** Compile from the project root with Kick Assembler 5.24:
   ```
   java -jar "D:\Development\C64\Utilities\Kick Assembler\KickAss.jar" "Game Engine Entry.asm" -odir .
   ```
   This regenerates `Game Engine Entry.prg`, `Game Engine Entry.sym` in place. A clean compile has zero errors and zero warnings.
   - Report any compiler errors/warnings verbatim, with file:line.
   - A clean compile proves the source is syntactically valid and fits its memory regions —
     it does **not** prove the game logic is correct.

2. **Runtime check (when feasible).** For behavioural changes, launch the build in VICE
   (`D:\Development\C64\Utilities\Vice\bin\x64sc.exe`, loading `Game Engine Entry.prg`) and exercise the affected feature directly.
   - State explicitly whether this was done, and what was observed.
   - If a change can't realistically be exercised this way, say so rather than claiming success.

3. **Reporting back.** At the end of a task, summarize:
   - Whether it compiled cleanly.
   - Whether/how it was tested in the emulator, and what was observed.
   - Anything that still needs the user to manually verify in-game.

Never claim a feature "works" based on compilation alone — only on observed behaviour, or a
clear statement that it's unverified.

---

## IDE Extension Notes

The VS Code KickAssembler extension auto-generates `.source.txt` files to track the active file. When editing files in subdirectories (e.g. `Modules/IRQ.asm`), the extension compiles that file in isolation and will show false positives for undefined macros/symbols that are only visible when compiled via the full entry point. **Ignore IDE diagnostics for undefined macros/symbols in library and module files — the command-line build is the authoritative check.**

---

## Primary Reference Files

| File | Purpose |
|------|---------|
| [Supporting Documentation/Kick Quick Ref.txt](Supporting%20Documentation/Kick%20Quick%20Ref.txt) | Kick Assembler directives and syntax |
| [Supporting Documentation/mapthe64.txt](Supporting%20Documentation/mapthe64.txt) | C64 hardware and memory map reference |
| [Supporting Documentation/Hacks.md](Supporting%20Documentation/Hacks.md) | Optimisation tricks for the C64 |
| [Supporting Documentation/6510 Assembly Instructions.pdf](Supporting%20Documentation/6510%20Assembly%20Instructions.pdf) | Instruction clock cycle counts |
| [Supporting Documentation/FLAGS.TXT](Supporting%20Documentation/FLAGS.TXT) | Additional reference flags |
| [Library/Constants/C_Memory Map.asm](Library/Constants/C_Memory%20Map.asm) | **Authoritative memory layout — check before touching any address** |
| [Library/Constants/C_ZP.asm](Library/Constants/C_ZP.asm) | Zero page address map |
| [Library/Constants/C_Global.asm](Library/Constants/C_Global.asm) | Game-wide constants, enums, bit masks, sprite/powerup/enemy indices |
| [Library/Constants/C_ControlPanel.asm](Library/Constants/C_ControlPanel.asm) | Tunable game parameters (raster lines, timers, etc.) |
| [Library/Constants/C_CIA.asm](Library/Constants/C_CIA.asm) | CIA chip registers |
| [Library/Constants/C_VIC.asm](Library/Constants/C_VIC.asm) | VIC chip registers |
| [Library/Constants/C_SID.asm](Library/Constants/C_SID.asm) | SID chip registers |

If a referenced file cannot be opened, output a `MISSING_FILES:` list and stop until the user confirms how to proceed.

---

## External References

- General C64 6502 assembly: https://codebase64.net/doku.php?id=start
- Illegal opcodes: https://codebase64.net/doku.php?id=base:advanced_optimizing
- Instruction timing (cycle-critical work): https://www.oxyron.de/html/opcodes02.html

---

## Memory Map

```
$0000-$00FF   Zero page (ZP namespace — see C_ZP.asm)
              $02-$1E  ZP variables (Temp0-7, Vectors, Counters, FrameFlag)
$0100-$01FF   Stack
$0200-$07FF   Free / future use (sort buffers, collision queues)
$0801-$080D   BASIC upstart (13 bytes)
$0810-$0812   Entry point  →  jmp STRUCTURE.Initialise
$0820-$08FF   Lookup tables (TABLES namespace)
$1000-$2FFF   Music and SFX (8KB — reserved, currently empty)
$3000-$7FFF   Game code (STRUCTURE namespace + modules)
              $3000  STRUCTURE.Initialise
              $3006  STRUCTURE.TitleScreen (main loop)
              $302D  IRQ.Initialise
              $3062  IRQ.IRQ1 (raster IRQ at line 20)
              $307E  UTILS data + routines
$8000-$BFFF   EasyFlash cartridge windows (future — Phase 7)
$C000-$FFFF   VIC-II bank 3
              $C000-$C3FF  Screen RAM (1KB)
              $C400-$CFFF  Spare
              $D000-$DFFF  I/O blind spot (VIC/SID/CIA registers, colour RAM)
              $E000-$E7FF  Character set A (2KB)
              $E800-$EFFF  Spare / Character set B (HUD)
              $F000-$FEFF  Sprite frames (future)
              $FF00-$FFFF  IRQ/NMI vectors (RAM, KERNAL banked out)
```

**CPU memory config ($0001):** `_IO_VISIBLE | _RAM_01` = `%00000101` → KERNAL banked out, I/O at `$D000`, RAM at `$A000` and `$E000–$FFFF`.

**VIC Setup:** Bank 3 (`$C000–$FFFF`) via CIA `$DD00` bits 0–1 = `%00`. Screen at `$C000`, charset at `$E000`. `$D018 = $08` (screen offset 0, charset offset 4×2048=$2000 in bank).

---

## Code Architecture

### Namespaces

| Namespace | Location | Purpose |
|-----------|----------|---------|
| `VIC` | `Library/Constants/C_VIC.asm` | VIC-II register addresses |
| `CIA` | `Library/Constants/C_CIA.asm` | CIA register addresses |
| `ZP` | `Library/Constants/C_ZP.asm` | Zero page labels |
| `TABLES` | `Library/Tables.asm` | Lookup tables |
| `STRUCTURE` | `Game Engine Structure.asm` | Main game loop + all modules |
| `IRQ` | `Modules/IRQ.asm` | Raster IRQ handler (nested in STRUCTURE) |
| `UTILS` | `Modules/Utils.asm` | Utility routines (nested in STRUCTURE) |

Full label path convention: `NAMESPACE.Scope.label` e.g. `STRUCTURE.IRQ.IRQ1`.

---

## Naming Conventions

| Context | Convention | Example |
|---|---|---|
| Global constants | `_UPPERCASE` | `_SCREEN_WIDTH` |
| Global labels | `_UPPERCASE` | `_GAME_START` |
| Zero page addresses | `PascalCase` | `BallXPos` |
| Namespace | `UPPERCASE` | `BALL` |
| Scope | `PascalCase` | `UpdatePosition` |
| Multilabels | `!camelCase` | `!nextLoop` |
| Scope labels | `camelCase` | `skipDraw` |
| Function constants | `_name_Of_Constant` | `_delay_Time` |
| Function labels | `camelCase` | `loopStart` |
| Data addresses | `camelCase` or `camel_Case` | `spriteData` |
| Self-modifying | `_camel_Case` | `_lda_Addr` |
| Macro names | `camelCase` | `frameCounter` |
| Macro variables | `camelCase` | `srcAddr` |

Full path: `NAMESPACE.Scope.nameOfLabel`. Constants always `.const` unless impossible.

**KickAssembler macro and pseudocommand names are case-sensitive.** Always match exact case when calling macros (e.g. `frameCounter()` not `FrameCounter()`).

**Function parameters:** strict in/out — a parameter is input or output, never both.

**Comments:** If you feel you need to comment what code does, rewrite the code. Only comment the non-obvious *why*.

---

## Constants Rules

- Never hardcode addresses or register values — always use named constants
- New constants go in the appropriate `Library/Constants/` file with a brief purpose comment
- Chip constants: use `C_CIA.asm`, `C_VIC.asm`, `C_SID.asm` as the authority

---

## Zero Page (C_ZP.asm)

Layout follows the spec (Section 2.1) exactly. Engine block is fixed; allocate new game variables in the `$58–$FF` area only.

| Range | Label(s) | Purpose | Phase |
|-------|----------|---------|-------|
| `$02–$03` | `ZP.MapPtr` | Map ring buffer pointer | 4 |
| `$04–$05` | `ZP.ObjPtr` | Active object data pointer | 5 |
| `$06–$07` | `ZP.Scratch` | General scratch 16-bit pointer | all |
| `$08–$0B` | `ZP.CamXHi/Lo, CamYHi/Lo` | Camera world position | 3 |
| `$0C–$0F` | `ZP.FineX/Y, ScrollFlags, ShiftPhase` | Scroll engine state | 3 |
| `$10–$1F` | `ZP.SpriteX[16]` | Logical sprite X positions | 2 |
| `$20–$2F` | `ZP.SpriteY[16]` | Logical sprite Y positions | 2 |
| `$30` | `ZP.MuxSort` | Multiplexer sort temporary | 2 |
| `$31` | `ZP.FrameCount` | Frame counter 0–255, wraps | 2 |
| `$32` | `ZP.NTSCFlag` | 0=PAL, 1=NTSC | 8 |
| `$33` | `ZP.FrameFlag` | Set by IRQ, consumed by main loop | 1 |
| `$34–$35` | `ZP.Counter` | 16-bit extended frame counter (MSB, LSB) | 1 |
| `$36–$3F` | *(reserved)* | Engine expansion | — |
| `$40–$43` | `ZP.FLDOffsetCur/Tgt, FLDScrollRate, FLDFlags` | FLD parallax (Phase 3 future) | 3 |
| `$44–$47` | `ZP.Temp0–3` | Single-function temporaries | all |
| `$48–$4A` | `ZP.TempA/X/Y` | Register save slots | all |
| `$4B–$52` | `ZP.Vector1–4` | Temporary 16-bit pointers | all |
| `$53–$54` | `ZP.ColourVector` | Pointer into colour RAM | 3 |
| `$55–$56` | `ZP.ScreenVector` | Pointer into screen RAM | 3 |
| `$57` | `ZP.BitCounter1` | Rolling bit counter | all |
| `$58–$FF` | *(free)* | Game-specific allocation | — |

Check `C_ZP.asm` before adding anything. List address conflicts rather than auto-assigning.

---

## Macro Library (Phase 1 active set)

| File | Status | Key macros |
|------|--------|-----------|
| `Library/Macros/M_IRQ.asm` | Active | `enterIRQ`, `exitIRQ`, `disableTimerInterrupts`, `setIRQ` (pseudocommand) |
| `Library/Macros/M_General.asm` | Active | `frameCounter`, `resetCounters`, `wait`, `saveA/X/Y`, `restoreA/X/Y` |
| `Library/Macros/M_Environment.asm` | Active | `VICSetup` (5 params — not yet called; inline setup used in Phase 1) |
| `Library/Macros/M_Utils.asm` | Partial | Generic math/bit utils active; `getJoystick_1/resetJoystick_1` disabled (need PLAYER namespace) |
| `Library/Includes/Debug_Border.inc` | Active | `debugStart`, `debugEnd` — assembly-time colour stack, runtime border writes |
| `Library/Macros/M_Screen.asm` | Disabled | Commented out — not needed yet |
| `Library/Macros/M_Sprites.asm` | Disabled | Commented out — requires MULTIPLEXER namespace (Phase 2+) |

---

## Cycle-Critical Rules

- Prefer cycle-optimal implementations when ≤30% extra bytes
- If cycle saving >10% but byte cost >30%, ask before proceeding
- Consult instruction timing reference and `Supporting Documentation/6510 Assembly Instructions.pdf`

---

## Illegal Opcodes

Only use when explicitly approved in the target module's header. Include a compatibility note and commented-out fallback. `M_Utils.asm` contains `dcm` (illegal) in the `dec16Bit` pseudocommand — this is disabled and must not be called until reviewed.

---

## Current Phase: Phase 1 — IRQ Foundation

**Status:** Base compiles cleanly. Single raster IRQ fires at line 20 (`_IRQ_1_RASTER = 20` in `C_ControlPanel.asm`). Border colour used as timing probe via `debugStart`/`debugEnd`.

**What is working:**
- CIA timer interrupts disabled
- VIC raster interrupt enabled, fires at raster line 20
- KERNAL banked out (`$0001 = _IO_VISIBLE | _RAM_01`), IRQ vector at `$FFFE/$FFFF`
- IRQ handler saves/restores registers, sets `ZP.FrameFlag`, acknowledges VIC interrupt
- Main loop (`STRUCTURE.TitleScreen`) waits on `ZP.FrameFlag` and increments frame counter

**Not yet done (see issues.md):**
- VIC bank 3 not configured (uses KERNAL default bank 0 — display will be garbage)
- `VICSetup()` macro not called; inline setup only does memory banking
- Stable raster (two-stage) not yet implemented
- No sprite multiplexer
