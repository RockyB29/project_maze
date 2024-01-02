#----------------------------------------------------------------------------------------------
# Project Maze
# creator: Rocky Chen
# Education: University of Alberta
# credit: University of Alberta cmput229 course for helper functions of parsing files' contents in RISC-V
# For the proceeding code (functions "handlerTerminate", "printStr", "printChar"
# and "waitForDisplayReady"):
# Copyright 2020 University of Alberta
# Copyright 2022 Dhanrajbir Singh Hira
# Copyright 2018 Zachary Selk
#----------------------------------------------------------------------------------------------

.data

.align 2
DISPLAY_CONTROL:	.word 0xFFFF0008
DISPLAY_DATA:		.word 0xFFFF000C
INTERRUPT_ERROR:	.asciz "Error: Unhandled interrupt with exception code: "
INSTRUCTION_ERROR:	.asciz "\n   Originating from the instruction at address: "
START_STR:		.asciz "Please enter 1, 2, or 3 to choose the difficulty of the game(70, 50 and 30 seconds): "
ERASER:			.asciz "                                                                                     "
TIME_INFO:		.asciz "Time remaining: "
KEY_CONTROL: 		.word 0xFFFF0000
KEY_DATA: 		.word 0xFFFF0004
TIME:			.word 0xFFFF0018
TIMECMP:		.word 0xFFFF0020
TIME_LEFT:		.word 0x00000000
GAME_ENDED:		.word 0x00000000
KEYINPUT:		.word 0x00000000


iTrapData:    .space     256
        .align     2
rawInputBuffer:    .space     4096
wallInfoArray:    .space     16384
mazeBuffer:    .space    16384


fileOpenErrStr:    .asciz "Unable to open file\n"
invalidFileContentsStr: .asciz "Invalid file."

# Draw distance of the player
DRAW_DIS_X:        .word    0x0
DRAW_DIS_Y:        .word    0x0

# Player's position
PLAYER_X_POS:        .word    0x0
PLAYER_Y_POS:        .word    0x0

# Co-ordinates of the finish point
FINISH_POINT_X:        .word    0x00
FINISH_POINT_Y:        .word    0x00

# ASCII values for the various characters displayed throughout the game.
WALL_CHARACTER:        .word    0x40
SPACE_CHARACTER:    .word    0x20
PLAYER_CHARACTER:    .word    0x41
FINISH_POINT_CHARACTER:    .word    0x47
W_ASCII:        .word    0x77
A_ASCII:        .word    0x61
D_ASCII:        .word    0x64
S_ASCII:        .word    0x73

test_wall:
    .word 0
    .word 5
    .word 4
    .word 5
test_mazeBuffer:    .space    16384
test_maze:
    .word 0x00
    .word 0x00
    .word 0x00
    .word 0x00
    .word 0x00
    .word 0x00
    .word 0x00
    .word 0x01010000
    .word 0x00010101
    .word 0x00
    .word 0x00
    .word 0x00

.text
main:       
    add s0,a1,zero	# save the address of the input file name
	
    #------------------------------
    # Load the contents of the given file into rawInputBuffer.
    lw    a0, 0(s0)        # Load the filename string into a0.
    li    a1, 0            # Open the file in read only mode.
    li    a7, 1024        # Open the file.
    ecall                # a0 now holds the file descriptor or -1 if an error occured.
    
    blez    a0, fileOpenError    # Check that we were successfully able to open the file.
    la    a1, rawInputBuffer    # Load the address of the read buffer.
    li    a2, 1024        # Max number of bytes to read.
    li    a7, 63            # Read the file.
    ecall
    
    mv    a2, a0
    la    a0, rawInputBuffer
    la    a1, wallInfoArray
    
    jal     parseWallInfo
    
    la    t0, iTrapData        # t0 <- Addr[iTrapData]
    csrw    t0, 0x040        # CSR #64 (uscratch) <- Addr[iTrapData]
    
    mv    a1, a0
    la    a0, wallInfoArray
    
    lw    t0, 0(a0)        # Player start x co-ordinate.
    sw    t0, PLAYER_X_POS, t1
    
    lw    t0, 4(a0)        # Player start y co-ordinate.
    sw    t0, PLAYER_Y_POS, t1
    
    lw    a3, 8(a0)        # Max x co-ordinate of the maze.
    
    lw    a4, 12(a0)
    
    lw    t0, 16(a0)
    sw    t0, FINISH_POINT_X, t1
    
    lw    t0, 20(a0)
    sw    t0, FINISH_POINT_Y, t1
    
    lw    t0, 24(a0)
    sw    t0, DRAW_DIS_X, t1
    
    lw    t0, 28(a0)
    sw    t0, DRAW_DIS_Y, t1
    
    # Skip the first 8 integers as they do not correspond to walls.
    addi    a0, a0, 32
    addi    a1, a1, -8
    
    # If the number of integers corresponding to the walls is not a multiple of 4, then the file must be invalid.
    li    t0, 4
    rem    t0, a1, t0
    bnez    t0, invalidFileContent
    
    srli    a1, a1, 2        # Divide the number of integers parsed by 4 as each struct is represented by 4 integers.
    la    a2, mazeBuffer

    jal    maze
    j    exit

