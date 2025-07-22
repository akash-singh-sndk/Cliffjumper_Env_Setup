#!/bin/bash

################################################################################
# CVF Linux Migration Environment Setup Script
# Setup includes Meson + Clang + Linux Migration
# 
# This script creates a complete development environment for migrating
# Windows Visual Studio projects to Linux using Meson + Clang
#
# Usage: ./setupDevEnv.sh [OPTIONS] [PYTHON_VERSION] [BOOST_VERSION]
#
# Author:    Akash Kumar Singh
# Email:     akash.singh@sandisk.com
################################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_PYTHON_VERSION="3.8.10"
DEFAULT_BOOST_VERSION="1.82.0"

# Suppress pip root user warnings globally
export PIP_ROOT_USER_ACTION=ignore

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "${GREEN}[$(date '+%H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
}

info() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

migration_info() {
    echo -e "${PURPLE}[MIGRATION] $1${NC}"
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check system requirements for Linux migration
check_migration_requirements() {
    log "Checking Linux migration requirements..."
    
    # Check if we're on Linux
    if [[ "$OSTYPE" != "linux-gnu"* ]]; then
        error "This script is designed for Linux systems only"
        exit 1
    fi
    
    # Check for essential tools
    local missing_tools=()
    
    if ! command_exists wget && ! command_exists curl; then
        missing_tools+=("wget or curl")
    fi
    
    if ! command_exists tar; then
        missing_tools+=("tar")
    fi
    
    if ! command_exists make; then
        missing_tools+=("make")
    fi
    
    # Check for Clang instead of GCC
    if ! command_exists clang; then
        missing_tools+=("clang")
    fi
    
    if ! command_exists clang++; then
        missing_tools+=("clang++")
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        error "Missing required tools for Linux migration: ${missing_tools[*]}"
        if [ "$EUID" -ne 0 ]; then
            info "Please run this script as root (sudo) to auto-install missing packages."
            info "Or install manually using your package manager:"
            info "  Ubuntu/Debian: sudo apt-get install wget tar make clang clang++ build-essential libssl-dev libffi-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev"
            info "  RHEL/AlmaLinux: dnf install -y wget tar make clang openssl-devel libffi-devel zlib-devel bzip2-devel readline-devel sqlite-devel ncurses-devel xz-devel glibc-devel"
            exit 1
        fi
        # Detect package manager and install
        if command -v apt-get >/dev/null 2>&1; then
            info "Installing missing packages with apt-get..."
            apt-get update
            apt-get install -y wget tar make clang clang++ build-essential libssl-dev libffi-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev
        elif command -v dnf >/dev/null 2>&1; then
            info "Installing missing packages with dnf..."
            dnf install -y wget tar make clang openssl-devel libffi-devel zlib-devel bzip2-devel readline-devel sqlite-devel ncurses-devel xz-devel glibc-devel
        elif command -v yum >/dev/null 2>&1; then
            info "Installing missing packages with yum..."
            yum install -y wget tar make clang openssl-devel libffi-devel zlib-devel bzip2-devel readline-devel sqlite-devel ncurses-devel xz-devel glibc-devel
        else
            error "No supported package manager found. Please install required packages manually."
            exit 1
        fi
        log "All required system packages installed."
    fi
    
    # Check for Meson
    if ! command_exists meson; then
        warn "Meson not found - will be installed via pip"
    else
        local meson_version=$(meson --version)
        info "Found Meson version: $meson_version"
    fi
    
    # Check for Ninja
    if ! command_exists ninja; then
        warn "Ninja not found - will be installed via pip"
    else
        local ninja_version=$(ninja --version)
        info "Found Ninja version: $ninja_version"
    fi
    
    log "Linux migration requirements check passed"
}

# Download and build Python from source with Clang
install_python() {
    local python_version="${1:-$DEFAULT_PYTHON_VERSION}"
    local python_major_minor=$(echo "$python_version" | cut -d. -f1,2)
    local python_build_dir="/tmp/cvf_python_build"
    local python_root="/opt/cvf/python$python_version"
    
    if [ -f "$python_root/bin/python3" ]; then
        local installed_version=$("$python_root/bin/python3" --version 2>&1 | cut -d' ' -f2)
        if [ "$installed_version" = "$python_version" ]; then
            log "Python $python_version already installed at $python_root"
            return 0
        fi
    fi
    
    migration_info "Building Python $python_version from source with Clang..."

    # Install required build dependencies for RHEL/CentOS/AlmaLinux
    if [ -f /etc/redhat-release ]; then
        info "Installing required development tools and libraries (YUM/DNF)..."
        if command -v dnf >/dev/null 2>&1; then
            dnf groupinstall -y "Development Tools"
            dnf install -y clang clang-devel clang-tools-extra \
                libffi-devel zlib-devel b zip2-devel openssl-devel \
                ncurses-devel sqlite-devel readline-devel tk-devel xz-devel \
                glibc-devel glibc-devel.i686 wget curl make tar
        else
            yum groupinstall -y "Development Tools"
            yum install -y clang clang-devel \
                libffi-devel zlib-devel bzip2-devel openssl-devel \
                ncurses-devel sqlite-devel readline-devel tk-devel xz-devel \
                glibc-devel glibc-devel.i686 wget curl make tar
        fi
    fi
    
    # Create build directory
    mkdir -p "$python_build_dir"
    cd "$python_build_dir"
    
    # Download Python source if not exists
    if [ ! -f "Python-$python_version.tgz" ]; then
        log "Downloading Python $python_version source..."
        if command -v wget >/dev/null 2>&1; then
            wget "https://www.python.org/ftp/python/$python_version/Python-$python_version.tgz"
        elif command -v curl >/dev/null 2>&1; then
            curl -O "https://www.python.org/ftp/python/$python_version/Python-$python_version.tgz"
        else
            error "Neither wget nor curl found"
            exit 1
        fi
    fi
    
    # Extract and build
    if [ -d "Python-$python_version" ]; then
        rm -rf "Python-$python_version"
    fi
    
    log "Extracting Python source..."
    tar -xzf "Python-$python_version.tgz"
    cd "Python-$python_version"
    
    # Configure with Clang
    export CC=clang
    export CXX=clang++
    export CFLAGS="-O2 -fPIC"
    export CXXFLAGS="-O2 -fPIC"
    
    log "Configuring Python build with Clang..."
    ./configure \
        --prefix="$python_root" \
        --enable-shared \
        --enable-optimizations \
        --with-lto \
        --with-computed-gotos \
        --with-system-ffi \
        --enable-loadable-sqlite-extensions
    
    # Build and install
    log "Building Python (this may take 10-15 minutes)..."
    make -j$(nproc)
    
    log "Installing Python to $python_root..."
    make install
    
    # Update shared library cache
    echo "$python_root/lib" > /etc/ld.so.conf.d/cvf-python.conf
    ldconfig
    
    log "Python $python_version built and installed successfully with Clang"
}

# Install Meson and build tools
install_build_tools() {
    local python_version="${1:-$DEFAULT_PYTHON_VERSION}"
    local python_root="/opt/cvf/python$python_version"
    
    migration_info "Installing Meson build system and tools..."
    
    # Use the custom Python installation
    "$python_root/bin/python3" -m pip install --upgrade pip
    
    # Install Meson and Ninja
    "$python_root/bin/python3" -m pip install meson ninja
    
    # Install additional development tools
    "$python_root/bin/python3" -m pip install pkgconfig conan cmake wheel setuptools
    
    log "Build tools installed successfully"
}

# Download and build Boost from source with Clang and Python support
install_boost() {
    local python_version="${1:-$DEFAULT_PYTHON_VERSION}"
    local boost_version="${2:-$DEFAULT_BOOST_VERSION}"
    local boost_underscore=$(echo "$boost_version" | sed 's/\./_/g')
    local boost_build_dir="/tmp/cvf_boost_build"
    local boost_root="/opt/cvf/boost_$boost_underscore"
    local archive_dir="/opt/cvf/archives"
    local boost_archive="$archive_dir/boost_$boost_underscore.tar.gz"
    local python_root="/opt/cvf/python$python_version"
    local python_major_minor=$(echo "$python_version" | cut -d. -f1,2)
    
    if [ -f "$boost_root/include/boost/version.hpp" ]; then
        local installed_version=$(grep "#define BOOST_VERSION " "$boost_root/include/boost/version.hpp" | awk '{print $3}')
        local expected_version_num=$(echo "$boost_version" | awk -F. '{print $1*100000 + $2*1000 + $3*10}')
        
        if [ "$installed_version" = "$expected_version_num" ]; then
            if [ -f "$boost_root/lib/libboost_python${python_major_minor//./}.so" ] || [ -f "$boost_root/lib/libboost_python${python_major_minor//./}.a" ]; then
                log "Boost $boost_version with Python $python_version support already installed at $boost_root"
                return 0
            fi
        fi
    fi
    
    migration_info "Building Boost $boost_version from source with Clang and Python $python_version support..."
    
    # Create build and archive directories
    mkdir -p "$boost_build_dir"
    mkdir -p "$archive_dir"
    cd "$boost_build_dir"
    
    # Check if Boost source already exists to skip download
    if [ -d "boost_$boost_underscore" ]; then
        log "Boost $boost_version source already exists at $boost_build_dir/boost_$boost_underscore, skipping download and extraction."
    else
        # Download Boost source if not exists or if archive is corrupted
        need_download=false
        if [ -f "$boost_archive" ]; then
            log "Found existing Boost archive at $boost_archive, verifying integrity..."
            if ! tar -tzf "$boost_archive" &>/dev/null; then
                warn "Existing Boost archive is corrupted, will re-download."
                rm -f "$boost_archive"
                need_download=true
            fi
        else
            need_download=true
        fi
        if [ "$need_download" = true ]; then
            log "Downloading Boost $boost_version source to $boost_archive..."
            local boost_urls=(
                "https://github.com/boostorg/boost/releases/download/boost-$boost_version/boost_$boost_underscore.tar.gz"
                "https://archives.boost.io/release/$boost_version/source/boost_$boost_underscore.tar.gz"
                "https://downloads.sourceforge.net/project/boost/boost/$boost_version/boost_$boost_underscore.tar.gz"
            )
            local downloaded=false
            for boost_url in "${boost_urls[@]}"; do
                log "Trying: $boost_url"
                if command -v wget >/dev/null 2>&1; then
                    if wget --timeout=30 --tries=2 "$boost_url" -O "$boost_archive" 2>/dev/null; then
                        downloaded=true
                        break
                    fi
                elif command -v curl >/dev/null 2>&1; then
                    if curl --connect-timeout 30 --max-time 300 -L "$boost_url" -o "$boost_archive" 2>/dev/null; then
                        downloaded=true
                        break
                    fi
                fi
                # Only delete if the download failed and the file is corrupted
                if [ -f "$boost_archive" ] && ! tar -tzf "$boost_archive" &>/dev/null; then
                    rm -f "$boost_archive" 2>/dev/null
                fi
            done
            if [ "$downloaded" = false ]; then
                error "Failed to download Boost from any mirror"
                exit 1
            fi
        fi
        # Final integrity check before extraction
        if ! tar -tzf "$boost_archive" &>/dev/null; then
            error "Downloaded Boost archive is corrupted. Aborting."
            exit 1
        fi
        log "Extracting Boost source from $boost_archive..."
        tar -xzf "$boost_archive"
    fi
    
    cd "boost_$boost_underscore"
    
    # Bootstrap Boost with custom Python and Clang
    log "Bootstrapping Boost with Python $python_version and Clang..."
    ./bootstrap.sh \
        --with-toolset=clang \
        --with-python="$python_root/bin/python3" \
        --with-python-version="$python_major_minor" \
        --with-python-root="$python_root" \
        --prefix="$boost_root"
    
    # Build Boost with Clang
    log "Building Boost with Clang and Python $python_version support (this may take 20-30 minutes)..."
    ./b2 \
        toolset=clang \
        --prefix="$boost_root" \
        --with-python \
        --with-system \
        --with-thread \
        --with-filesystem \
        --with-program_options \
        --with-regex \
        --with-serialization \
        --with-date_time \
        --with-chrono \
        python="$python_major_minor" \
        include="$python_root/include/python$python_major_minor" \
        cxxflags="-I$python_root/include/python$python_major_minor -std=c++17 -O3 -fPIC" \
        linkflags="-L$python_root/lib" \
        variant=release \
        link=shared \
        threading=multi \
        runtime-link=shared \
        cxxstd=17 \
        -j$(nproc) \
        install
    
    log "Boost $boost_version built and installed successfully with Clang and Python $python_version"
}

# Create environment activation script
create_environment_script() {
    local python_version="${1:-$DEFAULT_PYTHON_VERSION}"
    local boost_version="${2:-$DEFAULT_BOOST_VERSION}"
    local boost_underscore=$(echo "$boost_version" | sed 's/\./_/g')
    local python_major_minor=$(echo "$python_version" | cut -d. -f1,2)
    local env_script="$SCRIPT_DIR/activate_env.sh"
    local python_root="/opt/cvf/python$python_version"
    local boost_root="/opt/cvf/boost_$boost_underscore"
    
    log "Creating CVF migration environment script: $env_script"
    
    cat > "$env_script" << ENV_EOF
#!/bin/bash

# Author:    Akash Kumar Singh
# Email:     akash.singh@sandisk.com

# CVF Linux Migration Environment - Python $python_version + Boost $boost_version

# Professional color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

export CVF_ROOT="/opt/cvf"
export PYTHON_ROOT="$python_root"
export BOOST_ROOT="$boost_root"

# Update PATH to use custom Python $python_version
export PATH="\$PYTHON_ROOT/bin:\$PATH"

# Compiler setup for migration
export CC=clang
export CXX=clang++
export CFLAGS="-O2 -fPIC"
export CXXFLAGS="-O2 -fPIC -std=c++17"

# Library paths
export LD_LIBRARY_PATH="\$PYTHON_ROOT/lib:\$BOOST_ROOT/lib:\$LD_LIBRARY_PATH"
export PKG_CONFIG_PATH="\$PYTHON_ROOT/lib/pkgconfig:\$BOOST_ROOT/lib/pkgconfig:\$PKG_CONFIG_PATH"

# Python paths
export PYTHONPATH="\$BOOST_ROOT/lib/python$python_major_minor/site-packages:\$BOOST_ROOT/lib:\$PYTHONPATH"

# CMake/Meson configuration
export CMAKE_PREFIX_PATH="\$PYTHON_ROOT:\$BOOST_ROOT:\$CMAKE_PREFIX_PATH"
export CMAKE_C_COMPILER=clang
export CMAKE_CXX_COMPILER=clang++

# Boost-specific variables
export BOOST_INCLUDEDIR="\$BOOST_ROOT/include"
export BOOST_LIBRARYDIR="\$BOOST_ROOT/lib"

# Meson and Ninja from custom Python
export MESON="\$PYTHON_ROOT/bin/meson"
export NINJA="\$PYTHON_ROOT/bin/ninja"

echo -e "${YELLOW}🚀 CVF Linux Migration Environment Activated!${NC}"
echo -e "${BLUE}=============================================${NC}"
echo -e "${GREEN}  Python: \$(python3 --version) at \$PYTHON_ROOT${NC}"
echo -e "${GREEN}  Boost: $boost_version at \$BOOST_ROOT${NC}"
echo -e "${GREEN}  Compiler: Clang (\$(clang --version | head -1))${NC}"
echo -e "${GREEN}  Build System: Meson (\$($MESON --version))${NC}"
echo -e "${GREEN}  Build Backend: Ninja (\$($NINJA --version))${NC}"
echo ""
echo -e "${BLUE}🔧 Verification Commands:${NC}"
echo "  python3 --version"
echo "  meson --version"
echo "  ninja --version" 
echo "  clang --version"
echo "  ls \$BOOST_ROOT/lib/libboost_python${python_major_minor//./}.*"
echo ""
echo -e "${GREEN}🎯 Ready for Visual Studio → Linux migration!${NC}"
echo -e "${GREEN}   Use: meson setup builddir && ninja -C builddir${NC}"
ENV_EOF
    
    chmod +x "$env_script"
    log "Environment script created: $env_script"
}

# Main installation function
install_migration_environment() {
    local python_version="${1:-$DEFAULT_PYTHON_VERSION}"
    local boost_version="${2:-$DEFAULT_BOOST_VERSION}"
    local python_build_dir="/tmp/cvf_python_build"
    local boost_build_dir="/tmp/cvf_boost_build"
    
    log "Starting CVF Linux Migration Environment Installation"
    migration_info "Building Python $python_version + Boost $boost_version with Clang from source"
    info "This process may take 30-45 minutes for complete build"
    echo
    
    # Create CVF directory structure
    mkdir -p /opt/cvf
    
    # Install components in order
    log "Phase 1/4: Installing Python $python_version from source..."
    install_python "$python_version"
    
    log "Phase 2/4: Installing Meson and build tools..."
    install_build_tools "$python_version"
    
    log "Phase 3/4: Installing Boost $boost_version from source..."
    install_boost "$python_version" "$boost_version"
    
    log "Phase 4/4: Creating environment scripts..."
    create_environment_script "$python_version" "$boost_version"
    
    # Cleanup build directories
    log "Cleaning up build directories..."
    rm -rf "$python_build_dir" "$boost_build_dir"
    
    echo
    log "🎉 CVF Migration Environment Installation Complete!"
    echo "=================================================="
    info "Installation Summary:"
    echo "  ✅ Python $python_version built with Clang at /opt/cvf/python$python_version"
    echo "  ✅ Boost $boost_version built with Clang and Python $python_version at /opt/cvf/boost_$(echo "$boost_version" | sed 's/\./_/g')"
    echo "  ✅ Meson + Ninja build system installed"
    echo "  ✅ Environment activation script created"
    echo
    info "To activate the migration environment:"
    echo "  source activate_env.sh"
    echo
    info "To verify installation:"
    echo "  source activate_env.sh"
    echo "  python3 --version  # Should show Python $python_version"
    echo "  meson --version    # Should show Meson version"
    echo "  ls \$BOOST_ROOT/lib/libboost_python${python_major_minor//./}.*  # Should show Boost.Python"
    echo
    migration_info "🚀 Ready to start migrating Visual Studio projects to Linux!"
    echo "Next steps: meson setup builddir && ninja -C builddir"
}

# Main execution function
main() {
    local python_version="${1:-$DEFAULT_PYTHON_VERSION}"
    local boost_version="${2:-$DEFAULT_BOOST_VERSION}"
    
    log "CVF Linux Migration Environment Setup"
    migration_info "Target: Windows Visual Studio → Linux Meson + Clang"
    info "Python: $python_version, Boost: $boost_version"
    echo
    
    # Check if running as root
    if [ "$EUID" -ne 0 ]; then
        error "This script must be run as root (use sudo)"
        exit 1
    fi
    
    case "${3:-install}" in
        install)
            check_migration_requirements
            install_migration_environment "$python_version" "$boost_version"
            ;;
        *)
            error "Invalid action. Use --install to install the environment or --check-system to check requirements."
            show_usage
            exit 1
            ;;
    esac
}

