.namespace TABLES {
    // Screen address row lookup for first character positions, Low byte and High byte
    .pc = * "Tables Screen address"
    ScreenRowLB:
        .fill 25, <[VIC._SCREEN_RAM + i * $28]		// Where I = row number from 0 to 24 (25 bytes) and $28 is 40 characters per row
    ScreenRowHB:
        .fill 25, >[VIC._SCREEN_RAM + i * $28]		// Where I = row number from 0 to 24 (25 bytes) and $28 is 40 characters per row
    ColourRowHB:
        .fill 25, >[VIC._COLOUR_RAM + i * $28]		// Where I = row number from 0 to 24 (25 bytes) and $28 is 40 characters per row

    .pc = * "Tables Pof2"
    Pof2:   // Or Table for setting bits - Additional rows used by Multiplexer
        .fill 6, [$01,$02,$04,$08,$10,$20,$40,$80]

    .pc = * "Tables RPof2"
    RPof2:  // And Table for clearing bits - Additional rows used by Multiplexer
        .fill 6, [$FE,$FD,$FB,$F7,$EF,$DF,$BF,$7F]

    .align $10
    .pc = * "Tables TimerLB"
    TimerLB:  // Number of seconds in low byte of frame timer: 51 frames = 1 second
        //     00, 01, 02, 03, 04, 05  Seconds
        .byte $00,$33,$66,$99,$CC,$FF
}