#----------------------------------------------------------------------------------------------
# parseWallInfo
# Parses the raw wall info read from the file and converts it into the format given in the spec
# Also handles the parsing of ascii characters into integers. The output buffer must be large
# enough to hold the parsed output.
#
# Inputs:
#    a0: The memory address of the buffer that has the raw input.
#    a1: The memory address of the buffer where to store the parsed output.
#    a2: The number of bytes in the raw input buffer.
#
# Returns:
#     a0: The number of integers in the parsed output.
#
# S-Registers:
#    s0: To save the memory address of the next byte to read from the raw input buffer.
#    s1: To save the memory address where the next integer should be written.
#    s2: End address of the input buffer.
#    s3: Number of integers in the parsed output.
#    s4: To save the ascii code for the comma character.
#    s5: To save the ascii code for the linefeed character.
#    s6: To save the ascii code for space (" ")
# other Registers
#    a0: To hold the intermediate form of the integer.
#     t1: To hold the byte loaded from the raw input that we are currently parsing.
#----------------------------------------------------------------------------------------------
parseWallInfo:
    # Save the required registers.
    addi     sp, sp, -32
    sw    s0, 0(sp)
    sw    s1, 4(sp)
    sw    s2, 8(sp)
    sw    s3, 12(sp)
    sw    s4, 16(sp)
    sw    s5, 20(sp)
    sw    s6, 24(sp)
    sw    ra, 28(sp)
    
    mv    s0, a0
    mv    s1, a1
    add    s2, a0, a2        # The end address of the input buffer.
    li    s3, 0            # The number of integers in the output.
    li    s4, 48            # ascii for comma ("0")
    li    s5, 57            # ascii for newline ("9")
    li    s6, 32            # ascii for space (" ")
    
    bge    s0, s2, parseLoopEnd
parseLoop:
    li    a0, 0
    lb    t1, 0(s0)
    blt    t1, s4, _parseReadWordLoopEnd
    bgt    t1, s5, _parseReadWordLoopEnd
        
_parseReadWordLoop:
    or    a0, a0, t1
    addi     s0, s0, 1
    bge    s0, s2, _parseReadWordLoopEnd
    lb    t1, 0(s0)
    blt    t1, s4, _parseReadWordLoopEnd
    bgt    t1, s5, _parseReadWordLoopEnd
    slli    a0, a0, 8
    j    _parseReadWordLoop

_parseReadWordLoopEnd:
    addi     s0, s0, 1
    beqz    a0, _skipWrite
    jal     strToInt
    sw    a0, 0(s1)
    addi    s1, s1, 4
    addi    s3, s3, 1
_skipWrite:
    blt    s0, s2, parseLoop

parseLoopEnd:
    # Move the number of integers in the output to the appropriate register.
    mv    a0, s3
    
    # Restore saved registers.
    lw    s0, 0(sp)
    lw    s1, 4(sp)
    lw    s2, 8(sp)
    lw    s3, 12(sp)
    lw    s4, 16(sp)
    lw    s5, 20(sp)
    lw    s6, 24(sp)
    lw    ra, 28(sp)
    addi    sp, sp, 32
    ret
    
#----------------------------------------------------------------------------------------------
# strToInt
# Parses an ascii string representing an interger into that integer. Note that instead of a
# string, this function takes in the bytes representing the integer stored in a register. As
# such only 4 digit numbers maybe parsed using this function.
#
# Inputs:
#    a0: The ascii representation of the number
#
# Returns:
#     a0: The parsed integer.
#----------------------------------------------------------------------------------------------
strToInt:
    li    a1, 0            # Used to store intermediate results.
    li    t0, 0            # Amount of bits to shift right.
    li    t1, 1            # Used to store the place value of our current digit.
    li    t2, 24            # Used to store the constant 24
    li    t3, 10            # Used to store the constant 10
    li    t4, 0xFF        # Bitmask to extract the lower 8 bits.

_strToIntLoop:
    srl    t6, a0, t0        # t6 <- a0 shifted by number of bits required to get the next 8 bits to the lower
                    # part of the register.
    and    t5, t6, t4        # t5 <- Lower 8 bits of t6
    beqz    t5, _strToIntLoopEnd    # No more ascii representation of digits to convert.
    addi    t5, t5, -48        # Adjustment for ascii to integer values.
    mul    t5, t5, t1        # Multiply the number we just parsed by its placeholder value in the number.
    add    a1, a1, t5        # Add the number we just parsed to our intermediate result.
    
    addi    t0, t0, 8        # Increment the number of shift to get the next ascii character.
    mul    t1, t1, t3        # Multiply our current placeholder value by 10 for the next iteration.
    ble    t0, t2, _strToIntLoop    # Ensures that we run the loop at most 4 times. An ascii character takes 1 byte and since a word is
                    # 4 bytes, we can have at most 4 characters in a register.

_strToIntLoopEnd:
    mv    a0, a1
    ret
    
invalidFileContent:
    la    a0, invalidFileContentsStr
    li    a7, 4
    ecall
    j    exit

fileOpenError:
    la    a0, fileOpenErrStr
    li    a7, 4
    ecall

exit:
    li    a7, 10
    ecall
    
printTestResult:
    addi sp, sp, -4
    sw ra, 0(sp)
    
    li a7, 4
    ecall
    
    lw ra, 0(sp)
    addi sp, sp, 4
    jr ra

