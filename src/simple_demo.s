.global _main
.align 4

// Simple working SimCity demo

.text

_main:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    
    // Print startup
    adrp x0, startup_msg@PAGE
    add x0, x0, startup_msg@PAGEOFF
    bl _printf
    
    // Initialize city
    bl init_city
    
    // Show city a few times
    bl show_city
    bl update_city
    bl show_city
    bl update_city
    bl show_city
    
    // Print completion
    adrp x0, complete_msg@PAGE
    add x0, x0, complete_msg@PAGEOFF
    bl _printf
    
    mov x0, #0
    ldp x29, x30, [sp], #16
    ret

init_city:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    
    adrp x0, init_msg@PAGE
    add x0, x0, init_msg@PAGEOFF
    bl _printf
    
    // Initialize simple 4x4 grid
    adrp x0, city@PAGE
    add x0, x0, city@PAGEOFF
    
    // Clear grid
    mov x1, #16
    mov w2, #0
.clear:
    strb w2, [x0], #1
    subs x1, x1, #1
    b.ne .clear
    
    // Add some buildings
    adrp x0, city@PAGE
    add x0, x0, city@PAGEOFF
    mov w1, #1                  // Road
    strb w1, [x0, #1]
    strb w1, [x0, #2]
    
    mov w1, #2                  // House
    strb w1, [x0, #5]
    strb w1, [x0, #6]
    
    mov w1, #3                  // Commercial
    strb w1, [x0, #9]
    
    ldp x29, x30, [sp], #16
    ret

show_city:
    stp x29, x30, [sp, #-48]!
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    mov x29, sp
    
    adrp x0, city_header@PAGE
    add x0, x0, city_header@PAGEOFF
    bl _printf
    
    adrp x19, city@PAGE
    add x19, x19, city@PAGEOFF
    mov x20, #0                 // Position
    
.row_loop:
    mov x21, #0                 // Column in row (use x21 instead of x0)
.col_loop:
    ldrb w1, [x19, x20]
    
    // Convert tile to character
    cmp w1, #0
    b.eq .print_empty
    cmp w1, #1
    b.eq .print_road
    cmp w1, #2
    b.eq .print_house
    // Default: commercial
    mov w1, #'C'
    b .print

.print_empty:
    mov w1, #'.'
    b .print
.print_road:
    mov w1, #'#'
    b .print
.print_house:
    mov w1, #'H'
    
.print:
    // x1 already contains the character
    adrp x0, char_fmt@PAGE
    add x0, x0, char_fmt@PAGEOFF
    bl _printf
    
    add x20, x20, #1
    add x21, x21, #1            // Increment column counter (x21)
    cmp x21, #4                 // Compare column counter (x21)
    b.lt .col_loop
    
    // Print newline every 4 tiles
    adrp x0, newline@PAGE
    add x0, x0, newline@PAGEOFF
    bl _printf
    
    // Check if done (16 tiles total)
    cmp x20, #16
    b.lt .row_loop
    
    // Show population
    adrp x0, pop_msg@PAGE
    add x0, x0, pop_msg@PAGEOFF
    adrp x1, population@PAGE
    add x1, x1, population@PAGEOFF
    ldr w1, [x1]
    bl _printf
    
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

update_city:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    
    // Count houses and update population
    adrp x0, city@PAGE
    add x0, x0, city@PAGEOFF
    mov x1, #0                  // House count
    mov x2, #16                 // Tiles to check
    
.count:
    ldrb w3, [x0], #1
    cmp w3, #2                  // House
    b.ne .next
    add x1, x1, #1
.next:
    subs x2, x2, #1
    b.ne .count
    
    // Population = houses * 4
    lsl x1, x1, #2
    adrp x0, population@PAGE
    add x0, x0, population@PAGEOFF
    str w1, [x0]
    
    ldp x29, x30, [sp], #16
    ret

.data
.align 3

startup_msg:
    .asciz "🏙️  SimCity ARM64 - Simple Demo\n"

init_msg:
    .asciz "🔧 Creating 4x4 city...\n"

city_header:
    .asciz "\n=== City Grid ===\n"

char_fmt:
    .asciz "%c "

newline:
    .asciz "\n"

pop_msg:
    .asciz "Population: %d\n"

complete_msg:
    .asciz "✅ Demo complete!\n"

.bss
.align 3

city:
    .space 16

population:
    .space 4