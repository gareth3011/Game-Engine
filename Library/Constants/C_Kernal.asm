.namespace KERNAL {
// ++++ KERNAL SUBROUTINES ---------------------------------------------------------------------------------------------
	.label K_POLY1        	= $E043 	// Function Series Evaluation Subroutine 1
	.label K_POLY2        	= $E059 	// Function Series Evaluation Subroutine 2
	.label K_RMULC        	= $E08D 	// Multiplicative Constant for RND
	.label K_RADDC        	= $E092 	// Additive Constant for RND
	.label K_RND          	= $E097 	// Random Number Generator
	.label K_SYS 			= $E12A 	// Perform SYS
	.label K_SAVE         	= $E156 	// Sets Save Pointers for Basic
	.label K_VERIFY 		= $E165		// Load/Verify Flag at $10
	.label K_LOAD 			= $E168		// Gets Load pointers

    .label K_WAIT_KEY     	= $F142 	// Wait for key
    .label K_SCINIT       	= $FF81 	// Input: – Output: – Used registers: A, X, Y
    .label K_IOINIT       	= $FF84 	// Input: – Output: – Used registers: A, X
    .label K_RAMTAS       	= $FF87 	// Input: – Output: – Used registers: A, X, Y
    .label K_RESTOR       	= $FF8A 	// Input: – Output: – Used registers: –
    .label K_VECTOR       	= $FF8D 	// Input: Carry: 0 = Copy user table into vector table, 1 = Copy vector table into user table; X/Y = Pointer to user table. Output: – Used registers: A, Y
    .label K_SETMSG       	= $FF90 	// Input: A = Switch value. Output: – Used registers: –
    .label K_LSTNSA       	= $FF93 	// Input: A = Secondary address Output: – Used registers: A
    .label K_TALKSA       	= $FF96 	// Input: A = Secondary address Output: – Used registers: A
    .label K_MEMBOT       	= $FF99 	// Input: Carry: 0 = Restore from input, 1 = Save to output; X/Y = Address (if Carry = 0) Output: X/Y = Address (if Carry = 1) Used registers: X, Y
    .label K_MEMTOP       	= $FF9C 	// Input: Carry: 0 = Restore from input, 1 = Save to output; X/Y = Address (if Carry = 0) Output: X/Y = Address (if Carry = 1) Used registers: X, Y
    .label K_SCNKEY       	= $FF9F 	// Input: – Output: – Used registers: A, X, Y
    .label K_SETTMO       	= $FFA2 	// Input: A = Timeout value Output: – Used registers: –
    .label K_IECIN        	= $FFA5 	// Input: – Output: A = Byte read Used registers: A
    .label K_IECOUT       	= $FFA8 	// Input: A = Byte to write Output: – Used registers: –
    .label K_UNTALK       	= $FFAB 	// Input: – Output: – Used registers: A
    .label K_UNLSTN       	= $FFAE 	// Input: – Output: – Used registers: A
    .label K_LISTEN       	= $FFB1 	// Input: A = Device number Output: – Used registers: A
    .label K_TALK         	= $FFB4 	// Input: A = Device number Output: – Used registers: A
    .label K_READST       	= $FFB7 	// Input: – Output: A = Device status Used registers: A
    .label K_SETLFS       	= $FFBA 	// Input: A = Logical number; X = Device number; Y = Secondary address Output: – Used registers: –
    .label K_SETNAM       	= $FFBD 	// Input: A = File name length; X/Y = Pointer to file name Output: – Used registers: –
    .label K_OPEN         	= $FFC0 	// Input: – Output: – Used registers: A, X, Y
    .label K_CLOSE        	= $FFC3 	// Input: A = Logical number Output: – Used registers: A, X, Y
    .label K_CHKIN        	= $FFC6 	// Input: X = Logical number Output: – Used registers: A, X
    .label K_CHKOUT       	= $FFC9 	// Input: X = Logical number Output: – Used registers: A, X
    .label K_CLRCHN       	= $FFCC 	// Input: – Output: – Used registers: A, X
    .label K_CHRIN        	= $FFCF		// Input: – Output: A = Byte read Used registers: A, Y
    .label K_CHROUT       	= $FFD2 	// Input: A = Byte to write Output: – Used registers: –
    .label K_LOAD         	= $FFD5 	// Input: A: 0 = Load, 1-255 = Verify; X/Y = Load address (if secondary address = 0) Output: Carry: 0 = No errors, 1 = Error; A = KERNAL error code (if Carry = 1); X/Y = Address of last byte loaded/verified (if Carry = 0) Used registers: A, X, Y
    .label K_SAVE         	= $FFD8 	// Input: A = Address of zero page register holding start address of memory area to save; X/Y = End address of memory area plus 1 Output: Carry: 0 = No errors, 1 = Error; A = KERNAL error code (if Carry = 1) Used registers: A, X, Y
    .label K_SETTIM       	= $FFDB 	// Input: A/X/Y = New TOD value Output: – Used registers: –
    .label K_RDTIM        	= $FFDE		// Input: – Output: A/X/Y = Current TOD value Used registers: A, X, Y
    .label K_STOP         	= $FFE1 	// Input: – Output: Zero: 0 = Not pressed, 1 = Pressed; Carry: 1 = Pressed Used registers: A, X
    .label K_GETIN        	= $FFE4 	// Input: – Output: A = Byte read Used registers: A, X, Y
    .label K_CLALL        	= $FFE7 	// Input: – Output: – Used registers: A, X
    .label K_UDTIM        	= $FFEA 	// Input: – Output: – Used registers: A, X
    .label K_SCREEN       	= $FFED 	// Input: – Output: X = Number of columns (40); Y = Number of rows (25) Used registers: X, Y
    .label K_PLOT         	= $FFF0 	// Input: Carry: 0 = Restore from input, 1 = Save to output; X = Cursor column (if Carry = 0); Y = Cursor row (if Carry = 0) Output: X = Cursor column (if Carry = 1); Y = Cursor row (if Carry = 1) Used registers: X, Y
    .label K_IOBASE       	= $FFF3 	// Input: – Output: X/Y = CIA #1 base address ($DC00) Used registers: X, Y
}