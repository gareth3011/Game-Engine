*******************************************************
1. **COOKIE CUTTER**
For example, to store bits 3-5 of the accumulator into a memory location while leaving the other bits untouched:

```asm
eor $BEEF
and #%00111000 // Bits 3 to 5 $38
eor $BEEF
sta $BEEF
```

If you want to read bits 3-5 of a memory location into the corresponding bits of the accumulator, you may similarly do:

```asm
eor $BEEF
and #%11000111 // Bits 3 to 5 $C7
eor $BEEF
```

but there's a very important proviso here: $BEEF MUST NOT change between the two 'eor' instructions.  Any bit of $BEEF which changes between those instructions will cause the corresponding bit in the accumulator to be toggled if not in the range of bit 3..5.

*******************************************************
2. SUBTRACT FROM X REG
This:
```asm
  ldx #56
  Loop:
 // do some stuff here
  txa
  sec
  sbc #14
  tax
  bne Loop
```

Can be rewritten like this:
```asm
  ldx #56
  Loop:
 // do some stuff here
  txa
  sbx #14
  bne loop
```

*******************************************************
3. CHOOSING TWO OUTCOMES
```asm
	lda MyNumber
	bpl B1
	sta Loc1
	bmi Done // (This is effectively a BRA to Done.)
B1:
	sta Loc2
Done:
```

It uses 10 bytes. Now consider this alternative:
```asm
	lda MyNumber
	bpl B1
	sta Loc1
	.byte $2C (Skips the next 2 bytes, effectively doing a BRA to Done.)
B1:
	sta Loc2
Done:
```

It only uses 9 bytes, and does the same thing. When the processor hits the ".byte $2C", it reads this as an Absolute BIT command, which is a 3 byte command. So, it uses the two bytes of the sta Loc2 command as the argument to the BIT command, performs a meaningless BIT test,  and then continues to run, without ever executing the STA Loc2 command. The only thing to be careful with this is that the  N, V, and Z flags will be corrupted. But the accumulator is not affected. So you've just saved a byte.  Also be wary that one extra cycle is used. BIT Absolute is 4 cycles, and a BMI branch is 3 cycles (or 4 if it crosses a page boundary.)

Using Zero Page
```asm
	lda MyNumber
	bpl B1
	clc
	.byte $24 // (Skips the next bytes using BIT Zero Page, effectively doing a BRA to Done.)
B1:
	sec
Done:
```

*******************************************************
4. 0/1 TOGGLE
```asm
	lda ZPTOGGLE
	eor #$01
	sta ZPTOGGLE
	bne ODDFRAME 	// Branch to ODDFRAME every "odd" frame, else EVENFRAME
EVENFRAME: 			// code goes here
ODDFRAME:			// Code goes here
```

All you have to do when setting this up at the start of the program is to ensure the variable ZPTOGGLE = either 0 or 1  and EOR will invert that value every frame, producing a 0,1,0,1,0,1,0,1,0 cycle ad infinitum.

*******************************************************
5. FASTER SUBTRACTION
```asm
lda #%00011111
sec
sbc BITTABLE,y 	// where BITTABLE,Y is known to hold only values less than #%00011111
```

That takes 2 + 2 + 4* cycles = 8-9 cycles, the actual number depending on whether or not the page boundary is crossed by the SBC,Y operation; and if we say, by way of illustration, that the value in BITTABLE,Y = #%00001111 (15 in decimal), the result will be #%00010000, i.e, 31 - 15 = 16.

So if we can safely predict the range of the value being subtracted, we could use EOR to do the subtraction like this:

```asm
lda BITTABLE,y
eor #%00011111 	// Shorthand for subtracting BITTABLE,Y from #%00011111
```

The same calculation (with the same result, obviously!) now takes 4* + 2 cycles = 6-7 cycles, the actual number depending on whether or not the page boundary is crossed by the LDA,Y operation, with the extra bonus of the carry flag remaining unaltered by the calculation!

