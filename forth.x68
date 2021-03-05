* lisa-fig68k -- an adaptation of a fig-Forth for the Apple Lisa.
*
* This file contains the start-up code that prepares the Lisa for invoking the
* Forth interpreter in F68K.ASM, as well as the Lisa-specific I/O routines that
* the F86K.ASM calls to talk to the real world. Further details of what this
* code does can be found inline in the comments, with some summary information
* in README.md as well.
*
* In an abbreviated sense, this code serves as glue between the 68000 fig-Forth
* interpreter by Peter Nooy, Arie Kattenberg, Albert van der Horst and
* ultimately Kenneth Mantei, from
* https://home.hccnet.nl/a.w.m.van.der.horst/forthimpl.html , and the screen,
* keyboard, and hard drive I/O routines from the lisa_io library at
* https://github.com/stepleton/lisa_io .
*
* As written, this code requires that it be loaded into memory by the
* "bootloader_hd" bootloader at https://github.com/stepleton/bootloader_hd .
* This is because the bootloader leaves a copy of the lisa_io ProFile I/O
* library resident in memory, and the I/O routines here make use of it. It
* saves us one disk block to do it this way.
*
* Comments in this code make casual mention of "low-memory" and "high-memory".
* The former refers to the memory region $800..$9FF, which sits between the
* Lisa boot ROM's scratch memory space and the fig68k disk buffer; the latter
* refers to the memory at and above $10000. The fig68k interpreter generally
* does not make use of either region: the former seems to have been set aside
* by the interpreter's designers in case a particular computer liked to map a
* ROM there; the latter can't be addressed by the interpreter at all as only
* 16-bit addresses are used. This file places its startup code in the
* low-memory region ($800 is its entry point) alongside the machine-specific
* I/OO routines and some smaller data items and scratch space; meanwhile,
* various I/O routines and larger data items occupy the high-memory region.
*
* ----------
*
* This is free and unencumbered software released into the public domain.
* 
* Anyone is free to copy, modify, publish, use, compile, sell, or
* distribute this software, either in source code form or as a compiled
* binary, for any purpose, commercial or non-commercial, and by any
* means.
*
* In jurisdictions that recognize copyright laws, the author or authors
* of this software dedicate any and all copyright interest in the
* software to the public domain. We make this dedication for the benefit
* of the public at large and to the detriment of our heirs and
* successors. We intend this dedication to be an overt act of
* relinquishment in perpetuity of all present and future rights to this
* software under copyright law.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
* EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
* MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
* IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR
* OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
* ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
* OTHER DEALINGS IN THE SOFTWARE.
*
* For more information, please refer to <http://unlicense.org>
*
* ----------
*
* Changelog:
*
* 2021/05/03: Initial release. Tom Stepleton <stepleton@gmail.com>, London


* Equates ---------------------------------------


kSecCode	EQU 0		; For executable code
kSecData	EQU 1		; For immutable data (e.g. many strings)
kSecScratch	EQU 2		; For mutable temporary storage
kSecBuffer	EQU 3		; More mutable temporary storage


	; Lisa and lisa_io-specific replacement equates for values in F68K.ASM
	; Note how the most memory we can use for the interpreter is 32K ---
	; that's because bounds-checking inside the interpreter uses signed
	; 32-bit arithmetic :grimace:
BSIN		EQU $08		; Our backspace key generates $08
EM		EQU $7FFE	; As big as usable RAM gets on our 1 MiB machine
KBBUF		EQU $200	; Our disk buffers are 512 bytes, not 256


* Main program ----------------------------------


	ORG	$800
	; First, clear some local values and save pointers to useful
	; routines handed to us by the "stepleton_hd" bootloader
