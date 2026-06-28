.namespace ZP  {
    .pc = $02 "Zero Page" virtual

// ++++ TEMP PARAMETERS (Only use inside a single function) ------------------------------------------------------------
    Temp0:                  .byte $00
    Temp1:                  .byte $00
    Temp2:                  .byte $00
    Temp3:                  .byte $00
    TempA:                  .byte $00
    TempX:                  .byte $00
    TempY:                  .byte $00
														
// ++++ TEMP VECTORS ---------------------------------------------------------------------------------------------------
    Vector1:                .word $0000
    Vector2:                .word $0000
    Vector3:                .word $0000
    Vector4:                .word $0000

// ++++ SCREEN --------------------------------------------------------------------------------------------------------
    ColourVector:           .word $0000
    ScreenVector:           .word $0000

// ++++ COUNTERS & FLAGS -----------------------------------------------------------------------------------------------
                            //    MSB LSB
    BitCounter1:            .byte $80
    Counter:                .byte $00,$00               // Timer Counter - Incremented every frame - 
                                                        // Byte 0 (5 to 1275 seconds (21 minutes)), Byte 1 (0-5 seconds)
                                                        // 1 sec = $32, 2 sec $64, 3 sec = $96, 4 sec = $C8
    FrameFlag:              .byte $00

}