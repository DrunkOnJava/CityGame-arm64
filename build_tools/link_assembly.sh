#!/bin/bash
# SimCity ARM64 Assembly Linking Scripts
# Agent E5: Platform Team - Advanced Linking for Assembly Modules
# Creates optimized linking pipeline for all agent outputs

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Project configuration
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${PROJECT_ROOT}/build"
LINK_DIR="${BUILD_DIR}/link"
BIN_DIR="${BUILD_DIR}/bin"

# Linker configuration
LINKER="clang"
OBJDUMP="objdump"
NM="nm"
STRIP="strip"

# Advanced linking flags for ARM64 assembly
LINK_FLAGS_BASE=(
    "-arch" "arm64"
    "-Wl,-no_compact_unwind"
    "-Wl,-no_eh_labels" 
    "-Wl,-dead_strip"                   # Remove unused code
    "-Wl,-dead_strip_dylibs"            # Remove unused dylibs
    "-Wl,-mark_dead_strippable_dylib"   # Mark for dead stripping
)

# Performance optimization flags
LINK_FLAGS_OPTIMIZED=(
    "-Wl,-order_file,${LINK_DIR}/symbol_order.txt"  # Symbol ordering for performance
    "-Wl,-sectcreate,__TEXT,__info_plist,${LINK_DIR}/Info.plist"  # Info.plist
    "-Wl,-install_name,@executable_path/simcity"     # Install name
    "-Wl,-headerpad_max_install_names"              # Header padding
)

# Debug linking flags
LINK_FLAGS_DEBUG=(
    "-Wl,-keep_private_externs"     # Keep private symbols for debugging
    "-Wl,-no-dead_strip"            # Don't strip for debugging
)

# System frameworks and libraries
FRAMEWORKS=(
    "-framework" "CoreFoundation"
    "-framework" "Foundation" 
    "-framework" "CoreGraphics"
    "-framework" "Metal"
    "-framework" "MetalKit"
    "-framework" "MetalPerformanceShaders"
    "-framework" "Cocoa"
    "-framework" "QuartzCore"
    "-framework" "CoreAudio"
    "-framework" "AudioToolbox"
    "-framework" "AVFoundation"
)

SYSTEM_LIBS=(
    "-lc"
    "-lm"
    "-lpthread"
    "-ldl"
    "-lz"
)

# Agent module dependencies (topologically sorted)
AGENT_DEPENDENCIES=(
    "platform"     # Base platform layer - no dependencies
    "memory"       # Memory management - depends on platform
    "tools"        # Development tools - depends on platform, memory
    "graphics"     # Graphics - depends on platform, memory
    "audio"        # Audio - depends on platform, memory
    "io"           # I/O - depends on platform, memory
    "network"      # Network infrastructure - depends on platform, memory, io
    "simulation"   # Simulation engine - depends on platform, memory, graphics
    "agents"       # AI agents - depends on platform, memory, simulation
    "ui"           # User interface - depends on platform, memory, graphics, simulation
)

# Binary variants to create
BINARY_VARIANTS=(
    "simcity_full"      # Full featured version
    "simcity_minimal"   # Minimal version for testing
    "simcity_debug"     # Debug version with full symbols
    "simcity_profile"   # Profiling version with instrumentation
)