*******************************************************
6. FASTER ADDITION
For example, let's say you want to add any number less than $80 (in decimal, 128 or, in binary %10000000) to $80; normally, you would use CLC and ADC to do the following (we should keep it all in binary to help understand what's happening with the various bits):
```asm
lda #%00001010
clc
adc #%10000000
```

That gives a result of #%10001010 (138 in decimal) in the A-reg and takes 2 + 2 + 2 = 6 cycles, 
but consider that the following will give you the same result:
```asm
lda #%00001010
eor #%10000000
```
...which puts #%10001010 (138 in decimal) in the A-reg but takes only 2 + 2 = 4 cycles, 
with the saving still applying over different addressing modes if you replace like with like and, 
as with the EOR subtraction, you walk out of the calculation with the carry flag unaffected!

*******************************************************
7. JUMP TABLES
Best for cycle efficiency
```asm
  ldx JumpEntry			//2  2
  lda PointerTableH,X	//4  3
  sta SMOD + 1			//4  3
  lda PointerTableL,X	//4  3
  sta SMOD + 0			//4  3
  jmp SMOD: $BEEF		//3  3
```
21 Cycles, 17 Bytes

Best for Bytes efficiency
The so-called RTS Trick is a method of implementing jump tables by pushing a subroutine's entry point to the stack.
```asm
  ldx JumpEntry			//2  2
  lda PointerTableH,X	//4  3
  pha					//3  1
  lda PointerTableL,X	//4  3
  pha					//4  1
  rts					//6  1
```
23 Cycles, 11 Bytes
NOTE: Table low byte must be destination low byte - 1

*******************************************************
8. 16 BIT ROTATIONS
SHIFT LEFT
```asm
lda Hi Byte 
cmp #$80
rol Low Byte
rol
sta Hi Byte
```

SHIFT RIGHT
```asm
lda Low Byte
lsr
ror High Byte
bcc !Skip+
ora #$80
!Skip:
sta Low Byte
```

*******************************************************
9. SUBTRACT A FROM BYTE
a = (Address) - a
```asm
sec
eor #$ff
adc Address
```

Add or subtract from a byte based on carry (set = subtract, clear = add)
```asm
bcc !add+
eor #$ff
!add:
adc Address
```

*******************************************************
10. COMPARE 2 16 BIT NUMBERS
x = lo, a = hi
```asm
cpx #<compare 	// C is set if x >= <compare
sbc #>compare 	// takes low byte compare into account if equal
				// C is set if number is greater or equal to compare
```
or
```asm
lda addr0
cmp addr1
lda addr0+1
sbc addr1+1
bcc addr1IsBigger
bne addr0IsBigger
// else equal...
```

*******************************************************
11. COUNTING BITS
As we are on a 8 bit machine, counting from or to 8 occurs quite often. So why not counting bits?
```asm
//setup counter
lda #$80	       // (2)
sta $02	           // (3)
!Loop:
//do stuff that best use A, X and Y
lsr $02	          // (5)
bcc !Loop-	      // (3/2)
//restore counter
ror $02	          // (5)
```

This gets even cooler when you are able to use $02 as some bitmask (for e.g. when drawing lines). 
When using BMI/BPL or BVS/BVC (need then to test bits with BIT however) you might even count to 1, 2, 6 or 7.

*******************************************************
12. CHECK A FOR A RANGE (eg 10,100)
```asm
sec
sbc #10  	// start of the range
cmp #90  	// length of the range
bcs fail 	// result needs to be 0-89 to pass the original 10-99 check
			// A is in range here, and Carry is clear

			// Alternative but A is destroyed.  Start Value n, End value m
clc			// clear carry for add
adc	#$FF-m	// make m = $FF
adc	#m-n+1	// carry set if in range n to m
```