#------------------------------------------------------------------------------
# equals
# This function checks if 2 arrays are entirely equal.
#
# Args:
#    a0: pointer to string 1
#   a1: pointer to string 2
#    a2: length of string 1
#   a3: counter for recursion
# Returns:
#   a0: 1 if both arrays are entirely equal, 0 if not.
#
# Register Usage:
#   t0: current character to compare from string 1
#   t1: current character to compare from string 2
#-----------------------------------------------------------------------------
equals:

    # load current character
    lw t0, 0(a0)
    lw t1, 0(a1)

    # check if it doesn't equal each other, fail
    bne t0, t1, equal_fail

    # check if we've reached the end of the string
    beq a3, a2, equal_pass

    # increment for next iteration
    addi a0, a0, 4
    addi a1, a1, 4
    addi a3, a3, 1
    # jump to next iteration
    j equals

    equal_fail:

        # return 0 for a fail
        li a0, 0

        ret

    equal_pass:

        # return 1 for a pass
        li a0, 1

        ret



.text
#------------------------------------------------------------------------------
# maze:
# Gameplay
#
# Arguments:
#	a0: pointer to the walls' array
#	a1: number of walls in the array
#	a2: pointer to an array that can be used to store the maze in-memory as a
#	    2D array. Guaranteed to be large enough to hold the maze
#	a3: the max x co-ordinate of the maze
#	a4: the max y co-ordinate of the maze
#
# S-Registers:
# s4: to store a0
# s5: to store a1
# s6: to store a2
# s8: to store a3
# s9: to store a4
# s7: to keep track of time
#------------------------------------------------------------------------------
maze:
	
	
# following function calling conventions
	addi sp, sp, -40
    	sw s7, 0(sp)
    	sw s1, 4(sp)
    	sw s2, 8(sp)
    	sw s3, 12(sp)
    	sw s4, 16(sp)
    	sw s5, 20(sp)
    	sw s6, 24(sp)
    	sw s8, 28(sp)
    	sw s9, 32(sp)
    	sw ra, 36(sp)
    	
    	add s4,zero,a0			# copy a0 into s4
    	add s5,zero,a1			# copy a1 into s5
    	add s8,zero,a3			# copy a3 into s8
    	add s9,zero,a4			# copy a4 into s9
    	
    	#build maze
    	jal ra, buildMaze
    	
    	add s6,zero,a2			# copy a2 into s6
	
	la a0,START_STR			# call printStr function to print the START_STR: "Please enter 1, 2, or 3 to choose the level and start the game"
	li a1,0
	li a2,0
	jal ra, printStr
	
	li t0,0x01			# set t0 to 0x0000 0001 to do masking
	csrrw   t1, 0, t1		# swap between t1 and ustatus
	or t1,t1,t0			# set 1st bit of ustatus to 1
	csrrw   t1, 0, t1		# swap between the updated t1 and ustatus
	
	
	li t0,0x0110			# set t0 to 0x0000 0110 to do masking
	csrrw   t1, 0x04, t1		# swap between t1 and uie
	or t1,t1,t0			# set 4th and 8th bit of uie to 1
	csrrw   t1, 0x04, t1		# swap between the updated t1 and uie
	csrr t4,0x04
	
	la t0,handler			# load address of the handler to t0
	csrrw   t0, 5, t0		# swap between t0 and utvec
	
	li a0,0x31			# a0 <-- 0x31
	li a1, 0x32			# a1 <-- 0x32
	li a2, 0x33			# a2 <-- 0x33
	li t0,2				# t0 <-- 2
	
	lw t2, KEY_CONTROL		# t2 <-- &(keyboard control)
	lw t1, (t2)			# t1 <-- keyboard control
	or t1,t1,t0			# t1 <-- set 1st bit of keyboard control to 1
	sw t1,(t2)			# store t1 to keyboard control
	
			
	
validkey1:
	lw s3, KEYINPUT			# load KEYINPUT to s3
	beq s3, a0, level1		# if the input is '1', goto level1
	beq s3, a1, level2		# if the input is '2', goto level2
	beq s3, a2, level3		# if the input is '3', goto level3
	b validkey1			# check again if the key isn't any of them
	
	
level1:
	li s7, 70			# setup countdown to 60 seconds
	la t0, TIME_LEFT
	sw s7, (t0)			# store 60 to TIME_LEFT
	b gameplay			# goto gameplay
	
level2:
	li s7, 50			# setup countdown to 40 seconds
	la t0, TIME_LEFT
	sw s7, (t0)			# store 40 to TIME_LEFT
	b gameplay			# goto gameplay

level3:
	li s7, 30			# setup countdown to 20 seconds
	la t0, TIME_LEFT
	sw s7, (t0)			# store 20 to TIME_LEFT
	b gameplay			# goto gameplay

	
gameplay:
	#erase previous contents
	la a0,ERASER			# a0 <-- address of ERASER
	add a1,zero,zero		# row==0
	add a2,zero,zero		# col==0
	jal ra, printStr		# erase the previously printed content on first line
	
	la a0,TIME_INFO			# a0 <-- address of time_info
	addi a1,s9,2			# set a1(row number) to max_y+2
	add a2,zero,zero		# set a2(col number) to 0
	jal ra, printStr		# print the time_info
	
	lw t0,TIME			# t0 <-- address of time
	lw t1,(t0)			# t1 <-- current time
	addi t2,t1,1000			# t2 <-- current time + 1s
	lw t3,TIMECMP			# t3 <-- address of timecmp
	sw t2,(t3)			# store current time + 1s to timecmp
	
	

	
updategame:
	add a0,s8,zero			# a0 <-- max_x
	add a1,s9,zero			# a1 <-- max_y
	add a2,s6,zero			# a2 <-- pointer to 2D array
	jal ra, printMaze		# goto printMaze to print the current state of the maze
	
