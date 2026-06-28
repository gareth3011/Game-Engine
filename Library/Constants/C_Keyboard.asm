// ++++ KEYBOARD -------------------------------------------------------------------------------------------------------
/*
+----+----------------------+-------------------------------------------------------------------------------------------------------+
|    |                      |                                Peek from $dc01 (code in paranthesis):                                 |
|row:| $dc00:               +------------+------------+------------+------------+------------+------------+------------+------------+
|    |                      |   BIT 7    |   BIT 6    |   BIT 5    |   BIT 4    |   BIT 3    |   BIT 2    |   BIT 1    |   BIT 0    |
+----+----------------------+------------+------------+------------+------------+------------+------------+------------+------------+
|1.  | #%11111110 (254/$fe) | DOWN  ($  )|   F5  ($  )|   F3  ($  )|   F1  ($  )|   F7  ($  )| RIGHT ($  )| RETURN($  )|DELETE ($  )|
|2.  | #%11111101 (253/$fd) |LEFT-SH($  )|   e   ($05)|   s   ($13)|   z   ($1a)|   4   ($34)|   a   ($01)|   w   ($17)|   3   ($33)|
|3.  | #%11111011 (251/$fb) |   x   ($18)|   t   ($14)|   f   ($06)|   c   ($03)|   6   ($36)|   d   ($04)|   r   ($12)|   5   ($35)|
|4.  | #%11110111 (247/$f7) |   v   ($16)|   u   ($15)|   h   ($08)|   b   ($02)|   8   ($38)|   g   ($07)|   y   ($19)|   7   ($37)|
|5.  | #%11101111 (239/$ef) |   n   ($0e)|   o   ($0f)|   k   ($0b)|   m   ($0d)|   0   ($30)|   j   ($0a)|   i   ($09)|   9   ($39)|
|6.  | #%11011111 (223/$df) |   ,   ($2c)|   @   ($00)|   :   ($3a)|   .   ($2e)|   -   ($2d)|   l   ($0c)|   p   ($10)|   +   ($2b)|
|7.  | #%10111111 (191/$bf) |   /   ($2f)|   ^   ($1e)|   =   ($3d)|RGHT-SH($  )|  HOME ($  )|   ;   ($3b)|   *   ($2a)|   £   ($1c)|
|8.  | #%01111111 (127/$7f) | STOP  ($  )|   q   ($11)|COMMODR($  )| SPACE ($20)|   2   ($32)|CONTROL($  )|  <-   ($1f)|   1   ($31)|
+----+----------------------+------------+------------+------------+------------+------------+------------+------------+------------+
*/
	.const _KEY_ROW1            = %11111110         	// Keyboard Row 1
	.const _KEY_ROW2            = %11111101         	// Keyboard Row 2
	.const _KEY_ROW3            = %11111011         	// Keyboard Row 3
	.const _KEY_ROW4            = %11110111         	// Keyboard Row 4
	.const _KEY_ROW5            = %11101111         	// Keyboard Row 5
	.const _KEY_ROW6            = %11011111         	// Keyboard Row 6
	.const _KEY_ROW7            = %10111111         	// Keyboard Row 7
	.const _KEY_ROW8            = %01111111         	// Keyboard Row 8

	.const _KEY_INST_DEL		= $00
	.const _KEY_RETURN			= $01	
	.const _KEY_CRSR_LR			= $02
	.const _KEY_F7_F8			= $03
	.const _KEY_F1_F2			= $04
	.const _KEY_F3_F4			= $05
	.const _KEY_F5_F6			= $06
	.const _KEY_CRSR_UD			= $07
	.const _KEY_3				= $08
	.const _KEY_W				= $09
	.const _KEY_A				= $0A
	.const _KEY_4				= $0B
	.const _KEY_Z				= $0C
	.const _KEY_S				= $0D
	.const _KEY_E				= $0E
	.const _KEY_LSHIFT			= $0F
	.const _KEY_5				= $10
	.const _KEY_R				= $11
	.const _KEY_D				= $12
	.const _KEY_6				= $13
	.const _KEY_C				= $14
	.const _KEY_F				= $15
	.const _KEY_T				= $16
	.const _KEY_X				= $17
	.const _KEY_7				= $18
	.const _KEY_Y				= $19
	.const _KEY_G				= $1A
	.const _KEY_8				= $1B
	.const _KEY_B				= $1C
	.const _KEY_H				= $1D
	.const _KEY_U				= $1E
	.const _KEY_V				= $1F
	.const _KEY_9				= $20
	.const _KEY_I				= $21
	.const _KEY_J				= $22
	.const _KEY_0				= $23
	.const _KEY_M				= $24
	.const _KEY_K				= $25
	.const _KEY_O				= $26
	.const _KEY_N				= $27
	.const _KEY_PLUS			= $28
	.const _KEY_P				= $29
	.const _KEY_L				= $2A
	.const _KEY_MINUS			= $2B
	.const _KEY_GRTR_THAN		= $2C
	.const _KEY_BRKT_OPEN		= $2D
	.const _KEY_AT				= $2E
	.const _KEY_LESS_THAN		= $2F
	.const _KEY_POUNDS			= $30
	.const _KEY_MULTIPLY		= $31
	.const _KEY_BRKT_CLOSE		= $32
	.const _KEY_CLR_HOME		= $33
	.const _KEY_RSHIFT			= $34
	.const _KEY_EQUALS			= $35
	.const _KEY_UP				= $36
	.const _KEY_QUESTION		= $37
	.const _KEY_1				= $38
	.const _KEY_LEFT			= $39
	.const _KEY_CTRL			= $3A
	.const _KEY_2				= $3B
	.const _KEY_SPACE			= $3C
	.const _KEY_COMMODORE		= $3D
	.const _KEY_Q				= $3E
	.const _KEY_RUN_STOP		= $3F
