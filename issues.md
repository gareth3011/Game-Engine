# Issues

This file tracks bugs, TODOs, and planned features for the C64 Game Engine project.
Format: `[PHASE] Category — description`

---

## Phase 1 — IRQ Foundation

### Bugs
- **[P1-BUG-01]** `$D018` value in spec (Section 2.3) is incorrect. Spec states `$D018 = %00010001` for screen at `$C000` / charset at `$E000`, but the correct value is `$08` (screen offset=0, charset offset=4×2048). Fix `$D018` documentation in spec and in `VICSetup` calls once the macro is in use.

### TODO
- **[P1-TODO-01]** VIC bank 3 not configured. `IRQ.Initialise` currently only banks out KERNAL; it does not set `CIA.$DD00` for bank 3 or write `$D018`. Display will show garbage. Add full VIC setup (`VICSetup` macro call with correct parameters) or an equivalent inline sequence.
- **[P1-TODO-02]** `VICSetup` macro in `M_Environment.asm` takes 5 parameters (`io, ram, bank, screen, charset`) but has never been called with arguments. When Phase 1 VIC setup is added, call it as: `VICSetup(_IO_VISIBLE, _RAM_01, _VIC_BANK_3, VIC._SCREEN_RAM, _CHARACTER_DATA)`.
- **[P1-TODO-03]** Stable raster (two-stage NOP-pad technique) not implemented. Current IRQ can have 1-line jitter on bad lines. Required before sprite multiplexer work begins.
- **[P1-TODO-04]** `UTILS.Random.Initialise` starts CIA Timer A (`$DC0E = $91`). Verify this doesn't conflict with any future CIA interrupt use.
- **[P1-TODO-05]** Character data at `$E000` is empty RAM. The display will show random characters. Load or copy a charset before Phase 3 scroll work.
- **[P1-TODO-06]** `Supporting Documentation/` is missing an `Etiquette.txt` / coding conventions document referenced in `CLAUDE.md`. Create or rename `FLAGS.TXT` if that is the intended file.

### Macro Library Status
- **[P1-TODO-07]** `Library/Macros/M_Utils.asm` — `getJoystick_1()` and `resetJoystick_1()` reference `PLAYER.Data.*` which does not exist yet. Re-enable when the PLAYER module is created.
- **[P1-TODO-08]** `Library/Macros/M_Utils.asm` — `dec16Bit` pseudocommand uses the illegal opcode `dcm`. Review and replace with legal equivalent (`dec`) or enable illegal opcodes explicitly when this pseudocommand is needed.
- **[P1-TODO-09]** `Library/Macros/M_Screen.asm` — commented out but clean. Re-enable when screen manipulation is needed.
- **[P1-TODO-10]** `Library/Macros/M_Sprites.asm` — disabled, references `MULTIPLEXER` namespace. Re-enable in Phase 2 once the sprite multiplexer module exists.
- **[P1-TODO-11]** `Modules/Effects.asm` — not imported anywhere. Uses `VIC.SCROLY` (should be `VIC._SCROLY`) and `VIC.SCROLX` (should be `VIC._SCROLX`). Fix naming and import when screen effects are needed.

---

## Phase 2 — Sprite Multiplexer (planned)

- Implement `MULTIPLEXER` namespace with `Data` struct (`spriteX`, `spriteXMSB`, `spriteY`, `spriteFrame`, `spriteColour`, `spriteMC` arrays)
- Re-enable `Library/Macros/M_Sprites.asm`
- Insertion sort by Y position
- IRQ chain for hardware sprite reassignment
- See spec Section 8 and `c64_engine_instructions.md` Phase 2

---

## Phase 3 — Scroll Engine (planned)

- 4-way fine + coarse scroll
- Double-buffered screen RAM
- Ring buffer for map data
- Colour RAM split update
- See spec Section 5

---

## Phase 4 — Map System (planned)

- Tile definition table
- World coordinate system
- Background collision via tile flag cache
- See spec Sections 4 and 6

---

## Phase 5 — Object System (planned)

- Active object pool (MAX_ACTIVE = 8)
- Level data array
- AI state dispatch
- HP writeback on deactivation
- See spec Section 7

---

## Phase 6 — Collision Detection (planned)

- Five-stage cascade (activity → Y broad phase → group mask → dx/dy → geometry)
- Span mask data
- Collision event queue
- See spec Section 9.1

---

## Phase 7 — Cartridge Integration (planned)

- EasyFlash bank layout
- Asset loading at level transitions
- See spec Section 3

---

## Phase 8 — Integration and Polish (planned)

- Full engine running
- NTSC compatibility
- SID music
- Profiling via border colour trick
- See `c64_engine_instructions.md` Phase 8