updatetime:
	lw s7,TIME_LEFT			# load the time left into s7
	add a0,s7,zero			# a0 <-- s7
	jal ra, intToStr		# convert s7 to string
	
	add s3,zero,a0			# s3 <-- a0
	addi a1,s9,2			# set a1(row number) to max_y+2
	addi a2,zero,16			# set a2(col number) to 16
	jal ra, printChar		# print the 1st time character
	
	srli a0,s3,8			# shift s3 2 bits to the right
	addi a1,s9,2			# set a1(row number) to max_y+1
	addi a2,zero,17			# set a2(col number) to 17
	jal ra, printChar		# print the 2nd time character
	
gameloop:
	lw t1,GAME_ENDED		# t1 <-- Game ended
	bnez t1,endgame			# if game ended=1, goto endgame
	
	lw t0, TIME_LEFT		# load the (possibly) new time left into t0
	bne t0, s7, updatetime		# goto updatetime if new time_left isn't equal to old time_left
	
	lw t2,W_ASCII
	lw t3,A_ASCII
	lw t4,D_ASCII
	lw t5,S_ASCII
validkey2:
	lw s3,KEYINPUT			# load the current key input into s3
	beq s3,t2,moveup		# moveup if w is pressed
	beq s3,t3,moveleft		# moveleft if a is pressed
	beq s3,t4,moveright		# moveright if d is pressed
	beq s3,t5,movedown		# movedown if s is pressed
	b updatetime			# check again
	
moveup:
	lw s1,PLAYER_X_POS
	lw s2,PLAYER_Y_POS
	addi s2,s2,-1			# a2=PLAYER_Y_POS-1
	b wallCheck
	
moveleft:
	lw s1,PLAYER_X_POS
	lw s2,PLAYER_Y_POS
	addi s1,s1,-1			# a1=PLAYER_X_POS-1
	b wallCheck

moveright:
	lw s1,PLAYER_X_POS
	lw s2,PLAYER_Y_POS
	addi s1,s1,1			# a1=PLAYER_X_POS+1
	b wallCheck
	
movedown:
	lw s1,PLAYER_X_POS
	lw s2,PLAYER_Y_POS
	addi s2,s2,1			# a2=PLAYER_Y_POS+1
	b wallCheck
	
wallCheck:
	add a0,s1,zero
	add a1,s2,zero
	add a2,s6,zero
	add a3,s8,zero
	jal ra,checkIsWall		# check if the changed coordinate is a wall
	bnez a0,wallCheckfail		# if the coordinate is a Wall, go to wallCheckfail
	b wallChecksuccess
wallCheckfail:
	la t0,KEYINPUT
	sw zero,(t0)
	b validkey2

wallChecksuccess:

	la t1,PLAYER_X_POS
	la t2,PLAYER_Y_POS
	sw s1,(t1)			# store the updated x,y back
	sw s2,(t2)
	add a0,s8,zero			# a0 <-- max x
	add a1,s9,zero			# a1 <-- max y
	add a2,s6,zero			# a2 <-- 2d array pointer
	jal ra, printMaze		# goto printMaze
	bnez a0,endgame
	lw a1,GAME_ENDED
	bnez a1,endgame			# check if timer's up
	la t0,KEYINPUT
	sw zero,(t0)
	b validkey2

endgame:
#update time again	
	lw s7,TIME_LEFT			# load the time left into s7
	add a0,s7,zero			# a0 <-- s7
	jal ra, intToStr		# convert s7 to string
	
	add s3,zero,a0			# s3 <-- a0
	addi a1,s9,2			# set a1(row number) to max_y+2
	addi a2,zero,16			# set a2(col number) to 16
	jal ra, printChar		# print the 1st time character
	
	srli a0,s3,8			# shift s3 2 bits to the right
	addi a1,s9,2			# set a1(row number) to max_y+1
	addi a2,zero,17			# set a2(col number) to 17
	jal ra, printChar		# print the 2nd time character
	
# restoring values
	lw s7, 0(sp)
   	lw s1, 4(sp)
    	lw s2, 8(sp)
    	lw s3, 12(sp)
    	lw s4, 16(sp)
    	lw s5, 20(sp)
    	lw s6, 24(sp)
    	lw s8, 28(sp)
    	lw s9, 32(sp)
    	lw ra, 36(sp)
    	addi sp, sp, 40
	
	ret
	
#------------------------------------------------------------------------------
# handler:
# This handler catches and handles the keyboard and timer interrupts.
#
# S-Registers:
# s1 <-- 0x8000 0008 (keyboard interrupt uacause value)
# s2 <-- 0x8000 0004 (timer interrupt uacause register value)
#------------------------------------------------------------------------------
handler:
	# swap a0 and uscratch
	csrrw   a0, 0x040, a0     # a0 <- Addr[iTrapData], uscratch <- PROGRAMa0
	
	# save all used registers except a0
	sw      t0, 0(a0)         # save PROGRAMt0
        sw      t1, 4(a0)         # save PROGRAMt1
        sw      t2, 8(a0)         # save PROGRAMt2
        sw      t3, 12(a0)        # save PROGRAMt3
        sw      t4, 16(a0)        # save PROGRAMt4
        sw      s1, 20(a0)        # save PROGRAMs1
        sw      s2, 24(a0)        # save PROGRAMs2
        sw      s3, 28(a0)        # save PROGRAMs3
        sw      s4, 32(a0)        # save PROGRAMs4
        
        # save a0
      	csrr    t0, 0x040         # t0 <- PROGRAMa0     
      	sw      t0, 36(a0)        # save PROGRAMa0 
        
        li s1, 0x80000008		 # s1 <-- 0x8000 0008
        li s2, 0x80000004		# s2 <-- 0x8000 0004
        csrr    t1, 66		# t1 <-- ucause
        beq t1,s1,keyhandle		# if ucause == 0x8000 0008 go to keyhandle
        beq t1,s2,timerhandle		# if ucause == 0x8000 0004 go to timerhandle
        

