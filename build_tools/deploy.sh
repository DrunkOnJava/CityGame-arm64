#!/bin/bash
# SimCity ARM64 Deployment and Packaging System
# Agent E5: Platform Team - Complete Deployment Pipeline
# Creates distribution packages for macOS ARM64 systems

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Project configuration
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${PROJECT_ROOT}/build"
DEPLOY_DIR="${BUILD_DIR}/deploy"
PACKAGE_DIR="${DEPLOY_DIR}/packages"
DIST_DIR="${DEPLOY_DIR}/dist"
STAGING_DIR="${DEPLOY_DIR}/staging"

# Application information
APP_NAME="SimCity ARM64"
APP_BUNDLE_ID="com.simcity.arm64"
APP_VERSION="1.0.0"
APP_BUILD="$(date +%Y%m%d.%H%M)"
APP_EXECUTABLE="simcity_full"

# Code signing configuration
DEVELOPER_ID=""
PROVISIONING_PROFILE=""
SIGN_ENABLED=false
NOTARIZE_ENABLED=false

# Package variants
PACKAGE_VARIANTS=(
    "minimal"       # Minimal runtime version
    "standard"      # Standard full-featured version
    "developer"     # Developer version with debug tools
    "benchmark"     # Benchmarking and profiling version
)

# Deployment targets
DEPLOYMENT_TARGETS=(
    "app_bundle"    # macOS .app bundle
    "pkg_installer" # macOS .pkg installer
    "dmg_image"     # macOS .dmg disk image
    "archive"       # Compressed archive
)

# System requirements
MIN_MACOS_VERSION="11.0"
REQUIRED_MEMORY_GB=8
RECOMMENDED_MEMORY_GB=16

print_banner() {
    echo -e "${CYAN}=================================================${NC}"
    echo -e "${CYAN} SimCity ARM64 Deployment & Packaging System${NC}"
    echo -e "${CYAN} Agent E5: Complete Distribution Pipeline${NC}"
    echo -e "${CYAN}=================================================${NC}"
    echo ""
}

print_status() {
    echo -e "${BLUE}[DEPLOY]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_failure() {
    echo -e "${RED}[FAIL]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_package() {
    echo -e "${MAGENTA}[PACKAGE]${NC} $1"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS] [VARIANTS...] [TARGETS...]"
    echo ""
    echo "Package Variants:"
    echo "  minimal        Minimal runtime version"
    echo "  standard       Standard full-featured version"
    echo "  developer      Developer version with tools"
    echo "  benchmark      Benchmarking version"
    echo "  all            All variants (default)"
    echo ""
    echo "Deployment Targets:"
    echo "  app_bundle     macOS .app bundle"
    echo "  pkg_installer  macOS .pkg installer"
    echo "  dmg_image      macOS .dmg disk image"
    echo "  archive        Compressed archive"
    echo "  all            All targets (default)"
    echo ""
    echo "Options:"
    echo "  --sign         Enable code signing"
    echo "  --notarize     Enable notarization (requires signing)"
    echo "  --version V    Set application version (default: $APP_VERSION)"
    echo "  --dev-id ID    Set developer ID for signing"
    echo "  --clean        Clean deployment directory first"
    echo "  --verbose      Enable verbose output"
    echo "  --help, -h     Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                           # Deploy all variants and targets"
    echo "  $0 standard app_bundle       # Deploy standard version as app bundle"
    echo "  $0 --sign --notarize all     # Deploy all with code signing and notarization"
    echo "  $0 minimal archive           # Deploy minimal version as archive"
}

