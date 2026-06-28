// ENVIRONMENT SETUP
	.macro VICSetup (io, ram, bank, screen, charset) {
	// Set Ram visibility
			lda VIC._R6510
			and #%11111000								// reset lower 3 bits
			ora #(io | ram)								// Set ROM/RAM Areas
			sta VIC._R6510								// RAM visible at $A000-$BFFF and $E000-$FFFF; I/O area visible at $D000-$DFFF
		/* 
			Bits 0-2 of $0001 (R6510) configure the memory areas $A000-$BFFF, $D000-$DFFF, $E000-$FFFF
				%x00: RAM visible in all three areas.
				%x01: RAM visible at $A000-$BFFF and $E000-$FFFF.
				%x10: RAM visible at $A000-$BFFF; KERNAL ROM visible at $E000-$FFFF.
				%x11: BASIC ROM visible at $A000-$BFFF; KERNAL ROM visible at $E000-$FFFF.
				%0xx: Character ROM visible at $D000-$DFFF. (Except for the value %000, see above.)
				%1xx: I/O area visible at $D000-$DFFF. (Except for the value %100)
			Default: $37, %00110111
		*/

	//Set VIC Bank
			lda CIA._CI2PRA
			and #%11111100								// Mask out banks to set by clearing bits 0 and 1
			ora #bank									// Set the Bank
			sta CIA._CI2PRA
		/*  Bits 0,1 control the Vic Bank.  Bank 00 range is $C000-$FFFF.  Default is 11 $0-$3FFF
			$DD00 = %xxxxxx11 -> Bank0: $0000-$3FFF
			$DD00 = %xxxxxx10 -> Bank1: $4000-$7FFF
			$DD00 = %xxxxxx01 -> Bank2: $8000-$BFFF
			$DD00 = %xxxxxx00 -> Bank3: $C000-$FFFF
		*/

	//Set screen and character memory
			lda	#([screen & $3FFF] / 64) | ([charset & $3FFF] / 1024)
			sta VIC._VMCSB
		/*
			Default Lo nybble    %0100   This locates Character block 2 which gives address 2 x 2048 = 4096 or $1000
			%000, 0: $0000-$07FF Bits #1 to #3 only for Character bank
			%001, 1: $0800-$0FFF
			%010, 2: $1000-$17FF 
			%011, 3: $1800-$1FFF
			%100, 4: $2000-$27FF
			%101, 5: $2800-$2FFF
			%110, 6: $3000-$37FF
			%111, 7: $3800-$3FFF
			Default Hi nybble    %0001   Address of screen - offset of 1 x 1024 ($0400) bytes from start of VIC Memory
			Bits #4-#7: Pointer to screen memory (bits #10-#13), relative to VIC bank, memory address $DD00. Values:
			%0000, 0: $0000-$03FF, 0-1023.
			%0001, 1: $0400-$07FF, 1024-2047.
			%0010, 2: $0800-$0BFF, 2048-3071.
			%0011, 3: $0C00-$0FFF, 3072-4095.
			%0100, 4: $1000-$13FF, 4096-5119.
			%0101, 5: $1400-$17FF, 5120-6143.
			%0110, 6: $1800-$1BFF, 6144-7167.
			%0111, 7: $1C00-$1FFF, 7168-8191.
			%1000, 8: $2000-$23FF, 8192-9215.
			%1001, 9: $2400-$27FF, 9216-10239.
			%1010, 10: $2800-$2BFF, 10240-11263.
			%1011, 11: $2C00-$2FFF, 11264-12287.
			%1100, 12: $3000-$33FF, 12288-13311.
			%1101, 13: $3400-$37FF, 13312-14335.
			%1110, 14: $3800-$3BFF, 14336-15359.
			%1111, 15: $3C00-$3FFF, 15360-16383.

			SUMMARY
			SCREEN ADDRESS WILL NOW BE $C000 - VIC START ADDRESS $C000 + OFFSET $000
			CHARACTER DATA WILL BE STORED AT $E000 - VIC START ADDRESS $C000 + OFFSET $2000
		*/
	}

    .macro ClearZP () {
			ldx #$02
			lda #$00
		!loop:
			sta $00,x
			inx
			bne !loop-
	}
