.global _main
.align 4

// Minimal SimCity ARM64 Assembly Prototype
// Simple working demo without complex dependencies

.text

_main:
    // Set up stack frame
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    
    // Print startup message
    adrp x0, startup_msg@PAGE
    add x0, x0, startup_msg@PAGEOFF
    bl _printf
    
    // Initialize simple city grid
    bl init_simple_city
    
    // Run basic simulation loop
    bl simple_game_loop
    
    // Print shutdown message
    adrp x0, shutdown_msg@PAGE
    add x0, x0, shutdown_msg@PAGEOFF
    bl _printf
    
    mov x0, #0                  // Success exit code
    ldp x29, x30, [sp], #16
    ret

// Initialize a simple 8x8 city grid
init_simple_city:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    
    adrp x0, init_msg@PAGE
    add x0, x0, init_msg@PAGEOFF
    bl _printf
    
    // Clear the city grid (8x8 = 64 tiles)
    adrp x0, city_grid@PAGE
    add x0, x0, city_grid@PAGEOFF
    mov x1, #64
    mov w2, #0                  // Empty tile
    
.clear_loop:
    strb w2, [x0], #1
    subs x1, x1, #1
    b.ne .clear_loop
    
    // Add some initial buildings
    adrp x0, city_grid@PAGE
    add x0, x0, city_grid@PAGEOFF
    
    // Add roads (type 1)
    mov w1, #1
    strb w1, [x0, #9]           // Row 1, Col 1
    strb w1, [x0, #10]          // Row 1, Col 2
    strb w1, [x0, #11]          // Row 1, Col 3
    
    // Add houses (type 2)
    mov w1, #2
    strb w1, [x0, #17]          // Row 2, Col 1
    strb w1, [x0, #19]          // Row 2, Col 3
    
    // Add commercial (type 3)
    mov w1, #3
    strb w1, [x0, #25]          // Row 3, Col 1
    
    ldp x29, x30, [sp], #16
    ret

// Simple game loop - display city and count down
simple_game_loop:
    stp x29, x30, [sp, #-32]!
    stp x19, x20, [sp, #16]
    mov x29, sp
    
    mov x19, #10                // Run for 10 iterations
    
.loop:
    // Display current city state
    bl display_city
    
    // Update city (simple population growth)
    bl update_city
    
    // Simple delay loop instead of sleep
    mov x0, #0x100000           // 1 million iterations (hex)
.delay_loop:
    subs x0, x0, #1
    b.ne .delay_loop
    
    // Decrement counter
    subs x19, x19, #1
    b.ne .loop
    
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// Display the 8x8 city grid
display_city:
    stp x29, x30, [sp, #-32]!
    stp x19, x20, [sp, #16]
    mov x29, sp
    
    // Clear screen
    adrp x0, clear_screen@PAGE
    add x0, x0, clear_screen@PAGEOFF
    bl _printf
    
    // Print header
    adrp x0, city_header@PAGE
    add x0, x0, city_header@PAGEOFF
    bl _printf
    
    adrp x19, city_grid@PAGE
    add x19, x19, city_grid@PAGEOFF
    mov x20, #0                 // Current position
    
.display_row:
    mov x0, #0                  // Column counter
    
.display_col:
    // Load tile type
    ldrb w1, [x19, x20]
    
    // Convert to character and print
    cmp w1, #0
    b.eq .print_empty
    cmp w1, #1
    b.eq .print_road
    cmp w1, #2
    b.eq .print_house
    cmp w1, #3
    b.eq .print_commercial
    
    // Default case
    mov w1, #'?'
    b .print_char
    
.print_empty:
    mov w1, #'.'
    b .print_char
    
.print_road:
    mov w1, #'#'
    b .print_char
    
.print_house:
    mov w1, #'H'
    b .print_char
    
.print_commercial:
    mov w1, #'C'
    
.print_char:
    // Print character
    adrp x0, char_format@PAGE
    add x0, x0, char_format@PAGEOFF
    bl _printf
    
    // Next tile
    add x20, x20, #1
    add x0, x0, #1
    cmp x0, #8
    b.lt .display_col
    
    // Print newline
    adrp x0, newline@PAGE
    add x0, x0, newline@PAGEOFF
    bl _printf
    
    // Check if we've done all 8 rows
    mov x0, x20
    mov x1, #8
    udiv x2, x0, x1
    cmp x2, #8
    b.lt .display_row
    
    // Print population
    adrp x0, population_format@PAGE
    add x0, x0, population_format@PAGEOFF
    adrp x1, population@PAGE
    add x1, x1, population@PAGEOFF
    ldr w1, [x1]
    bl _printf
    
    adrp x0, newline@PAGE
    add x0, x0, newline@PAGEOFF
    bl _printf
    
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// Simple city update - count buildings and update population
update_city:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    
    adrp x0, city_grid@PAGE
    add x0, x0, city_grid@PAGEOFF
    
    mov x1, #0                  // House count
    mov x2, #0                  // Commercial count  
    mov x3, #64                 // Tile count
    
.count_loop:
    ldrb w4, [x0], #1
    cmp w4, #2                  // House
    b.ne .check_commercial
    add x1, x1, #1
    b .next_tile
    
.check_commercial:
    cmp w4, #3                  // Commercial
    b.ne .next_tile
    add x2, x2, #1
    
.next_tile:
    subs x3, x3, #1
    b.ne .count_loop
    
    // Calculate population (houses * 4 + commercial * 2)
    lsl x1, x1, #2              // houses * 4
    lsl x2, x2, #1              // commercial * 2
    add x1, x1, x2
    
    // Store population
    adrp x0, population@PAGE
    add x0, x0, population@PAGEOFF
    str w1, [x0]
    
    ldp x29, x30, [sp], #16
    ret

.data
.align 3

startup_msg:
    .asciz "🏙️  SimCity ARM64 Assembly - Minimal Prototype\n"

init_msg:
    .asciz "🔧 Initializing 8x8 city grid...\n"

city_header:
    .asciz "=== SimCity Status ===\n"

char_format:
    .asciz "%c "

newline:
    .asciz "\n"

population_format:
    .asciz "Population: %d\n"

shutdown_msg:
    .asciz "🛑 SimCity simulation complete!\n"

clear_screen:
    .asciz "\033[2J\033[H"

.bss
.align 3

// Simple 8x8 city grid (64 bytes)
city_grid:
    .space 64

// Current population
population:
    .space 4