*******************************************************
13. SET/UNSET OR FLIP A BIT
```asm
INVPOT:
    .byte 255-1,255-2,255-4,255-8,255-16,255-32,255-64,255-128
POT:
    .byte 1,2,4,8,16,32,64,128

ldx #$03
lda MEMORYTOFLIP
and INVPOT, x   //set bit to 0
sta MEMORYTOFLIP

ldx #$07
lda MEMORYTOFLIP
ora POT, x   //set bit to 1
sta MEMORYTOFLIP
```
To flip a bit, use eor instead of ora

*******************************************************
14. SWAP NYBBLES
```asm
lda Value
asl
adc #$80
rol
asl
adc #$80
rol
```
A = swapped nybbles

C	Value		Code
x	11110000	Start
1	11100000	asl
1	11100001	adc #$80
0	11000011	rol
1	10000110	asl
1	10000111	adc #$80
0	00001111	rol

*******************************************************
15. 16-Bit increment or decrement - two ways
Example 1
```asm
lda SpriteX
clc
adc #Value
sta SpriteX
lda #Value
and #$80
beq !+
lda #$FF
!:
adc SpriteXMSB
sta SpriteXMSB
```
21-24 cycles (ZP), 25/28 cycles (Address)

Example 2
if "Value" was signed then you could do...  
```asm
clc
lda #Value
bpl !+
dec SpriteXMSB
!:  
adc SpriteX
sta SpriteX
bcc !+
inc SpriteXMSB
!:
```

Example 3
Decrement 16 bit by 1
```asm
lda #$FF
dcm lsb
bne !Skip+
dec msb
!Skip:
```
10/12 cycles (ZP),  11/13 cycles (Address)

Example 4
Increment 16 bit by 1
```asm
inc lsb
bne !Skip+
inc msb
!Skip:
```
8/12 cycles (ZP), 9/13 Cycles (Address)

*******************************************************
16. ODDS/EVENS
```asm
lda #number
lsr
bcc !Even+
!Odd:			// Will be an odd number
// Do stuff

!Even:			// Will be an even number
// Do Stuff
```

*******************************************************
17. CARRY BIT TOGGLE
Toggle carry – flip the carry bit.
Carry bit wrong? Want a 0 when it’s 1?
```asm
lda #$00
rol			// Cb into b0
eor	#$01	// toggle bit
ror			// b0 into Cb
```

*******************************************************
18. SNAPPING A SPRITE TO A CHAR POSITION
Due to sprites starting off screen at 0,0, when the sprite appears on screen at 24,50, 
the sprite Y value is 2 pixels out of alignment with the char positions.  To correct and snap
the sprite to the top of the car, use the following:
```asm
lda SpriteYPos
sec
sbc #$06
and #%11111000        // Rounds to nearest 8 (F8)
ora #%00000110        // Add on 6 again
sta SpriteYPos
```

*******************************************************
19. Generating a random positive or negative value
Sometimes you need to pick a positive (01) or a negative (ff) value

```asm
jsr Random           // Pick a random value 0 to 255 - separate sub-routine
and #%00000001       // Make it 0 or 1
asl                  // Make it 0 or 2
clc
adc #$FF             // Make it $FF or $01
```
or

```asm
jsr Random
and #%00000001
lsr
ror                  // Make it $80 or $00
```

20. Determine overlapping objects
Useful for a collision detection routine.

```asm
clc                    // Start with carry clear
lda xpos1
sbc xpos2              // Note will subtract n-1
sbc #SIZE2 - 1
adc #SIZE1 + SIZE2 - 1 // Carry set if overlap
```

21. Flip a Byte
Flip the value of a byte based on the carry flag

Carry Clear: 2's complement x = x ^ $FF + 1
```asm
eor #$FF
adc #01
```

Carry Set: 2's complement x = x - 1 ^ $FF
```asm
sbc #$01
eor #$FF
```

22. Divide by 100
Divide a 16 bit number by 100.  A = Remainder

```asm
ldy #16 // 16 bits
lda #00
clc
!Loop:
rol
cmp #100
bcc !skip+
sbc #100
!Skip:
rol temp + 0 // 16 bit value held in temp
rol temp + 1
dey
bpl !Loop-
```