MAIN	LEA.L	zBreakDown(PC),A4
	CLR.W	(A4)+		; Clear zBreakDown flag
	CLR.W	(A4)		; Number of free disk blocks is 0 at first
	MOVEM.L	A0-A3,(A4)	; Save ProFile I/O routine pointers

	; After this program is loaded into RAM, a portion that needs to be
	; located at kHiMemStart is sitting at INITDP, so we need to move it
	; (Explanation: even though this program was assembled with the "high
	; memory" data in the right place, the post-assembly steps that prepare
	; the binary moves the high memory stuff lower in the memory image, so
	; we don't waste loading time and disk space on a lot of 0 bytes)
	LEA.L	INITDP(PC),A0	; Point A0 at the stuff we need to move
	LEA.L	kHiMemStart,A1	; Point A1 at the place where we need to move it
	LEA.L	(kHiMemEnd-kHiMemStart,A1),A2	; Point A2 at the loading endpt.
.ll	MOVE.W	(A0)+,(A1)+	; Copy a word
	CMPA.L	A2,A1		; Are we done?
	BLO.S	.ll		; No, copy another

	; We now need to figure out the size of the ProFile, if we have one for
	; disk I/O, so begin by loading the Widget drive ID block into the
	MOVE.L	#$FFFFFF00,D1	; "Read block FFFFFF"
	MOVE.W	#$0A03,D2	; Retry count and sparing threshold
	LEA.L	zBlock(PC),A0	; Load the data here
	MOVE.L	zProFileIoPtr(PC),A1	; Point A1 at the ProFile I/O routine
	JSR	(A1)		; And execute the routine
	BNE.S	.ok		; On failure, jump ahead to skip drive sizing

	; Now we copy the ProFile's 3-byte block count locally for analysis, and
	; for copying into zProFileNumFreeBlocks; note that A0 points just past
	; the end of the loaded block
	LEA.L	$10(A4),A4	; Advance A4 to zProFileNumFreeBlocks
	MOVE.W	#$FFFF,(A4)	; zProFileNumFreeBlocks is $FFFF by default
	MOVE.L	-514(A0),D0	; Copy size plus one extra byte into D0
	LSR.L	#$8,D0		; Shift the extra byte off
	SWAP.W	D0		; Swap MSWord and LSWord
	TST.W	D0		; Any bits at all in the (old) LSWord? If so...
	BNE.S	.fb		; ...disk is > what we can address, skip ahead
	SWAP.W	D0		; Restore original word ordering in D0
	MOVE.W	D0,(A4)		; Save number of disk blocks
	BEQ.S	.ok		; If it was 0 (some error?) skip ahead

	; We're now going to find out how many drive blocks we can use without
	; clobbering the Forth interpreter resident on the drive, and that means
	; loading each block counting up from $000000 until we find a block
	; whose tag contains $00000000 at bytes $04..$07, which marks the first
	; block available to the user
.fb	LEA.L	$2(A4),A3	; Point A3 at the first free block variable
	CLR.L	D1		; "Read block 000000"
   	LEA.L	zBlock(PC),A0	; Load the data here
.fl	JSR	(A1)		; Read the block
	LEA.L	zBlock(PC),A0	; Rewind A0 to the start of the block
	TST.L	4(A0)		; Are the second four tag bytes $00000000?
	BEQ.S	.ok		; If so, it's the first free block! We're done
	ADDQ.W	#$1,(A3)	; No, maybe it's the next block
	SUBQ.W	#$1,(A4)	; Decrement the number of free blocks
	BEQ.S	.ok		; If no free blocks, skip ahead
	ADDI.L  #$100,D1	; Otherwise, set up D1 to read the next block
	BRA.S	.fl		; And go read it

	; Warning text is loaded from a disk and stored in RAM, so we can always
	; have WARNING set to 1
.ok	ADDQ.W	#$1,COLDUS+$E	; Forth can get error messages from the disk

	; I found the white-on-black text of UniPlus UNIX to be really striking,
	; so let's replicate it here --- also, fig-Forth can't really do
	; characters outside of $00..$7F, so in Jupiter Ace fashion, let's have
	; the $80..$FF characters be inverted (or really un-inverted) copies of
	; their counterparts 128-characters below
	LEA.L	fontLisaConsole,A0
	LEA.L	(9*128,A0),A1
	MOVE.W	#$11F,D0
.il	MOVE.L	(A0),(A1)+
	NOT.L	(A0)+
	DBRA	D0,.il

	; Initialise library components for screen and keyboard/mouse I/O
	JSR	InitLisaConsoleKbMouse
	JSR	InitLisaConsoleScreen

	; Clear the screen -- we can't use ClearLisaConsoleScreen, since we need
	; to turn the screen dark, not light, so use XHOME instead
	BSR	XHOME

	; Now jump into the interpreter at last!
	BRA	MCOLD


* Hardware-specific routines --------------------


	; XRSLW -- Low-level drive I/O
	; Args:
	;   A3+$0: w. $0000 means write, other values mean read
	;   A3+$2: w. Which block to read or write
	;   A3+$4: w. 16-bit address in $0000..$7FFF receiving the block data
	;       (if a read) or transmitting the block data (if a write)
	; Notes:
	;   Blocks $6..$B are read from RAM (see kBlock6 and onward); writes to
	;       these have no effect
	;   On the physical media, block $5 is followed by block $C
	;   Much of the remaining bulk of this function comes from dealing with
	;       the 20-byte tag that prepends the 512 bytes of block data that
	;       we actually use --- we do our best to pretend that the tag data
	;       doesn't exist
	;   This code assumes that A3+$2 will never be less than $1000
	;   It's also assumed that A3+$2 values will never be $1001..$1013
	;   Trips an error #6 if the block to read is out of bounds
	;   For nominal returns, increments (pops) A3 by 6 bytes
	;   Trashes D0-D3/A0-A1/A3 (and A5 on errors), also zBlockTag, and for
	;       reads wherever A3+$2 was pointing
XRSLW	CLR.L	D1		; Clear D1 high word, for much later
	MOVE.W	$2(A3),D1	; Load the block to read into D1
	CMPI.W	#$6,D1		; Is the block less than 6?
	BLO.S	.va		; If so, go straight on to process it
	SUBQ.W	#$6,D1		; If not, subtract 6 from the block ID
	CMPI.W	#$6,D1		; Is the block still less than 6?
	BHS.S	.va		; No; we have to read from a real disk

	; If here, we're dealing with our read-only blocks in RAM
	TST.W	(A3)		; Does the user want to write?
	BEQ.S	.rt		; If yes, then too bad; silently do nothing
	LSL.W	#$8,D1		; Multiply block ID by 512, part 1
	LSL.W	#$1,D1		; Multiply block ID by 512, part 2
	LEA.L	kBlock6,A0	; Point A0 at the blocks in RAM
	ADDA.L	D1,A0		; Point A0 at the block we want to read
	MOVEA.W	$4(A3),A1	; Point A1 at the copy destination
	MOVE.W	#$1FF,D0	; Get ready to copy 512 bytes
.ml	MOVE.B	(A0)+,(A1)+	; Copy a byte
	DBRA	D0,.ml		; Loop to the next byte
	BRA.S	.rt		; Jump ahead to return

	; Check whether the block is valid
.va	LEA.L	zProFileNumFreeBlocks(PC),A0	; Point A0 at num. free blocks
	MOVE.W	(A0),D0		; And load that value into D0
	CMP.W	D1,D0		; Is the specified block valid?
	BHI.S	.ok		; Yes, move ahead
	MOVEQ.L	#$6,D3		; Otherwise, load error word 6 into D3
	BRA.S	.er		; Go report an error

	; Save and blank out the tag data that precedes the block to read/write
.ok	MOVEA.W	$4(A3),A0	; Point A0 at the specified block address
	LEA.L	zBlockData(PC),A1	; Point A1 just beyond the block tag
	MOVEQ.L	#$13,D0		; We want to copy 20 bytes
.bl	MOVE.B	-(A0),-(A1)	; Copy a byte
	CLR.B	(A0)		; Blank it out at the source
	DBRA	D0,.bl		; Loop for the next longword

	; Now to actually do the I/O --- note that A0 is already set up to go
	ADD.W	zProFileFirstFreeBlock(PC),D1	; Offset D1 by first free block
	LSL.L	#$8,D1		; Shift result into proper place for ProFileIo
	TST.W	(A3)		; Are we reading or writing?
	SEQ.B	D1		; If writing, set D1 LSWord to $FF
	NEG.B	D1		; Now read is $00, write is $01, as it should be
	MOVE.W	#$0A03,D2	; Set retry count and sparing threshold
	MOVE.L	zProFileIoPtr(PC),A1	; Point A1 at the ProFile I/O routine
	JSR	(A1)		; Call the ProFile I/O routine
	SNE.B	D3		; Set D3 to $00 on success, $FF on failure
	ANDI.W	#$8,D3		; D3 is now $0000 on success, $0008 on failure

	; Restore the tag data that we cached at zBlockTag
	MOVEA.W	$4(A3),A0	; Point A0 at the specified block address
	LEA.L	zBlockData(PC),A1	; Point A1 just beyond the block tag
	MOVEQ.L	#$13,D0		; We want to copy 20 bytes
.rl	MOVE.B	-(A1),-(A0)	; Copy a byte
	DBRA	D0,.rl		; Loop for the next longword

	; Finishing up and returning to the caller
	TST.W	D3		; Did we encounter any errors?
	BNE.S	.er		; If so, go report them
.rt	ADDQ.W	#$6,A3		; Pop all our args off the Forth data stack
	RTS

	; For reporting errors: place an error word in D3 and jump here
.er	ADDQ.W	#$4,A3		; Pop off (most of the) stack args
	MOVE.W	D3,(A3)		; Push the error word onto the stack
	ADDQ.L	#$4,SP		; Pop our normal return address off the stack
	MOVEA.W	#ERROR,A5	; Point A5 at the ERROR code field
	MOVEA.W	(A5)+,A0	; Advance A5 to ERROR params
	JMP	(A0)		; Jump to run ERROR


	; XCR -- Move the cursor to column 0 of the next row
	; Args:
	;   (none)
	; Notes:
	;   One of the hardware-specific routines that we need to implement for
	;       the fig-Forth interpreter
	;   Simply falls through into XEMIT with a newline character in D0
	;   Trashes D0-D2/A0-A2
XCR	MOVEQ.L	#$0A,D0		; Load a \n into D0


	; XEMIT -- Display a character on the screen
	; Args:
	;   D0: Character to display; can also be $07, meaning beep; $08,
	;       meaning backspace; or $0A, meaning newline
	; Notes:
	;   One of the hardware-specific routines that we need to implement for
	;       the fig-Forth interpreter
	;   Backspacing at the beginning of a row places the cursor at the end
	;       of the previous row and does not take into account where the
	;	end of the text on the previous row appears
	;   Audible beep is accompanied by a visual flash
	;   Contains a shameful kludge to preserve white-on-black text after
	;       printing a newline
	;   Trashes D0-D2/A0-A2
XEMIT	CMPI.B	#BSOUT,D0	; Are we trying to backspace over a character?
	BEQ.S	.bs		; If so, that's handled below; otherwise...
	CMPI.B	#BELL,D0	; ...are we trying to ding the bell?
	BEQ.S	.di		; That's a bit further below; otherwise...
	LEA.L	.st(PC),A0	; ...point A0 at the pre-terminated string
	MOVE.B	D0,(A0)		; Deposit the character there
	MOVE.L  A3,D3		; Save Forth SP in D3, since we'll smash it
	JSR	PrintLisaConsole	; Print the single-character string
	MOVEA.L	D3,A3		; Restore Forth SP from D3

	; An ugly post-hoc kludge for the sake of white-on-black text: did we
	; just print a newline? Then the bottom line of text will be white,
	; and so now we paint it black, which causes an annoying flicker, but
	; maybe it makes things look more retro-janky, and that's fun?
	MOVE.B	.st(PC),D0	; Retrieve the printed character into D0
	CMPI.B	#LF,D0		; Was it a newline?
	BNE.S	.rt		; No, jump ahead to return
	MOVE.L	zLisaConsoleScreenBase,A0	; Yes, point A0 at the screen
	LEA.L	$7B0C(A0),A0	; Advance to the start of the new white row
	MOVEQ.L	#-1,D0		; Get ready to write lots of 1s
	MOVE.W	#$E0,D1		; Loop counter
.lp	MOVE.L	D0,(A0)+	; Black out another 32 pixels
	DBRA	D1,.lp		; Loop to black out more
.rt	RTS

.st	DC.B	$00,$00		; A pre-terminated single-character string

	; This portion of XEMIT handles the backspace character
.bs	LEA.L	2+zRowLisaConsole,A2	; Point A2 just past screen pos. vars
	MOVE.W	-(A2),D2	; Load row into D2
	MOVE.W	-(A2),D1	; Load column into D1
	BEQ.S	.br		; If column was 0, go do row-decrementing
	SUBQ.W	#$1,D1		; Otherwise move the cursor back one column
	BRA.S	.ro		; And jump to do the rubout
.br	TST.W	D2		; Is the row 0?
	BEQ.S	.ro		; If so, we can't go back any further
	SUBQ.W	#$1,D2		; Otherwise, move the cursor back one row
	MOVEQ.L	#$59,D1		; And to the rightmost column

.ro	MOVEM.W	D1-D2,(A2)	; Update the screen positions in memory
	MOVEQ.L	#$20,D0		; Prepare to place a blank character
	JMP	PutcLisaConsole		; Returns to the caller

	; This portion of XEMIT flashes the screen and also uses the ROM to make
	; a beep for us
.di	MOVE.W	SR,-(SP)	; Save SR on the stack
	ORI.W	#$0700,SR	; Now disable interrupts
	MOVEA.L	zLisaConsoleScreenBase,A0	; Point A0 at the screen
	MOVE.W	#$3FFB,D0	; We have to invert $3FFC words
.d1	NOT.W	(A0)+		; Invert the next word
	DBRA	D0,.d1		; And go loop again
	MOVEQ.L	#$20,D0		; Higher-pitch beep
	MOVEQ.L	#$40,D1		; About 1/32 of a second long
	MOVEQ.L	#$2,D2		; And pretty quiet, too
	JSR	$FE00B8		; Go beep!
	MOVE.W	#$3FFB,D0	; We have to un-invert $3FFC words
.d2	NOT.W	-(A0)		; Un-invert the preceding word
	DBRA	D0,.d2		; And go loop again
	MOVE.W	(SP)+,SR	; Restore interrupts
	RTS


	; This routine empties the COPS and then retrieves a key from the user,
	; blinking a cursor character as it awaits input
XKEY	BSR.S	FlushCops	; Flush the COPS
	MOVE.W	#$205F,D5	; D5: Blinking cursor glyphs: one must be $20!
.lp	MOVE.W	#$BFFF,D2	; Delay for LisaConsoleDelayForKbMouse
	JSR	LisaConsoleDelayForKbMouse	; Await new COPS bytes
	BEQ.S	.kp		; If a proper keypress, jump to handle it

	; If here, the user typed nothing and it's time to blink the cursor
	BSR.S	.bl		; Go blink the cursor
	BRA.S	.lp		; Jump to try and get a key again

	; If here, the user did a keypress, so we need to deal with it
.kp	MOVE.B	zLisaConsoleKbChar,D3	; Load the character into D3
	CMPI.B	#$1B,D3		; Was it the Clear key?
	BEQ.S	.lp		; If so, ignore and get another key
	MOVE.W	#$2020,D5	; Force the cursor to "unblink"
	BSR.S	.bl		; And unblink it
	CLR.W	D0		; Set D0 word to 0
	MOVE.B	D3,D0		; Copy typed character into LSByte
	ANDI.B	#$7F,D0		; ASCII-only, I'm afraid
	CMPI.B	#LF,D0		; Did the user press the Return (\n) key?
	BNE.S	.rt		; No, jump ahead to return
	MOVEQ.L	#ACR,D0		; Yes, make it \r for the interpreter
.rt	RTS

	; Helper: blink the cursor
.bl	CLR.W	D0		; Clear glyph-to-print argument
	MOVE.B	D5,D0		; Now copy glyph to print into D0
	MOVE.W	zColLisaConsole,D1	; The printing column to D1
	MOVE.W	zRowLisaConsole,D2	; The printing row to D1
	ROR.W	#$8,D5		; Set up next glyph-to-print
	JMP	PutcLisaConsole		; Returns to the caller
	

	; XQTERM -- Check and clear the "break key pressed" flag
	; Args:
	;   (None)
	; Notes:
	;   One of the hardware-specific routines that we need to implement for
	;       the fig-Forth interpreter
	;   If zBreakDown is set, then this routine loops calling FlushCops
	;	until zBreakDown is clear, then it returns with $0001 in D0
	;   Otherwise it returns with D0 cleared
	;   Trashes D0-D1/A0-A2
XQTERM	BSR.S	FlushCops	; Flush the COPS and set up A2->zBreakDown
	MOVE.W	(A2),D0		; Copy zBreakDown contents to D0
	BEQ.S	.rt		; Jump to exit if it is $0000
.lp	BSR.S	FlushCops	; Flush the COPS again, await zBreakDown == 0
	TST.W	(A2)		; Is it 0 yet?
	BNE.S	.lp		; If not, keep looping
	MOVE.W	#$1,D0		; Mark the break key as pressed prior to return
.rt	RTS


	; XHOME -- Clear the screen and move the cursor to 0,0
	; Args
	;   (None)
	; Notes:
	;   Trashes D0-D1/A0
XHOME	MOVE.L	zLisaConsoleScreenBase,A0	; Point A0 at video memory
	MOVE.W	#$1FFD,D0	; Loop 8190 times
	MOVEQ.L #-1,D1		; We're gonna write a lot of 1s now
.cl	MOVE.L	D1,(A0)+	; One longword at a time
	DBRA	D0,.cl		; Loop to the next longword
	CLR.L	zColLisaConsole		; Set output row/column to 0
	RTS


* Local helper functions ------------------------


	; FlushCops -- Process pending COPS bytes
	; Args:
	;   (none)
	; Notes:
	;   Sets the zBreakDown variable if it detects that the Clear key has
	;       been depressed; clears zBreakDown if it detects that the Clear
	;       key has been released
	;   A2 will point to zBreakDown on return
	;   Trashes D0-D1/A0-A2
FlushCops:
	LEA.L	zBreakDown(PC),A2	; Point A2 at the zBreakDown flag
.lp	JSR	LisaConsolePollKbMouse	; Poll the COPS
	BCS.S	.rb		; Read a byte? Go process it
	RTS			; No byte period, return to caller

.rb	ROXR.W	#$1,D0		; Was X set? If so, then...
	BMI.S	.lp		; ...we need to go get another COPS byte now

	LEA.L	zLisaConsoleKbCode,A0	; Point A0 at the saved keycode
	CMPI.B	#$A0,(A0)	; Did user press the Clear key?
	BNE.S	.bu		; No, see if they released it
	MOVE.W	#$1,(A2)	; Yes, set the zBreakDown flag
        BRA.S   .lp		; And go poll the COPS again

.bu	CMPI.B	#$20,(A0)	; User released the Clear key?
	BNE.S	.lp		; No, go poll the COPS again
	MOVE.W	#$0,(A2)	; Yes, clear the zBreakDown flag
        BRA.S   .lp		; And go poll the COPS again


* Low-memory scratch space ----------------------


	; In processing user key input, we set this flag if we discover that
	; the user is holding down the Clear key
	; Also not in kSecScratch for PC-relative convenience, and it's
	; also important that this come right before zProFileIoSetupPtr!
zBreakDown:
	DC.W	$0000		; This is really just a 1-bit flag


	; Pointers to ProFile I/O library data and routines; these are not in
	; kSecScratch so that we can use PC-relative addressing, although
	; there's not a whole lot of demand for that, really
	; Ordering of these values is important!
zProFileIoSetupPtr:
	DC.L	'I/O '		; Points to: I/O data structure setup routine
zProFileIoInitPtr:
	DC.L	'lib '		; Points to: I/O port initialisation routine
zProFileIoPtr:
	DC.L	'poin'		; Points to: block read/write routine
zProFileErrCodePtr:
	DC.L	'ters'		; Points to: error code byte


zProFileNumFreeBlocks:		; How many free blocks does our ProFile have?
	DC.W	$0000		; Note that we will max out at $FFFF blocks
zProFileFirstFreeBlock:
	DC.W	$0000		; Which block is the first we can write to?


* Disk buffer -----------------------------------


	; $1000 - 20 is temporary storage for drive tags; we put some text here
	; so that the assembler will warn us if we smash it
	ORG	$FEC
zBlock:
zBlockTag:
	DC.B	'[Where the tags go!]'

	; $1000 marks the start of the disk buffer; we put some text here so
	; that the assembler will warn us if we smash it
	ORG	$1000
zBlockData:
	DC.B	'[This is the start of the disk buffer]'


* High-memory fixed program data ----------------


	; As fig-Forth can use only 32 KiB of RAM, the remainder of memory is a
	; fine place to keep other things. We will place font data here first.
	ORG	$8000
kHiMemStart	EQU *		; A symbol indicating where high memory begins

kSecD_Start	EQU *		; This gimmick means that kSecData will start...
	SECTION kSecData	; ...just after the code/data that immediately...
	ORG	kSecD_Start	; ...precedes it

	; Font data will be placed first in this "data section" of "high memory"
	INCLUDE	lisa_io/font_Lisa_Console.x68

	; Now include the raw "disk" data for screens 3, 4, and 5
	INCLUDE screens.x68


* High-memory scratch space ---------------------


	; Scratch data will come next.
	DS.W	0		; Force word alignment
kSecS_Start	EQU *+$300	; 'kbmouse requires this much additional room
 	SECTION kSecScratch
	ORG	kSecS_Start


        ; This next section will contain... code
kSecC_Start	EQU *+$100	; Allocates this much scratch space before it
	SECTION	kSecCode
	ORG	kSecC_Start


* High-memory includes --------------------------


	; Invocation of the defineLisaConsole will execute macros in the
	; lisa_console_screen display library that place data in the kSecCode
	; and kSecScratch sections
	; (Being naughty, we first replace one of the internal macros that gives
	; us vertical padding between lines, making this padding black)
_mVPad8     MACRO
              IFGT (\1-\2)
      ST.B    (\3)                   ; Clear row of the on-screen glyph copy
      ADDA.W  \4,\3                  ; Advance to the next row
              ENDC
            ENDM
	; With that dirty business done, we can execute the macros that define
	; the text display library
 	INCLUDE	lisa_io/lisa_console_screen.x68
 	defineLisaConsole


	; The lisa_console_kbmouse library places data in the kSecCode, kSecData,
	; and kSecScratch sections
	INCLUDE	lisa_io/lisa_console_kbmouse.x68


	SECTION	kSecCode
kHiMemEnd	EQU *		; A symbol indicating the end of high memory


* The interpreter itself! -----------------------


	; The F68K.ASM library places code in various locations starting at
	; $1000 and remaining below $10000, so the kSec* sections are not
	; involved
	INCLUDE	F68K.ASM