keyhandle:
	lw t3, KEY_DATA			# t3 <-- address of keyboard data
	lw t4, (t3)			# t4 <-- keyboard data
	la t0,KEYINPUT			# t0 <-- address of KEYINPUT
	sw t4,(t0)			# KEYINPUT <-- t4
	
	# reset keyboard control
	li t0,0x02
	lw t2, KEY_CONTROL		# t2 <-- &(keyboard control)
	lw t1, (t2)			# t1 <-- *t2
	or t1,t1,t0			# t1 <-- t1 or t0
	sw t1,(t2)			# store t2 to keyboard control
	b handlerdone			# goto handlerdone

timerhandle:
        
        lw t0,GAME_ENDED		# t0 <-- GAME_ENDED
        bnez t0,handlerdone		# goto handler done if game has ended
        lw t1, TIME_LEFT		# t1 <-- Time left
        addi t1,t1,-1			# time left=time left - 1 s
        la t3,TIME_LEFT
        sw t1, (t3)		# store the updated time left into TIME_LEFT
        li t2,1				# t2 <-- 1
        slt s1,t1,t2			# set s1 to 1 if time left <= 0, else 0
        la t4,GAME_ENDED
        sw s1,(t4)		# set GAME_ENDED to be s1
        
        #update timecmp
        lw t0,TIME			# t0 <-- address of time
	lw t1,(t0)			# t1 <-- current time
	addi t2,t1,1000			# t2 <-- current time + 1s
	lw t3,TIMECMP			# t3 <-- address of timecmp
	sw t2,(t3)			# store current time + 1s to timecmp
        
handlerdone:
	
	la a0,iTrapData		# a0 <- Addr[iTrapData]
	lw t0,36(a0)		# t0 <-- PROGRAMa0
	csrw t0,0x040		# uscratch <-- PROGRAMa0
	
        lw      t0, 0(a0)         # restore PROGRAMt0
        lw      t1, 4(a0)         # restore PROGRAMt1
        lw      t2, 8(a0)         # restore PROGRAMt2
        lw      t3, 12(a0)        # restore PROGRAMt3
        lw      t4, 16(a0)        # restore PROGRAMt4
        lw      s1, 20(a0)        # restore PROGRAMs1
        lw      s2, 24(a0)        # restore PROGRAMs2
        lw      s3, 28(a0)        # restore PROGRAMs3
        lw      s4, 32(a0)        # restore PROGRAMs4
        
        csrrw a0,0x040,a0	  #a0 <- PROGRAMa0, uscratch <- Addr[iTrapData]
        
	uret

#------------------------------------------------------------------------------
# printMaze:
# Prints the maze within the view distance. Also checks if the agent is in the finish point, returns 1 if in the finish point, 0 if not
#
# Arguments:
#	a0: max x co-ordinate of the maze
#	a1: max y co-ordinate of the maze
#	a2: pointer to the array to store the maze
#
# Return:
#	a0: 1 if the agent is at the finish point, 0 if not
# S-Registers:
# s1 <-- a2 pointer to the array to store the MAZE
# s2 <-- To keep track of the X coordinate 
# s3 <-- To keep track of the Y coordinate 
# s4 <-- DRAW_DIS_X//2
# s5 <-- DRAW_DIS_Y//2
# s6 <-- a0 MAX X co-ordinate of the maze
# s7 <-- a1 MAX Y co-ordinate of the maze
# s8 <-- PLAYER_X_POS
# s9 <-- PLAYER_Y_POS
# s10 <-- keep track of whether the agent is in the finish point, initialized to 0
#------------------------------------------------------------------------------
printMaze:
	#calling convention
	addi sp, sp, -44
    	sw s7, 0(sp)
    	sw s1, 4(sp)
    	sw s2, 8(sp)
    	sw s3, 12(sp)
    	sw s4, 16(sp)
    	sw s5, 20(sp)
    	sw s6, 24(sp)
    	sw s8, 28(sp)
    	sw s9, 32(sp)
    	sw s10, 36(sp)
    	sw ra, 40(sp)
    	
    	add s10,zero,zero		# set s10 to keep track of whether the agent is in the finish point, initialized to 0
    	lw s8,PLAYER_X_POS		# s8 <-- PLAYER_X_POS
    	lw s9,PLAYER_Y_POS		# s9 <-- PLAYER_Y_POS
    	add s1,a2,zero			# s1 <-- a2 pointer to the array to store the MAZE
    	add s6,a0,zero			# s6 <-- a0 MAX X co-ordinate of the maze
    	add s7,a1,zero			# s7 <-- a1 MAX Y co-ordinate of the maze
    	lw s4,DRAW_DIS_X		# s4 <-- DRAW_DIS_X
    	lw s5,DRAW_DIS_Y		# s5 <-- DRAW_DIS_Y
    	srli s4,s4,1			# s4 <-- DRAW_DIS_X//2
    	srli s5,s5,1			# s5 <-- DRAW_DIS_Y//2
    	add s2,zero,zero		# s2 <-- 0	X coordinate for clearing the surface
    	add s3,zero,zero		# s3 <-- 0	Y coordinate for clearing the surface
	
