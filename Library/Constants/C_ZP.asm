.namespace ZP {
    .pc = $02 "Zero Page" virtual

// ============================================================================
// ENGINE ZERO PAGE  $02-$43
// Layout matches c64_engine_spec.md Section 2.1 exactly.
// Do not move or insert here without updating the spec.
// ============================================================================

// ++++ MAP SYSTEM (Phase 4) ---------------------------------------------------
    MapPtr:         .word $0000     // $02-$03  Map ring buffer pointer

// ++++ OBJECT SYSTEM (Phase 5) ------------------------------------------------
    ObjPtr:         .word $0000     // $04-$05  Active object data pointer

// ++++ GENERAL SCRATCH (engine-wide) ------------------------------------------
    Scratch:        .word $0000     // $06-$07  General-purpose scratch pointer
                                    //          Save/restore if used across calls

// ++++ SCROLL ENGINE / CAMERA (Phase 3) ---------------------------------------
    CamXHi:         .byte $00       // $08      Camera world block X
    CamXLo:         .byte $00       // $09      Camera sub-block X (fixed point)
    CamYHi:         .byte $00       // $0A      Camera world block Y
    CamYLo:         .byte $00       // $0B      Camera sub-block Y (fixed point)
    FineX:          .byte $00       // $0C      Hardware fine scroll X (0-7 → $D016 bits 0-2)
    FineY:          .byte $00       // $0D      Hardware fine scroll Y (0-7 → $D011 bits 0-2)
    ScrollFlags:    .byte $00       // $0E      Scroll direction (bit0=R, bit1=L, bit2=D, bit3=U)
    ShiftPhase:     .byte $00       // $0F      Coarse shift phase (0=first half, 1=second half)

// ++++ SPRITE MULTIPLEXER (Phase 2) -------------------------------------------
    SpriteX:        .fill 16, 0     // $10-$1F  Logical sprite X positions (16 slots)
    SpriteY:        .fill 16, 0     // $20-$2F  Logical sprite Y positions (16 slots)

// ++++ MULTIPLEXER SORT (Phase 2) ---------------------------------------------
    MuxSort:        .byte $00       // $30      Multiplex insertion-sort temporary

// ++++ TIMING & SYSTEM --------------------------------------------------------
    FrameCount:     .byte $00       // $31      Frame counter 0-255 (wraps — used by mux timing)
    NTSCFlag:       .byte $00       // $32      0 = PAL, 1 = NTSC (detected at startup, Phase 8)

// ++++ GAME / ENGINE RESERVED  $33-$3F ----------------------------------------
    FrameFlag:      .byte $00       // $33      Set by IRQ each frame, consumed by main loop
    Counter:        .byte $00,$00   // $34-$35  16-bit extended frame counter (MSB, LSB)
                                    //          Byte 0 (MSB): ~5 sec per tick at 50fps
                                    //          Byte 1 (LSB): incremented every frame
    .fill 10, 0                     // $36-$3F  Reserved — game-specific engine expansion

// ++++ FLD / PARALLAX (Phase 3 future — do not use before then) ---------------
    FLDOffsetCur:   .byte $00       // $40      FLD parallax offset current
    FLDOffsetTgt:   .byte $00       // $41      FLD parallax offset target
    FLDScrollRate:  .byte $00       // $42      FLD scroll rate fraction
    FLDFlags:       .byte $00       // $43      FLD state flags

// ============================================================================
// GAME-SPECIFIC ZERO PAGE  $44+
// Allocate new game variables here. Document each addition with its address.
// ============================================================================

// ++++ TEMPORARIES (single-function only — must not persist across calls) -----
    Temp0:          .byte $00       // $44
    Temp1:          .byte $00       // $45
    Temp2:          .byte $00       // $46
    Temp3:          .byte $00       // $47
    TempA:          .byte $00       // $48      Save slot for accumulator
    TempX:          .byte $00       // $49      Save slot for X register
    TempY:          .byte $00       // $4A      Save slot for Y register

// ++++ GENERAL 16-BIT POINTERS (single-function only) ------------------------
    Vector1:        .word $0000     // $4B-$4C
    Vector2:        .word $0000     // $4D-$4E
    Vector3:        .word $0000     // $4F-$50
    Vector4:        .word $0000     // $51-$52

// ++++ SCREEN POINTERS --------------------------------------------------------
    ColourVector:   .word $0000     // $53-$54  Points into colour RAM ($D800)
    ScreenVector:   .word $0000     // $55-$56  Points into screen RAM ($C000)

// ++++ BIT COUNTERS -----------------------------------------------------------
    BitCounter1:    .byte $80       // $57      Rolling bit counter (ror to cycle through bits)

// $58-$FF available for game-specific allocation

}
