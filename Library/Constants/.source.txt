.namespace ZP  {
    .pc = $02 "Zero Page" virtual

// ++++ TEMP PARAMETERS (single-function temporaries only — never persist across calls) --------
    Temp0:                  .byte $00   // $02
    Temp1:                  .byte $00   // $03
    Temp2:                  .byte $00   // $04
    Temp3:                  .byte $00   // $05
    TempA:                  .byte $00   // $06
    TempX:                  .byte $00   // $07
    TempY:                  .byte $00   // $08

// ++++ TEMP VECTORS (16-bit scratch pointers, single-function only) ---------------------------
    Vector1:                .word $0000 // $09-$0A
    Vector2:                .word $0000 // $0B-$0C
    Vector3:                .word $0000 // $0D-$0E
    Vector4:                .word $0000 // $0F-$10

// ++++ SCREEN ----------------------------------------------------------------------------------
    ColourVector:           .word $0000 // $11-$12
    ScreenVector:           .word $0000 // $13-$14

// ++++ COUNTERS & FLAGS ------------------------------------------------------------------------
    BitCounter1:            .byte $80   // $15
    Counter:                .byte $00,$00 // $16-$17 — frame counter (MSB at $16, LSB at $17)
    FrameFlag:              .byte $00   // $18 — set by IRQ, consumed by main loop

// ++++ RESERVED GAP ($19-$1F) — available for future engine use --------------------------------
    .fill 7, 0                          // $19-$1F

// ++++ SPRITE MULTIPLEXER (Phase 2) -----------------------------------------------------------
// Spec Section 2.1: $10-$1F logical sprite X, $20-$2F logical sprite Y
// We use $20-$2F (X) and $30-$3F (Y) to avoid the $10-$1F overlap with temporaries above.
// NOTE: If the spec's exact addresses are required for a Phase 3+ feature, revisit this layout.
    SpriteX:                .fill 16, 0 // $20-$2F — logical sprite X positions (16 slots)
    SpriteY:                .fill 16, 0 // $30-$3F — logical sprite Y positions (16 slots)

// ++++ SCROLL ENGINE (Phase 3) — reserved, not yet implemented ---------------------------------
    CamXHi:                 .byte $00   // $40 — camera world block X
    CamXLo:                 .byte $00   // $41 — camera sub-block X
    CamYHi:                 .byte $00   // $42 — camera world block Y
    CamYLo:                 .byte $00   // $43 — camera sub-block Y
    FineX:                  .byte $00   // $44 — VIC fine scroll X (0-7, written to $D016 bits 0-2)
    FineY:                  .byte $00   // $45 — VIC fine scroll Y (0-7, written to $D011 bits 0-2)
    ScrollFlags:            .byte $00   // $46 — direction bits (bit0=R, bit1=L, bit2=D, bit3=U)
    ShiftPhase:             .byte $00   // $47 — coarse shift phase (0=first half, 1=second half)

// ++++ NTSC FLAG (Phase 8) --------------------------------------------------------------------
    NTSCFlag:               .byte $00   // $48 — 0 = PAL, 1 = NTSC (detected at startup)

// ++++ $49-$FF — game-specific zero page (allocate here as needed) ----------------------------

}