clearsurface:
	sub t2,s8,s4			# set t2 to be PLAYER_X_POS - DRAW_DIS_X//2
	sub t3,s9,s5			# set t3 to be PLAYER_Y_POS - DRAW_DIS_Y//2
	add t4,s8,s4			# set t4 to be PLAYER_X_POS + DRAW_DIS_X//2
	add t5,s9,s5			# set t5 to be PLAYER_Y_POS + DRAW_DIS_Y//2
	blt s2,t2,clearsurface2
	blt s3,t3,clearsurface2
	bgt s2,t4,clearsurface2
	bgt s3,t5,clearsurface2		# if the current clearning position is in the area that's about to be printed, skip it
	b nextclear
clearsurface2:
	addi a0,zero,0x20		# a0 <-- space character	
	addi a1,s3,1			# set the row to print the charcater to be current surrounding's y + 1
	add a2,s2,zero			# set the col to print the charcater to be current surrounding's x
	jal ra,printChar		# print the character
nextclear:
	slt t1,s2,s6			# if current surrounding's x is less than MAX X, set t1 to 1, else 0
	add s2,s2,t1			# if current surrounding's x is less than MAX X, add 1 to x
	bnez t1,clearsurface		# go to clear surface again if x was successfully incremented
	bge s3,s7,clearcomplete		# complete clearning if the current y is already MAX Y
	addi s3,s3,1			# y++
	add s2,zero,zero		# x=0
	b clearsurface			# clear next position	
	
clearcomplete:
	sub s2,s8,s4			# initialize surroundings' x position to be PLAYER_X_POS - DRAW_DIS_X//2
	sub s3,s9,s5			# initialize surroundings' y position to be PLAYER_Y_POS - DRAW_DIS_Y//2
	
surroundingCheck:
	bltz s2,nextSurrounding		# goto nextSurrounding if current surrounding's x is less than 0
	bgt s2,s6,nextSurrounding	# goto nextSurrounding if current surrounding's x is greater than x max
	bltz s3,nextSurrounding		# goto nextSurrounding if current surrounding's y is less than 0
	bgt s3,s7,nextSurrounding	# goto nextSurrounding if current surrounding's y is greater than y max
	b printSurrounding
	
nextSurrounding:
	add t2,s8,s4			# t2 <-- PLAYER_X_POS + DRAW_DIS_X//2
	slt t1,s2,t2			# if current surrounding's x is less than PLAYER_X_POS + DRAW_DIS_X//2, set t1 to 1, else 0
	add s2,s2,t1			# if current surrounding's x is less than PLAYER_X_POS + DRAW_DIS_X//2, add 1 to current surrounding's x
	bnez t1,surroundingCheck	# skip the process of incrementing y and resetting x if current surrounding's x was successfully incremented
	add t3,s9,s5			# t3 <-- PLAYER_Y_POS + DRAW_DIS_Y//2
	bge s3,t3,printFinish		# goto printFinish if current surrounding's y >= PLAYER_Y_POS + DRAW_DIS_Y//2
	addi s3,s3,1			# increment current surrounding's y
	sub s2,s8,s4			# reinitialize current surroundings' x position to be PLAYER_X_POS - DRAW_DIS_X//2
	b surroundingCheck

printSurrounding:
	add a0,s2,zero			# copy current surrounding's x into a0
	add a1,s3,zero			# copy current surrounding's y into a1
	add a2,s1,zero			# copy pointer to the 2D array to a2
	add a3,s6,zero			# copy max x coordinate to a3
	jal ra, checkIsWall		# check if the current surrounding is wall
	bnez a0,printWall		# goto printWall if the current surrounding is wall
	
printSpace:
	lw a0,SPACE_CHARACTER		
	addi a1,s3,1			# set the row to print the charcater to be current surrounding's y + 1
	add a2,s2,zero			# set the col to print the charcater to be current surrounding's x
	jal ra,printChar		# print the character
	b nextSurrounding

printWall:
	lw a0,WALL_CHARACTER		
	addi a1,s3,1			# set the row to print the charcater to be current surrounding's y + 1
	add a2,s2,zero			# set the col to print the charcater to be current surrounding's x
	jal ra,printChar		# print the character
	b nextSurrounding
	

printFinish:
	lw a0,FINISH_POINT_CHARACTER	
	lw t1,FINISH_POINT_X		# t1 <-- FINISH_POINT_X
	lw t2,FINISH_POINT_Y		# t2 <-- FINISH_POINT_Y
	addi a1,t2,1			# row to print == FINISH_POINT_Y+1
	add a2,t1,zero			# col to print == FINISH_POINT_x
	jal ra, printChar		# print the finish point character
	
	lw t1,FINISH_POINT_X		# t1 <-- FINISH_POINT_X
	lw t2,FINISH_POINT_Y		# t2 <-- FINISH_POINT_Y
	bne s8,t1,printAgent		
	bne s9,t2,printAgent		# checking if player's at finish point if so, go to printFinish
	addi s10,zero,1			# set s10 to 1 to indicate the agent is at the finish point
	b endSuccess			# goto endSuccess
	
printAgent:
	lw a0,PLAYER_CHARACTER
	addi a1,s9,1			# row to print == PLAYER_Y_POS+1
	add a2,s8,zero			# col to print == PLAYER_X_POS
	jal ra, printChar		# print the player character
	