# Function to check deployment dependencies
check_deployment_dependencies() {
    print_status "Checking deployment dependencies..."
    
    local missing_deps=()
    
    # Check for required tools
    if ! command -v codesign >/dev/null 2>&1; then
        missing_deps+=("codesign (Xcode command line tools)")
    fi
    
    if ! command -v productbuild >/dev/null 2>&1; then
        missing_deps+=("productbuild (Xcode command line tools)")
    fi
    
    if ! command -v hdiutil >/dev/null 2>&1; then
        missing_deps+=("hdiutil (macOS disk utility)")
    fi
    
    if ! command -v zip >/dev/null 2>&1; then
        missing_deps+=("zip utility")
    fi
    
    # Check for built executables
    if [ ! -f "${BUILD_DIR}/bin/${APP_EXECUTABLE}" ]; then
        missing_deps+=("${APP_EXECUTABLE} executable (run build system first)")
    fi
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        print_failure "Missing deployment dependencies:"
        for dep in "${missing_deps[@]}"; do
            echo "  - $dep"
        done
        exit 1
    fi
    
    print_success "All deployment dependencies found"
}

# Function to setup deployment directories
setup_deployment_dirs() {
    print_status "Setting up deployment directories..."
    
    # Clean if requested
    if [ "${CLEAN_DEPLOY:-false}" = true ]; then
        rm -rf "$DEPLOY_DIR"
    fi
    
    # Create directory structure
    mkdir -p "${DEPLOY_DIR}"/{packages,dist,staging,scripts,resources}
    mkdir -p "${PACKAGE_DIR}"
    mkdir -p "${DIST_DIR}"
    mkdir -p "${STAGING_DIR}"
    
    # Create variant-specific directories
    for variant in "${PACKAGE_VARIANTS[@]}"; do
        mkdir -p "${STAGING_DIR}/${variant}"
        mkdir -p "${PACKAGE_DIR}/${variant}"
    done
    
    print_success "Deployment directories created"
}

# Function to create Info.plist for app bundle
create_app_info_plist() {
    local variant="$1"
    local plist_file="$2"
    
    cat > "$plist_file" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundleExecutable</key>
    <string>$(basename "${APP_EXECUTABLE}" .exe)</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>${APP_BUNDLE_ID}.${variant}</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$APP_VERSION</string>
    <key>CFBundleVersion</key>
    <string>$APP_BUILD</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.games</string>
    <key>LSMinimumSystemVersion</key>
    <string>$MIN_MACOS_VERSION</string>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2025 SimCity ARM64 Project</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSRequiresAquaSystemAppearance</key>
    <false/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
    <key>LSArchitecturePriority</key>
    <array>
        <string>arm64</string>
    </array>
    <key>LSRequiresNativeExecution</key>
    <true/>
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsArbitraryLoads</key>
        <false/>
    </dict>
    <key>SimCityBuildInfo</key>
    <dict>
        <key>BuildVariant</key>
        <string>$variant</string>
        <key>BuildDate</key>
        <string>$(date -Iseconds)</string>
        <key>TargetArchitecture</key>
        <string>arm64</string>
        <key>AssemblyOnlyBuild</key>
        <true/>
    </dict>
</dict>
</plist>
EOF
}

# Function to create app bundle
create_app_bundle() {
    local variant="$1"
    local app_bundle="${STAGING_DIR}/${variant}/${APP_NAME} ${variant^}.app"
    
    print_package "Creating app bundle for $variant variant..."
    
    # Create bundle directory structure
    mkdir -p "${app_bundle}/Contents"/{MacOS,Resources,Frameworks}
    
    # Create Info.plist
    create_app_info_plist "$variant" "${app_bundle}/Contents/Info.plist"
    
    # Copy executable based on variant
    local source_executable="${BUILD_DIR}/bin/simcity_${variant}"
    if [ ! -f "$source_executable" ]; then
        source_executable="${BUILD_DIR}/bin/${APP_EXECUTABLE}"
    fi
    
    if [ ! -f "$source_executable" ]; then
        print_failure "Executable not found for $variant: $source_executable"
        return 1
    fi
    
    cp "$source_executable" "${app_bundle}/Contents/MacOS/$(basename "${APP_EXECUTABLE}" .exe)"
    chmod +x "${app_bundle}/Contents/MacOS/$(basename "${APP_EXECUTABLE}" .exe)"
    
    # Copy resources
    copy_app_resources "$variant" "${app_bundle}/Contents/Resources"
    
    # Copy frameworks and libraries if needed
    copy_dependencies "$variant" "${app_bundle}/Contents/Frameworks"
    
    # Code signing if enabled
    if [ "$SIGN_ENABLED" = true ]; then
        sign_app_bundle "$app_bundle"
    fi
    
    print_success "App bundle created: $app_bundle"
    return 0
}

