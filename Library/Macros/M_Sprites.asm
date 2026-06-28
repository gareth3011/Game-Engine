	.macro sprite_SetFrame (frame, offset) {			// Set sprite Frame
		.if(frame != null) {
			lda #frame
		}
			sta MULTIPLEXER.Data.spriteFrame + offset
	}

	.macro sprite_SetFrame_x (frame, offset) {			// Set sprite Frame, indexed x
		.if(frame != null) {
			lda #frame
		}
			sta MULTIPLEXER.Data.spriteFrame + offset,x
	}

	.macro sprite_SetFrame_y (frame, offset) {			// Set sprite Frame, indexed y
		.if(frame != null) {
			lda #frame
		}
			sta MULTIPLEXER.Data.spriteFrame + offset,y
	}

	.macro sprite_SetColour (colour, offset) {			// Set sprite colour
		.if(colour != null) {
			lda #colour
		}
			sta MULTIPLEXER.Data.spriteColour + offset
	}

	.macro sprite_SetColour_x (colour, offset) {		// Set sprite colour, indexed x
		.if(colour != null) {
			lda #colour
		}
			sta MULTIPLEXER.Data.spriteColour + offset,x
	}

	.macro sprite_SetColour_y (colour, offset) {		// Set sprite colour, indexed y
		.if(colour != null) {
			lda #colour
		}
			sta MULTIPLEXER.Data.spriteColour + offset,y
	}

	.macro sprite_SetMC (flag, offset) {				// Set sprite Multicolour
		.if(flag != null) {
			lda #flag
		}
			sta MULTIPLEXER.Data.spriteMC + offset
	}

	.macro sprite_SetMC_x (flag, offset) {				// Set sprite Multicolour, Indexed x
		.if(flag != null) {
			lda #flag
		}
			sta MULTIPLEXER.Data.spriteMC + offset,x
	}
	
	.macro sprite_SetMC_y (flag, offset) {				// Set sprite Multicolour, Indexed y
		.if(flag != null) {
			lda #flag
		}
			sta MULTIPLEXER.Data.spriteMC + offset,y
	}

	.macro setSpriteMC1 (colour)	{					// Set Sprite Multicolour 1 
			lda #colour
			sta VIC._SPMC0
	}

	.macro setSpriteMC2 (colour) {						// Set Sprite Multicolour 2
			lda #colour
			sta VIC._SPMC1
	}

	.macro sprite_SetPosition (xpos, ypos, offset) {	// Set the sprite position on screen
		.if(xpos != null) {
			lda #<xpos
			sta MULTIPLEXER.Data.spriteX + offset
			lda #>xpos
			sta MULTIPLEXER.Data.spriteXMSB + offset
		}
		.if(ypos != null) {
			lda #ypos
			sta ZP.SpriteY + offset
		}
	}

	.macro sprite_SetPosition_x (xpos, ypos, offset) {	// Set the sprite position on screen, Indexed X
		.if(xpos != null) {
			lda #<xpos
			sta MULTIPLEXER.Data.spriteX + offset,x
			lda #>xpos
			sta MULTIPLEXER.Data.spriteXMSB + offset,x
		}
		.if(ypos != null) {
			lda #ypos
			sta ZP.SpriteY + offset,x
		}
	}

	.macro sprite_SetPosition_y (xpos, ypos, offset) {	// Set the sprite position on screen, Indexed Y
		.if(xpos != null) {
			lda #<xpos
			sta MULTIPLEXER.Data.spriteX + offset,y
			lda #>xpos
			sta MULTIPLEXER.Data.spriteXMSB + offset,y
		}
		.if(ypos != null) {
			lda #ypos
			sta ZP.SpriteY + offset,y
		}
	}