# Show usage function
show_usage() {
    cat << EOF
CVF Linux Migration Environment Setup Script

This script creates a complete development environment for migrating
Windows Visual Studio projects to Linux using Meson + Clang.

Usage: $0 [OPTIONS] [PYTHON_VERSION] [BOOST_VERSION]

OPTIONS:
    --help, -h              Show this help message
    --check-system          Check system requirements for migration
    --install               Install the migration environment

MIGRATION FEATURES:
    - Python with Clang compiler
    - Boost built with Clang + Python support  
    - Meson build system
    - Ninja build backend
    - Cross-platform development libraries

EXAMPLES:
    $0 --check-system       # Check if system is ready
    $0 --install            # Install complete migration environment
    $0 --install 3.9.10 1.83.0  # Install with custom Python and Boost versions

EOF
}

# Parse arguments
case "${1:-}" in
    --help|-h)
        show_usage
        exit 0
        ;;
    --check-system)
        check_migration_requirements
        exit 0
        ;;
    --install)
        shift
        main "${1:-$DEFAULT_PYTHON_VERSION}" "${2:-$DEFAULT_BOOST_VERSION}" "install"
        ;;
    *)
        main "$DEFAULT_PYTHON_VERSION" "$DEFAULT_BOOST_VERSION" "install"
        ;;
esac