print_status() {
    echo -e "${BLUE}[LINK]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Function to setup linking directories
setup_link_dirs() {
    print_status "Setting up linking directories..."
    
    mkdir -p "${LINK_DIR}"/{symbols,maps,scripts,configs}
    mkdir -p "${BIN_DIR}"
    
    print_success "Linking directories created"
}

# Function to analyze symbols from object files
analyze_symbols() {
    print_status "Analyzing symbols for optimization..."
    
    local symbol_file="${LINK_DIR}/symbols/all_symbols.txt"
    local strong_symbols="${LINK_DIR}/symbols/strong_symbols.txt"
    local weak_symbols="${LINK_DIR}/symbols/weak_symbols.txt"
    
    # Clear previous symbol files
    > "$symbol_file"
    > "$strong_symbols"
    > "$weak_symbols"
    
    # Collect symbols from all object files
    find "${BUILD_DIR}/obj" -name "*.o" -exec nm -g {} \; > "$symbol_file" 2>/dev/null || true
    
    # Separate strong and weak symbols
    grep -E "^[0-9a-fA-F]+ [DTBSC] " "$symbol_file" > "$strong_symbols" 2>/dev/null || true
    grep -E "^[0-9a-fA-F]+ [Uuv] " "$symbol_file" > "$weak_symbols" 2>/dev/null || true
    
    local strong_count=$(wc -l < "$strong_symbols")
    local weak_count=$(wc -l < "$weak_symbols")
    
    print_status "Symbol analysis complete: $strong_count strong, $weak_count weak"
}

# Function to generate symbol ordering file for performance
generate_symbol_order() {
    print_status "Generating symbol ordering for performance optimization..."
    
    local order_file="${LINK_DIR}/symbol_order.txt"
    
    cat > "$order_file" << 'EOF'
# SimCity ARM64 Symbol Ordering for Performance
# Hot path functions first, cold path functions last

# Entry points
_main
_start

# Platform layer (most frequently called)
_platform_init
_platform_syscall
_platform_thread_create
_platform_memory_alloc

# Memory management (hot path)
_memory_alloc
_memory_free
_memory_realloc
_tlsf_malloc
_tlsf_free
_slab_alloc
_slab_free

# Graphics rendering (frame critical)
_graphics_render_frame
_graphics_update_sprites
_graphics_draw_tiles
_metal_encode_commands
_isometric_transform

# Simulation engine (game loop critical) 
_simulation_update
_simulation_tick
_ecs_update_systems
_entity_update

# AI agents (CPU intensive)
_agents_update
_pathfind_a_star
_behavior_tree_execute

# Less frequently called functions
_ui_handle_input
_audio_play_sound
_io_save_game
_io_load_game

# Cold path functions
_tools_profiler_init
_tools_debug_print
_error_handlers
EOF

    print_success "Symbol ordering file generated"
}

# Function to create Info.plist for macOS bundle
create_info_plist() {
    local plist_file="${LINK_DIR}/Info.plist"
    
    cat > "$plist_file" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>simcity</string>
    <key>CFBundleIdentifier</key>
    <string>com.simcity.arm64</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>SimCity ARM64</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>11.0</string>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2025 SimCity ARM64 Project</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.games</string>
</dict>
</plist>
EOF

    print_success "Info.plist created"
}

# Function to validate module dependencies
validate_dependencies() {
    local module="$1"
    print_status "Validating dependencies for $module..."
    
    local module_lib="${BUILD_DIR}/lib/${module}/lib${module}.a"
    if [ ! -f "$module_lib" ]; then
        print_error "Module library not found: $module_lib"
        return 1
    fi
    
    # Check for undefined symbols
    local undefined_file="${LINK_DIR}/symbols/${module}_undefined.txt"
    nm -u "$module_lib" > "$undefined_file" 2>/dev/null || true
    
    local undefined_count=$(wc -l < "$undefined_file")
    if [ "$undefined_count" -gt 0 ]; then
        print_status "$module has $undefined_count undefined symbols"
    fi
    
    return 0
}

# Function to create linker script
create_linker_script() {
    local variant="$1"
    local script_file="${LINK_DIR}/scripts/${variant}.ld"
    
    print_status "Creating linker script for $variant..."
    
    cat > "$script_file" << 'EOF'
/* SimCity ARM64 Linker Script */
/* Optimized for Apple Silicon Memory Layout */

SECTIONS
{
    /* Code section - optimized for instruction cache */
    .text : {
        *(.text.entry)      /* Entry points first */
        *(.text.hot)        /* Hot path functions */
        *(.text.platform)   /* Platform layer */
        *(.text.memory)     /* Memory management */
        *(.text.graphics)   /* Graphics pipeline */
        *(.text.simulation) /* Simulation engine */
        *(.text.agents)     /* AI agents */
        *(.text.cold)       /* Cold path functions */
        *(.text)            /* Remaining code */
    }
    
    /* Read-only data - constants and lookup tables */
    .rodata : {
        *(.rodata.constants) /* Game constants */
        *(.rodata.tables)    /* Lookup tables */
        *(.rodata)           /* Other read-only data */
    }
    
    /* Initialized data */
    .data : {
        *(.data.game_state)  /* Game state variables */
        *(.data.config)      /* Configuration data */
        *(.data)             /* Other initialized data */
    }
    
    /* Uninitialized data */
    .bss : {
        *(.bss.large)        /* Large arrays */
        *(.bss.agents)       /* Agent arrays */
        *(.bss)              /* Other uninitialized data */
    }
}
EOF

    print_success "Linker script created for $variant"
}

# Function to link specific binary variant
link_binary_variant() {
    local variant="$1"
    local link_flags=("${LINK_FLAGS_BASE[@]}")
    local output_binary="${BIN_DIR}/${variant}"
    
    print_status "Linking binary variant: $variant"
    
    # Add variant-specific flags
    case "$variant" in
        simcity_full)
            link_flags+=("${LINK_FLAGS_OPTIMIZED[@]}")
            ;;
        simcity_debug)
            link_flags+=("${LINK_FLAGS_DEBUG[@]}")
            ;;
        simcity_minimal)
            # Minimal flags - exclude optional modules
            ;;
        simcity_profile)
            link_flags+=("-Wl,-sectcreate,__TEXT,__profile,/dev/null")
            ;;
    esac
    
    # Collect required libraries based on variant
    local required_libs=()
    for module in "${AGENT_DEPENDENCIES[@]}"; do
        local module_lib="${BUILD_DIR}/lib/${module}/lib${module}.a"
        
        # Skip optional modules for minimal variant
        if [ "$variant" = "simcity_minimal" ]; then
            case "$module" in
                audio|tools|ui)
                    print_status "Skipping optional module for minimal build: $module"
                    continue
                    ;;
            esac
        fi
        
        if [ -f "$module_lib" ]; then
            required_libs+=("$module_lib")
        else
            print_warning "Module library not found: $module_lib"
        fi
    done
    
    # Main object file
    local main_obj="${BUILD_DIR}/obj/main.o"
    if [ ! -f "$main_obj" ]; then
        print_error "Main object file not found: $main_obj" 
        return 1
    fi
    
    # Construct link command
    local link_cmd=(
        "$LINKER"
        "${link_flags[@]}"
        "$main_obj"
        "${required_libs[@]}"
        "${FRAMEWORKS[@]}"
        "${SYSTEM_LIBS[@]}"
        "-o" "$output_binary"
    )
    
    print_status "Linking with ${#required_libs[@]} modules..."
    
    # Execute linking
    if "${link_cmd[@]}" 2>&1; then
        print_success "Successfully linked: $variant"
        
        # Show binary info
        if [ -f "$output_binary" ]; then
            local binary_size=$(stat -f%z "$output_binary" 2>/dev/null || stat -c%s "$output_binary" 2>/dev/null)
            print_status "$variant size: $((binary_size / 1024)) KB"
        fi
        
        # Generate symbol map
        generate_symbol_map "$variant" "$output_binary"
        
        return 0
    else
        print_error "Failed to link: $variant"
        return 1
    fi
}

