ANIMATIONS: {
        ScreenShakeIndex:
                .byte $00               // 0 = no screen shake, any other value is number of frames to shake for. (#16 is good)
        ScreenShakeV:
                .byte $03               // First byte is default value
                .fill 7, floor(random() * 4) + 1
        ScreenShakeH:
                .byte $00
                .fill 7, floor(random() * 4)

        Shake: {
                
                // Screen Shake
                // Acc = No of frames to run the shake for.
                // eg envoke with lda #16, sta IRQ.ScreenShakeIndex
                lda ScreenShakeIndex              
                beq !+
                sec
                sbc #$01
                sta ScreenShakeIndex
                and #$07
                tax
                lda VIC.SCROLY
                and #%11111000
                ora ScreenShakeV,x
                sta VIC.SCROLY
                lda VIC.SCROLX
                and #%11111000
                ora ScreenShakeH,x
                sta VIC.SCROLX
        !:
                rts
        }


}