endprintMaze:
	add a0,s10,zero			# a0 <-- s10
	# restoring values
endSuccess:	
    	lw s7, 0(sp)
   	lw s1, 4(sp)
    	lw s2, 8(sp)
    	lw s3, 12(sp)
    	lw s4, 16(sp)
    	lw s5, 20(sp)
    	lw s6, 24(sp)
    	lw s8, 28(sp)
    	lw s9, 32(sp)
    	lw s10, 36(sp)
    	lw ra, 40(sp)
    	addi sp, sp, 44
	ret

#------------------------------------------------------------------------------
# buildMaze:
# Builds the in-memory representation of the maze as a 2D array.
#
# Args:
#	a0: pointer to the array that has wall info
#	a1: the number of "wall structs" in the array
#	a2: pointer to the array to store the maze
#	a3: max x co-ordinate of the maze
#	a4: max y co-ordinate of the maze
#
# Register Usage:
# set t1 to keep track of the current x coordinate
# set t2 to keep track of the current y coordinate
# set t3 to a0 to keep track of the current wall info
# set t4 to a2 to keep track of the current position's address
#------------------------------------------------------------------------------
buildMaze:

# --- insert your solution here ---
	#following function calling conventions
	addi sp, sp, -28
    	sw s7, 0(sp)
    	sw s1, 4(sp)
    	sw s2, 8(sp)
    	sw s3, 12(sp)
    	sw s4, 16(sp)
    	sw s5, 20(sp)
    	sw s6, 24(sp)
    	
	li t1,0			# set t1 to keep track of the current x coordinate
	li t2,0			# set t2 to keep track of the current y coordinate
	#add t3,zero,a0		# set t3 to a0 to keep track of the current wall info
	add t4,zero,a2		# set t4 to a2 to keep track of the current position's address
	
	slli s7,a1,4		# s7 <-- a1*16
	add s7,s7,a0		# s7 <-- s7+a0 (set s7 to be the ending address of the wall info array)
	li t5,1			# t5 <-- 1
	
buildMazeLoop:
	sb zero,(t4)		# set element to 0
	add t3,zero,a0		# set t3 to a0 to keep track of the current wall info
wallcheckLoop:
	bge t3,s7,nextelement1	# branch to nextelement1 if there's no wall that needs checking
	lw s1,0(t3)		# load the current maze info's startx to s1
	lw s2,4(t3)		# load the current maze info's starty to s2
	lw s3,8(t3)		# load the current maze info's endx to s3
	lw s4,12(t3) 		# load the current maze info's endy to s4
	addi t3,t3,16		# t3 <-- t3+16 (go to the next maze info)
	blt t1,s1,wallcheckLoop	# go to next maze info if currentx < startx
	bgt t1,s3,wallcheckLoop	# go to next maze info if currentx > endx
	blt t2,s2,wallcheckLoop	# go to next maze info if currenty < starty
	bgt t2,s4,wallcheckLoop	# go to next maze info if currenty > endy
	sb t5,(t4)		# set the current element to 1

nextelement1:
	slt t0,t1,a3		# set t0 to 1 if currentx < max of x coordinate
	add t1,t1,t0		# increment x if currentx < max of x coordinate
	seqz t0,t0		# set t0 to 1 if t0==0
	add t2,t2,t0		# increment y if currentx >= max of x coordinate
	bgt t2,a4,endbuildMaze		# goto end if currenty > max of y
	bne t0,t5,nextelement2	# branch to nextelement2 if t0 not equal to 1
	add t1,zero,zero	# currentx <-- 0
	addi t4,t4,1		# t4++ (increment address of the maze)
	b buildMazeLoop		# goto buildMazeLoop
	
nextelement2:
	addi t4,t4,1		# t4++ (increment address of the maze)
	b buildMazeLoop		# goto buildMazeLoop
	
endbuildMaze:
	
	
	# restoring values
    	lw s7, 0(sp)
   	lw s1, 4(sp)
    	lw s2, 8(sp)
    	lw s3, 12(sp)
    	lw s4, 16(sp)
    	lw s5, 20(sp)
    	lw s6, 24(sp)
    	addi sp, sp, 28
	ret

#------------------------------------------------------------------------------
# checkIsWall:
# Accesses the 2D array representing the maze.
#
# Args:
#	a0: the x co-ordinate of the point to check
#	a1: the y co-ordinate of the point to check
#	a2: pointer to the 2D array representing the maze
#	a3: the max x co-ordinate of the maze
#
# Returns:
#	a0: 1 if the point is a wall else 0
#
# Register Usage:
#  t0 <-- t0 + x coordinate
#  t1 <-- a3+1 (set t1 to the number of columns)
#  t2 <-- address of 2D array + y coordinate*number of columns + x coordinate
#------------------------------------------------------------------------------
checkIsWall:

# --- insert your solution here ---
	addi t1,zero,1		# t1 <-- 1
	add t1,t1,a3		# t1 <-- a3+1 (set t1 to the number of columns)
	mul t0,a1,t1		# t0 <-- y coordinate*number of columns
	add t0,t0,a0		# t0 <-- t0 + x coordinate
	add t2,a2,t0		# t2 <-- address of 2D array + y coordinate*number of columns + x coordinate
	lb t0,0(t2)		# load from t2
	sgtz a0,t0		# set a0 to 1 if t0>0 else set a0 to 0
	ret

