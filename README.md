# CVF Linux Migration Environment Setup

Follow this readme inorder to understand how to use the `setupDevEnv.sh` script to set up a complete development environment for migrating Windows Visual Studio projects to Linux using Meson + Clang. Follow the steps below in order for a successful setup.

### Note: Estimated time 30-45 minutes for complete setup configuration. Python downloading may feel like stucked around 62%, please don't terminate that, its AlmaLinux bug

## Prerequisites
- Linux system (Ubuntu, Debian, RHEL, AlmaLinux, etc.)
- Root privileges (run with `sudo`)
- Internet connection (for downloading dependencies)

## Step-by-Step Setup

### 1. Clone the Repository
Clone or download the repository containing `setupDevEnv.sh` and related files.

### 2. Install System Dependencies
The script will check for required tools and install automatically. If any are missing, or you can install them using your package manager manually:

**Ubuntu/Debian:**
```bash
sudo apt-get install wget tar make clang clang++ build-essential libssl-dev libffi-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev
```
**RHEL/AlmaLinux:**
```bash
sudo dnf install -y wget tar make clang openssl-devel libffi-devel zlib-devel bzip2-devel readline-devel sqlite-devel ncurses-devel xz-devel glibc-devel
```

### 3. Run the Setup Script
Run the script as root:
```bash
sudo ./setupDevEnv.sh (default python 3.8.10 & Boost 1.82.0)
OR
sudo ./setupDevEnv.sh --install [PYTHON_VERSION] [BOOST_VERSION]
```
- `[PYTHON_VERSION]` (optional): Specify Python version (default: 3.8.10)
- `[BOOST_VERSION]` (optional): Specify Boost version (default: 1.82.0)

Example:
```bash
sudo ./setupDevEnv.sh --install 3.8.10 1.82.0
```

### 4. Script Execution Phases
The script will perform the following steps in sequence:

1. **Check System Requirements**
   - Verifies required tools (wget/curl, tar, make, clang, clang++, meson, ninja)
2. **Install Python**
   - Downloads and builds the specified Python version from source using Clang
   - Installs to `/opt/cvf/python<version>`
3. **Install Meson and Build Tools**
   - Installs Meson, Ninja, and other Python build tools using the custom Python
4. **Install Boost**
   - Downloads and builds the specified Boost version from source with Clang and Python support
   - Installs to `/opt/cvf/boost_<version>`
   - Boost archive is stored persistently in `/opt/cvf/archives/`
5. **Create Environment Activation Script**
   - Generates `activate_env.sh` in the script directory
   - Sets up environment variables for Python, Boost, compiler, and build tools
6. **Cleanup**
   - Removes temporary build directories

### 5. Activate the Environment
After installation, activate the environment:
```bash
source activate_env.sh
```
This sets up all required environment variables for migration and development.

### 6. Verify Installation
Run the following commands to verify:
```bash
python3 --version      # Should show the installed Python version
meson --version        # Should show Meson version
ls $BOOST_ROOT/lib/libboost_python*  # Should show Boost.Python library
```

### 7. Start Migration/Development
You are now ready to migrate Visual Studio projects to Linux:
```bash
meson setup builddir && ninja -C builddir
```

## Additional Notes
- The script supports custom Python and Boost versions.
- All build artifacts and archives are stored in `/opt/cvf/`.
- For troubleshooting, check the log output for errors or missing dependencies.

---
**Author:** Akash Kumar Singh  
**Email:** akash.singh@sandisk.com