# Function to generate symbol map
generate_symbol_map() {
    local variant="$1"
    local binary="$2"
    local map_file="${LINK_DIR}/maps/${variant}_symbols.map"
    
    print_status "Generating symbol map for $variant..."
    
    {
        echo "Symbol Map for $variant"
        echo "======================"
        echo "Generated: $(date)"
        echo ""
        
        echo "Exported Symbols:"
        echo "----------------"
        nm -g "$binary" | grep -E "^[0-9a-fA-F]+ [DTBSC] " || true
        echo ""
        
        echo "Imported Symbols:"
        echo "----------------"
        nm -u "$binary" || true
        echo ""
        
        echo "Section Layout:"
        echo "--------------"
        if command -v otool >/dev/null 2>&1; then
            otool -l "$binary" | grep -A5 sectname || true
        fi
    } > "$map_file"
    
    print_success "Symbol map generated: $map_file"
}

# Function to optimize binary
optimize_binary() {
    local binary="$1"
    local variant="$2"
    
    print_status "Optimizing binary: $variant"
    
    # Create optimized copy
    local optimized_binary="${binary}.optimized"
    cp "$binary" "$optimized_binary"
    
    # Strip symbols for release builds
    if [ "$variant" != "simcity_debug" ]; then
        if $STRIP -S "$optimized_binary" 2>/dev/null; then
            print_status "Stripped debug symbols"
        fi
    fi
    
    # Replace original with optimized version
    mv "$optimized_binary" "$binary"
    print_success "Binary optimization complete"
}

# Function to verify binary integrity
verify_binary() {
    local binary="$1"
    local variant="$2"
    
    print_status "Verifying binary integrity: $variant"
    
    # Check if binary is executable
    if [ ! -x "$binary" ]; then
        print_error "Binary is not executable: $binary"
        return 1
    fi
    
    # Check architecture
    if ! file "$binary" | grep -q "arm64"; then
        print_error "Binary is not ARM64 architecture"
        return 1
    fi
    
    # Check for required symbols (basic validation)
    local required_symbols=("_main" "_platform_init" "_memory_alloc")
    for symbol in "${required_symbols[@]}"; do
        if ! nm "$binary" | grep -q "$symbol"; then
            print_warning "Required symbol not found: $symbol"
        fi
    done
    
    print_success "Binary verification passed: $variant"
    return 0
}

