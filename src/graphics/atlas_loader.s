.global load_texture_atlas
.global get_sprite_uvs
.align 4

// Atlas entry structure offsets
.equ AtlasEntry_x, 0
.equ AtlasEntry_y, 4
.equ AtlasEntry_width, 8
.equ AtlasEntry_height, 12
.equ AtlasEntry_u1, 16
.equ AtlasEntry_v1, 20
.equ AtlasEntry_u2, 24
.equ AtlasEntry_v2, 28
.equ AtlasEntry_size, 32

.section __TEXT,__text
load_texture_atlas:
    // x0 = atlas path
    // x1 = metadata path
    stp x29, x30, [sp, #-32]!
    stp x19, x20, [sp, #16]
    mov x29, sp
    
    mov x19, x0  // Save atlas path
    mov x20, x1  // Save metadata path
    
    // Load texture
    mov x0, x19
    bl load_texture_from_file
    mov x19, x0  // Save texture
    
    // Load metadata
    mov x0, x20
    bl load_json_file
    bl parse_atlas_metadata
    
    // Store in global
    adrp x1, texture_atlases@PAGE
    add x1, x1, texture_atlases@PAGEOFF
    stp x19, x0, [x1]  // texture, metadata
    
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

get_sprite_uvs:
    // x0 = sprite name hash
    // Returns UV coordinates in v0 (u1,v1,u2,v2)
    
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    
    // Look up in atlas metadata
    adrp x1, texture_atlases@PAGE
    add x1, x1, texture_atlases@PAGEOFF
    ldr x1, [x1, #8]  // metadata
    cbz x1, .sprite_not_found
    
    // Binary search for sprite
    bl find_sprite_entry
    cbz x0, .sprite_not_found
    
    // Load UVs into vector register
    add x0, x0, #AtlasEntry_u1
    ld1 {v0.4s}, [x0]
    
    ldp x29, x30, [sp], #16
    ret
    
.sprite_not_found:
    // Return default UVs (0,0,1,1)
    movi v0.4s, #0
    fmov s1, #1.0
    mov v0.s[2], v1.s[0]
    mov v0.s[3], v1.s[0]
    
    ldp x29, x30, [sp], #16
    ret

find_sprite_entry:
    // x0 = sprite name hash
    // x1 = metadata structure
    // Returns pointer to AtlasEntry or NULL
    
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    
    // For now, simple linear search
    // TODO: Implement proper hash table lookup
    
    // Return NULL for now
    mov x0, #0
    
    ldp x29, x30, [sp], #16
    ret

load_json_file:
    // x0 = filepath
    // Returns parsed metadata structure
    
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    
    // TODO: Implement JSON parsing
    // For now, return NULL
    mov x0, #0
    
    ldp x29, x30, [sp], #16
    ret

parse_atlas_metadata:
    // x0 = JSON data
    // Returns parsed atlas metadata structure
    
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    
    // TODO: Parse JSON into AtlasEntry structures
    // For now, return NULL
    mov x0, #0
    
    ldp x29, x30, [sp], #16
    ret

// Hash function for sprite names
hash_sprite_name:
    // x0 = sprite name string
    // Returns hash in x0
    
    mov x1, #0  // hash value
    mov x2, #31 // multiplier
    
.hash_loop:
    ldrb w3, [x0], #1
    cbz w3, .hash_done
    
    mul x1, x1, x2
    add x1, x1, x3
    b .hash_loop
    
.hash_done:
    mov x0, x1
    ret

.section __DATA,__data
// Predefined sprite mappings for testing
.global sprite_mappings
sprite_mappings:
    // buildingTiles_000: u1=0.0, v1=0.0, u2=0.0625, v2=0.0625 (assuming 256x256 in 4096x4096 atlas)
    .float 0.0, 0.0, 0.0625, 0.0625
    // buildingTiles_001: u1=0.0625, v1=0.0, u2=0.125, v2=0.0625
    .float 0.0625, 0.0, 0.125, 0.0625

.section __DATA,__bss
texture_atlases:
    .space 256  // Array of atlas pointers
    
sprite_mappings_extra:
    .space 1024  // Room for more sprite UV mappings