#------------------------------------------------------------------------------
# intToStr:
# Converts at most a 2 digit integer into its ascii equivalent. The lower 2 bytes
# of the return contain the ASCII characters corresponding to the digits in the
# integer while the upper 2 bytes are guaranteed to be zero.
#
# Args:
#	a0: the integer that is to be converted to a string
#
# Returns:
#	a0: the ASCII characters corresponding to the integer in the lower 2 bytes
#
# Register Usage:
#   --- insert your register usage here ---
#------------------------------------------------------------------------------
intToStr:

# --- insert your solution here ---
	li t0,0x0A		# t0 <-- 0x0A(10) 	for calculation purpose
	div t1,a0,t0		# t1 <-- a0/10
	mul t1,t1,t0		# t1 <-- t1*10
	sub t2,a0,t1		# t2 <-- a0-t1
	div t1,t1,t0		# t1 <-- t1/10
	li t0,0x30		# t0 <-- 0x30	 	for conversion purpose	
	add t1,t1,t0		# t1 <-- t1+0x30(ascii value for'0')  
	add t2,t2,t0		# t2 <-- t2+0x30(ascii value for'0')  
	add a0,t2,zero		# a0 <-- t2
	slli a0,a0,8		# shift a0 left 8 bits(2 bytes)
	add a0,a0,t1		# a0 <-- a0+t1
	ret

#------------------------------------------------------------------------------
# For the proceeding code (functions "handlerTerminate", "printStr", "printChar"
# and "waitForDisplayReady"):
# Copyright 2020 University of Alberta
# Copyright 2022 Dhanrajbir Singh Hira
# Copyright 2018 Zachary Selk
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# handlerTerminate
# Print error msg before terminating
#------------------------------------------------------------------------------
handlerTerminate:
	li	a7, 4
	la	a0, INTERRUPT_ERROR
	ecall
	li	a7, 34
	csrrci	a0, 66, 0
	ecall
	li	a7, 4
	la	a0, INSTRUCTION_ERROR
	ecall
	li	a7, 34
	csrrci	a0, 65, 0
	ecall
handlerQuit:
	li	a7, 10
	ecall	# End of program

#------------------------------------------------------------------------------
# printStr
# Args:
# 	a0: strAddr - The address of the null-terminated string to be printed.
# 	a1: row - The row to print on.
# 	a2: col - The column to start printing on.
#
# Prints a string in the Keyboard and Display MMIO Simulator terminal at the
# given row and column.
#------------------------------------------------------------------------------
printStr:
	# Stack
	addi	sp, sp, -16
	sw	ra, 0(sp)
	sw	s0, 4(sp)
	sw	s1, 8(sp)
	sw	s2, 12(sp)
	
	mv	s0, a0
	mv	s1, a1
	mv	s2, a2
	printStrLoop:
		# Check for null-character
		lb	t0, 0(s0)	# t0 <- char = str[i]
		# Loop while(str[i] != '\0')
		beq	t0, zero, printStrLoopEnd
		
		# Print character
		mv	a0, t0		# a0 <- char
		mv	a1, s1		# a1 <- row
		mv	a2, s2		# a2 <- col
		jal	printChar
		
		addi	s0, s0, 1	# i++
		addi	s2, s2, 1	# col++
		j	printStrLoop
	printStrLoopEnd:
	
	# Unstack
	lw	ra, 0(sp)
	lw	s0, 4(sp)
	lw	s1, 8(sp)
	lw	s2, 12(sp)
	addi	sp, sp, 16
	jalr	zero, ra, 0

	
#------------------------------------------------------------------------------
# printChar
# Args:
#	a0: char - The character to print
#	a1: row - The row to print the given character
#	a2: col - The column to print the given character
#
# Prints a single character to the Keyboard and Display MMIO Simulator terminal
# at the given row and column.
#------------------------------------------------------------------------------
printChar:
	# Stack
	addi	sp, sp, -16
	sw	ra, 0(sp)
	sw	s0, 4(sp)
	sw	s1, 8(sp)
	sw	s2, 12(sp)
	
	# Save parameters
	add	s0, a0, zero
	add	s1, a1, zero
	add	s2, a2, zero
	
	jal	waitForDisplayReady	# Wait for display before printing
	
	# Load bell and position into a register
	addi	t0, zero, 7	# Bell ascii
	slli	s1, s1, 8	# Shift row into position
	slli	s2, s2, 20	# Shift col into position
	or	t0, t0, s1
	or	t0, t0, s2	# Combine ascii, row, & col
	
	# Move cursor
	lw	t1, DISPLAY_DATA
	sw	t0, 0(t1)
	
	jal	waitForDisplayReady	# Wait for display before printing
	
	# Print char
	lw	t0, DISPLAY_DATA
	sw	s0, 0(t0)
	
	# Unstack
	lw	ra, 0(sp)
	lw	s0, 4(sp)
	lw	s1, 8(sp)
	lw	s2, 12(sp)
	addi	sp, sp, 16
	jalr    zero, ra, 0
	
	
#------------------------------------------------------------------------------
# waitForDisplayReady
#
# A method that will check if the Keyboard and Display MMIO Simulator terminal
# can be writen to, busy-waiting until it can.
#------------------------------------------------------------------------------
waitForDisplayReady:
	# Loop while display ready bit is zero
	lw	t0, DISPLAY_CONTROL
	lw	t0, 0(t0)
	andi	t0, t0, 1
	beq	t0, zero, waitForDisplayReady
	
	jalr    zero, ra, 0