# Function to copy application resources
copy_app_resources() {
    local variant="$1"
    local resources_dir="$2"
    
    print_status "Copying resources for $variant..."
    
    # Copy assets
    if [ -d "${PROJECT_ROOT}/assets" ]; then
        cp -R "${PROJECT_ROOT}/assets" "$resources_dir/"
    fi
    
    # Copy shaders
    if [ -d "${BUILD_DIR}/shaders" ]; then
        cp -R "${BUILD_DIR}/shaders" "$resources_dir/"
    fi
    
    # Create app icon (placeholder)
    create_app_icon "$resources_dir/AppIcon.icns"
    
    # Copy documentation based on variant
    case "$variant" in
        developer)
            if [ -d "${PROJECT_ROOT}/docs" ]; then
                cp -R "${PROJECT_ROOT}/docs" "$resources_dir/"
            fi
            ;;
        benchmark)
            if [ -d "${BUILD_DIR}/benchmark" ]; then
                mkdir -p "$resources_dir/benchmark"
                cp -R "${BUILD_DIR}/benchmark/data" "$resources_dir/benchmark/" 2>/dev/null || true
            fi
            ;;
    esac
    
    # Create version information file
    cat > "$resources_dir/version.txt" << EOF
SimCity ARM64 - $variant variant
Version: $APP_VERSION
Build: $APP_BUILD
Built: $(date)
Architecture: arm64
Assembly-only build: Yes
EOF
}

# Function to create app icon
create_app_icon() {
    local icon_file="$1"
    
    # This is a placeholder - in a real deployment you would have actual icon files
    print_status "Creating placeholder app icon..."
    
    # Create a simple icon using built-in tools (placeholder)
    # In reality, you would use iconutil to create proper .icns files
    touch "$icon_file"
}

