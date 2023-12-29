.data
iTrapData:    .space     256
        .align     2
rawInputBuffer:    .space     4096
wallInfoArray:    .space     16384
mazeBuffer:    .space    16384


fileOpenErrStr:    .asciz "Unable to open file\n"
invalidFileContentsStr: .asciz "Invalid file."

# Draw distance of the player in the x and y direction respectively.
DRAW_DIS_X:        .word    0x0
DRAW_DIS_Y:        .word    0x0

# Player's position, set to the initial position before calling the maze function.
PLAYER_X_POS:        .word    0x0
PLAYER_Y_POS:        .word    0x0

# The co-ordinates of the finish point in the maze, set to the values defined by the maze file before
# calling the maze function.
FINISH_POINT_X:        .word    0x00
FINISH_POINT_Y:        .word    0x00

# ASCII values for the various characters displayed throughout the game.
WALL_CHARACTER:        .word    0x23
SPACE_CHARACTER:    .word    0x20
PLAYER_CHARACTER:    .word    0x41
FINISH_POINT_CHARACTER:    .word    0x40
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
    mv s0, a1        # save the address of the input file name

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
# Register Usage:
#    s0: To save the memory address of the next byte to read from the raw input buffer.
#    s1: To save the memory address where the next integer should be written.
#    s2: End address of the input buffer.
#    s3: Number of integers in the parsed output.
#    s4: To save the ascii code for the comma character.
#    s5: To save the ascii code for the linefeed character.
#    s6: To save the ascii code for space (" ")
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