# Function to create universal linking report
create_linking_report() {
    print_status "Creating linking report..."
    
    local report_file="${LINK_DIR}/linking_report_$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "SimCity ARM64 Linking Report"
        echo "==========================="
        echo "Generated: $(date)"
        echo "Linker: $LINKER"
        echo ""
        
        echo "Binary Variants Created:"
        echo "-----------------------"
        for variant in "${BINARY_VARIANTS[@]}"; do
            local binary="${BIN_DIR}/${variant}"
            if [ -f "$binary" ]; then
                local size=$(stat -f%z "$binary" 2>/dev/null || stat -c%s "$binary" 2>/dev/null)
                echo "✓ $variant ($((size / 1024)) KB)"
            else
                echo "✗ $variant (failed)"
            fi
        done
        echo ""
        
        echo "Module Dependencies:"
        echo "-------------------"
        for module in "${AGENT_DEPENDENCIES[@]}"; do
            local lib="${BUILD_DIR}/lib/${module}/lib${module}.a"
            if [ -f "$lib" ]; then
                local size=$(stat -f%z "$lib" 2>/dev/null || stat -c%s "$lib" 2>/dev/null)
                echo "✓ $module ($((size / 1024)) KB)"
            else
                echo "✗ $module (missing)"
            fi
        done
        echo ""
        
        echo "Linking Configuration:"
        echo "---------------------"
        echo "Base flags: ${LINK_FLAGS_BASE[*]}"
        echo "Frameworks: ${#FRAMEWORKS[@]} frameworks linked"
        echo "System libs: ${#SYSTEM_LIBS[@]} system libraries"
        echo ""
        
        echo "Generated Files:"
        echo "---------------"
        echo "Symbol maps: $(find "${LINK_DIR}/maps" -name "*.map" 2>/dev/null | wc -l)"
        echo "Linker scripts: $(find "${LINK_DIR}/scripts" -name "*.ld" 2>/dev/null | wc -l)"
        echo "Binary variants: $(find "${BIN_DIR}" -type f -executable 2>/dev/null | wc -l)"
        
    } > "$report_file"
    
    print_success "Linking report created: $report_file"
}

# Main linking function
main() {
    echo -e "${CYAN}SimCity ARM64 Assembly Linking System${NC}"
    echo -e "${CYAN}=====================================${NC}"
    echo ""
    
    # Setup
    setup_link_dirs
    analyze_symbols
    generate_symbol_order
    create_info_plist
    
    # Validate all modules
    print_status "Validating module dependencies..."
    for module in "${AGENT_DEPENDENCIES[@]}"; do
        validate_dependencies "$module"
    done
    
    # Create linker scripts for each variant
    for variant in "${BINARY_VARIANTS[@]}"; do
        create_linker_script "$variant"
    done
    
    # Link all binary variants
    local successful_builds=()
    local failed_builds=()
    
    for variant in "${BINARY_VARIANTS[@]}"; do
        if link_binary_variant "$variant"; then
            local binary="${BIN_DIR}/${variant}"
            optimize_binary "$binary" "$variant"
            
            if verify_binary "$binary" "$variant"; then
                successful_builds+=("$variant")
            else
                failed_builds+=("$variant")
            fi
        else
            failed_builds+=("$variant")
        fi
    done
    
    # Report results
    echo ""
    print_status "Linking Summary:"
    echo "================"
    
    if [ ${#successful_builds[@]} -gt 0 ]; then
        print_success "Successfully linked variants:"
        for variant in "${successful_builds[@]}"; do
            echo "  ✓ $variant"
        done
    fi
    
    if [ ${#failed_builds[@]} -gt 0 ]; then
        print_error "Failed to link variants:"
        for variant in "${failed_builds[@]}"; do
            echo "  ✗ $variant"
        done
    fi
    
    # Create final report
    create_linking_report
    
    echo ""
    if [ ${#failed_builds[@]} -eq 0 ]; then
        print_success "All binary variants linked successfully!"
    else
        print_error "Some variants failed to link"
        exit 1
    fi
}

# Execute main function
main "$@"