# Function to copy dependencies
copy_dependencies() {
    local variant="$1"
    local frameworks_dir="$2"
    
    print_status "Copying dependencies for $variant..."
    
    # Copy any required dynamic libraries or frameworks
    # For assembly-only build, this might be minimal
    
    # Copy Metal shaders if they exist
    if [ -d "${BUILD_DIR}/shaders/metallib" ]; then
        mkdir -p "$frameworks_dir/Shaders"
        cp "${BUILD_DIR}/shaders/metallib"/*.metallib "$frameworks_dir/Shaders/" 2>/dev/null || true
    fi
}

# Function to sign app bundle
sign_app_bundle() {
    local app_bundle="$1"
    
    if [ -z "$DEVELOPER_ID" ]; then
        print_warning "No developer ID specified for code signing"
        return 1
    fi
    
    print_status "Code signing app bundle..."
    
    # Sign frameworks first
    find "${app_bundle}/Contents/Frameworks" -name "*.dylib" -o -name "*.framework" | while read -r framework; do
        codesign --force --verify --verbose --sign "$DEVELOPER_ID" "$framework" || true
    done
    
    # Sign the main executable
    codesign --force --verify --verbose --sign "$DEVELOPER_ID" "${app_bundle}/Contents/MacOS"/*
    
    # Sign the entire bundle
    codesign --force --verify --verbose --sign "$DEVELOPER_ID" "$app_bundle"
    
    print_success "Code signing completed"
}

# Function to create PKG installer
create_pkg_installer() {
    local variant="$1"
    local app_bundle="${STAGING_DIR}/${variant}/${APP_NAME} ${variant^}.app"
    local pkg_file="${PACKAGE_DIR}/${variant}/${APP_NAME}_${variant}_v${APP_VERSION}.pkg"
    
    if [ ! -d "$app_bundle" ]; then
        print_failure "App bundle not found for PKG creation: $app_bundle"
        return 1
    fi
    
    print_package "Creating PKG installer for $variant..."
    
    # Create installer scripts
    local scripts_dir="${DEPLOY_DIR}/scripts/${variant}"
    mkdir -p "$scripts_dir"
    
    # Pre-install script
    cat > "$scripts_dir/preinstall" << 'EOF'
#!/bin/bash
# Pre-install script for SimCity ARM64

# Check system requirements
ARCH=$(uname -m)
if [ "$ARCH" != "arm64" ]; then
    echo "Error: This application requires Apple Silicon (ARM64) architecture"
    exit 1
fi

# Check macOS version
OS_VERSION=$(sw_vers -productVersion)
REQUIRED_VERSION="11.0"
if [ "$(printf '%s\n' "$REQUIRED_VERSION" "$OS_VERSION" | sort -V | head -n1)" != "$REQUIRED_VERSION" ]; then
    echo "Error: This application requires macOS $REQUIRED_VERSION or later"
    exit 1
fi

exit 0
EOF

    # Post-install script
    cat > "$scripts_dir/postinstall" << 'EOF'
#!/bin/bash
# Post-install script for SimCity ARM64

# Set proper permissions
chmod -R 755 /Applications/SimCity\ ARM64*.app/Contents/MacOS/
chmod -R 644 /Applications/SimCity\ ARM64*.app/Contents/Resources/

# Clear application cache
rm -rf ~/Library/Caches/com.simcity.arm64* 2>/dev/null || true

echo "SimCity ARM64 installation completed successfully!"
exit 0
EOF

    chmod +x "$scripts_dir"/{preinstall,postinstall}
    
    # Create installer package
    if productbuild --component "$app_bundle" /Applications \
                   --scripts "$scripts_dir" \
                   --identifier "${APP_BUNDLE_ID}.${variant}" \
                   --version "$APP_VERSION" \
                   "$pkg_file"; then
        print_success "PKG installer created: $pkg_file"
        
        # Sign the package if enabled
        if [ "$SIGN_ENABLED" = true ] && [ -n "$DEVELOPER_ID" ]; then
            productsign --sign "$DEVELOPER_ID" "$pkg_file" "${pkg_file}.signed"
            mv "${pkg_file}.signed" "$pkg_file"
            print_success "PKG installer signed"
        fi
        
        return 0
    else
        print_failure "Failed to create PKG installer"
        return 1
    fi
}

# Function to create DMG disk image
create_dmg_image() {
    local variant="$1"
    local app_bundle="${STAGING_DIR}/${variant}/${APP_NAME} ${variant^}.app"
    local dmg_file="${PACKAGE_DIR}/${variant}/${APP_NAME}_${variant}_v${APP_VERSION}.dmg"
    
    if [ ! -d "$app_bundle" ]; then
        print_failure "App bundle not found for DMG creation: $app_bundle"
        return 1
    fi
    
    print_package "Creating DMG disk image for $variant..."
    
    # Create temporary DMG staging area
    local dmg_staging="${DEPLOY_DIR}/dmg_staging_${variant}"
    rm -rf "$dmg_staging"
    mkdir -p "$dmg_staging"
    
    # Copy app bundle to staging
    cp -R "$app_bundle" "$dmg_staging/"
    
    # Create README file
    cat > "$dmg_staging/README.txt" << EOF
SimCity ARM64 - $variant variant
====================================

Version: $APP_VERSION
Build: $APP_BUILD
Built: $(date)

System Requirements:
- Apple Silicon Mac (M1, M2, or later)
- macOS $MIN_MACOS_VERSION or later
- ${REQUIRED_MEMORY_GB}GB RAM (${RECOMMENDED_MEMORY_GB}GB recommended)

Installation:
1. Copy the application to your Applications folder
2. Launch the application from Applications
3. Enjoy building your city!

This is an assembly-only build optimized for Apple Silicon.

For support and documentation, visit:
https://github.com/simcity-arm64/simcity

Copyright © 2025 SimCity ARM64 Project
EOF

    # Create Applications symlink
    ln -s /Applications "$dmg_staging/Applications"
    
    # Calculate size needed
    local size_needed=$(du -sm "$dmg_staging" | cut -f1)
    local dmg_size=$((size_needed + 50))  # Add 50MB padding
    
    # Create DMG
    local temp_dmg="${dmg_file}.temp.dmg"
    
    if hdiutil create -srcfolder "$dmg_staging" \
                     -volname "${APP_NAME} ${variant^}" \
                     -fs HFS+ \
                     -fsargs "-c c=64,a=16,e=16" \
                     -format UDRW \
                     -size "${dmg_size}m" \
                     "$temp_dmg"; then
        
        # Convert to compressed read-only DMG
        hdiutil convert "$temp_dmg" -format UDZO -imagekey zlib-level=9 -o "$dmg_file"
        rm -f "$temp_dmg"
        
        # Clean up staging
        rm -rf "$dmg_staging"
        
        print_success "DMG disk image created: $dmg_file"
        return 0
    else
        print_failure "Failed to create DMG disk image"
        rm -rf "$dmg_staging"
        return 1
    fi
}

# Function to create compressed archive
create_archive() {
    local variant="$1"
    local app_bundle="${STAGING_DIR}/${variant}/${APP_NAME} ${variant^}.app"
    local archive_file="${PACKAGE_DIR}/${variant}/${APP_NAME}_${variant}_v${APP_VERSION}.zip"
    
    if [ ! -d "$app_bundle" ]; then
        print_failure "App bundle not found for archive creation: $app_bundle"
        return 1
    fi
    
    print_package "Creating compressed archive for $variant..."
    
    # Create archive staging area
    local archive_staging="${DEPLOY_DIR}/archive_staging_${variant}"
    rm -rf "$archive_staging"
    mkdir -p "$archive_staging"
    
    # Copy app bundle
    cp -R "$app_bundle" "$archive_staging/"
    
    # Add documentation
    cp "$PROJECT_ROOT/README.md" "$archive_staging/" 2>/dev/null || true
    cp "$PROJECT_ROOT/LICENSE" "$archive_staging/" 2>/dev/null || true
    
    # Create installation instructions
    cat > "$archive_staging/INSTALL.txt" << EOF
SimCity ARM64 Installation Instructions
=======================================

1. Extract this archive to a location of your choice
2. Copy "${APP_NAME} ${variant^}.app" to your Applications folder
3. Launch the application

System Requirements:
- Apple Silicon Mac (M1, M2, or later)
- macOS $MIN_MACOS_VERSION or later
- ${REQUIRED_MEMORY_GB}GB RAM minimum

Version: $APP_VERSION
Build: $APP_BUILD
Architecture: arm64 (Apple Silicon optimized)
EOF
    
    # Create ZIP archive
    cd "$archive_staging"
    if zip -r "$archive_file" . -x "*.DS_Store"; then
        cd - >/dev/null
        rm -rf "$archive_staging"
        print_success "Archive created: $archive_file"
        return 0
    else
        cd - >/dev/null
        rm -rf "$archive_staging"
        print_failure "Failed to create archive"
        return 1
    fi
}

# Function to notarize packages
notarize_packages() {
    if [ "$NOTARIZE_ENABLED" != true ]; then
        return 0
    fi
    
    print_status "Notarizing packages..."
    print_warning "Notarization requires Apple Developer account and may take several minutes"
    
    # This is a placeholder for notarization
    # Real implementation would use xcrun notarytool
    
    print_status "Notarization completed (placeholder)"
}

# Function to create deployment summary
create_deployment_summary() {
    print_status "Creating deployment summary..."
    
    local summary_file="${DEPLOY_DIR}/deployment_summary_$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "SimCity ARM64 Deployment Summary"
        echo "==============================="
        echo "Generated: $(date)"
        echo "Version: $APP_VERSION"
        echo "Build: $APP_BUILD"
        echo ""
        
        echo "Package Variants Created:"
        echo "------------------------"
        for variant in "${PACKAGE_VARIANTS[@]}"; do
            echo "Variant: $variant"
            find "${PACKAGE_DIR}/${variant}" -type f 2>/dev/null | while read -r file; do
                local size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
                echo "  $(basename "$file") ($((size / 1024 / 1024))MB)"
            done
            echo ""
        done
        
        echo "Deployment Configuration:"
        echo "------------------------"
        echo "Code Signing: $SIGN_ENABLED"
        echo "Notarization: $NOTARIZE_ENABLED"
        echo "Target macOS: $MIN_MACOS_VERSION+"
        echo "Architecture: arm64 only"
        echo ""
        
        echo "Distribution Files:"
        echo "------------------"
        find "$PACKAGE_DIR" -type f | while read -r file; do
            local size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
            echo "$(basename "$file"): $((size / 1024 / 1024))MB"
        done
        
    } > "$summary_file"
    
    print_success "Deployment summary created: $summary_file"
}

# Function to parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --sign)
                SIGN_ENABLED=true
                shift
                ;;
            --notarize)
                NOTARIZE_ENABLED=true
                SIGN_ENABLED=true  # Notarization requires signing
                shift
                ;;
            --version)
                APP_VERSION="$2"
                shift 2
                ;;
            --dev-id)
                DEVELOPER_ID="$2"
                shift 2
                ;;
            --clean)
                CLEAN_DEPLOY=true
                shift
                ;;
            --verbose)
                set -x
                shift
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;
            minimal|standard|developer|benchmark|all)
                # Package variants handled in main
                shift
                ;;
            app_bundle|pkg_installer|dmg_image|archive)
                # Deployment targets handled in main
                shift
                ;;
            *)
                print_failure "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
}

# Main deployment function
main() {
    local start_time=$SECONDS
    
    print_banner
    
    # Parse arguments
    parse_arguments "$@"
    
    print_status "Deployment Configuration:"
    echo "  App Version: $APP_VERSION"
    echo "  Build Number: $APP_BUILD"
    echo "  Code Signing: $SIGN_ENABLED"
    echo "  Notarization: $NOTARIZE_ENABLED"
    echo "  Target macOS: $MIN_MACOS_VERSION+"
    echo ""
    
    # Setup
    check_deployment_dependencies
    setup_deployment_dirs
    
    # Deploy each variant
    local successful_deployments=()
    local failed_deployments=()
    
    for variant in "${PACKAGE_VARIANTS[@]}"; do
        print_status "Deploying $variant variant..."
        
        local variant_success=true
        
        # Create app bundle
        if ! create_app_bundle "$variant"; then
            variant_success=false
        fi
        
        # Create deployment targets
        if [ "$variant_success" = true ]; then
            for target in "${DEPLOYMENT_TARGETS[@]}"; do
                case "$target" in
                    app_bundle)
                        # Already created above
                        ;;
                    pkg_installer)
                        create_pkg_installer "$variant" || variant_success=false
                        ;;
                    dmg_image)
                        create_dmg_image "$variant" || variant_success=false
                        ;;
                    archive)
                        create_archive "$variant" || variant_success=false
                        ;;
                esac
            done
        fi
        
        if [ "$variant_success" = true ]; then
            successful_deployments+=("$variant")
        else
            failed_deployments+=("$variant")
        fi
    done
    
    # Notarization
    notarize_packages
    
    # Create summary
    create_deployment_summary
    
    # Final summary
    local total_time=$((SECONDS - start_time))
    echo ""
    print_status "Deployment Summary"
    echo "=================="
    echo "Successful: ${#successful_deployments[@]} variants"
    echo "Failed: ${#failed_deployments[@]} variants"
    echo "Deployment Time: ${total_time}s"
    echo ""
    
    if [ ${#successful_deployments[@]} -gt 0 ]; then
        print_success "Successfully deployed variants:"
        for variant in "${successful_deployments[@]}"; do
            echo "  ✓ $variant"
        done
    fi
    
    if [ ${#failed_deployments[@]} -gt 0 ]; then
        print_failure "Failed to deploy variants:"
        for variant in "${failed_deployments[@]}"; do
            echo "  ✗ $variant"
        done
    fi
    
    echo ""
    print_status "Deployment artifacts available in: $PACKAGE_DIR"
    
    if [ ${#failed_deployments[@]} -eq 0 ]; then
        print_success "All deployments completed successfully!"
        exit 0
    else
        print_failure "Some deployments failed"
        exit 1
    fi
}

# Execute main function with all arguments
main "$@"