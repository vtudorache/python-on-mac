# Building Python from sources on recent macOS

## Foreword

The method presented here performs a classical UNIX-style Python installation from source. It can be used when an optimized interpreter or an API compatible with the installed C toolchain is required. This method uses the Command Line Tools provided by Apple. The tools are already on the system for those having installed Xcode (a second download isn't required). The structure of the framework is similar to the one available at [python.org](https://www.python.org/downloads/macos/) but the binaries are single architecture (aarch64 or x86_64) and optimized by default (built with `--enable-optimizations` flag). The framework is built in-place (administrator rights are required, see below).

Note: Respect the laws concerning cryptography in your country before downloading and installing OpenSSL. There are regions in the world where cryptography software (or event talking about) is forbidden. Ask a lawyer about your rights and/or restrictions, I'm not liable for any violations you make. Be careful, it's _your_ responsibility.

## 1. Obtaining the Command Line Tools

Check that clang works. Open the application Terminal (or the equivalent you like) and enter:
```sh
clang -v
```
If the toolchain is installed, an informational message like the one below (taken on a recent macOS) will be shown.
```sh
Apple clang version 15.0.0 (clang-1500.3.9.4)
Target: arm64-apple-darwin23.5.0
Thread model: posix
InstalledDir: /Library/Developer/CommandLineTools/usr/bin
```
If no toolchain is installed, the command above will trigger a dialog requiring the installation of Xcode or Command Line Tools. Alternatively, the tools can be installed with the command:
```sh
xcode-select --install
```
If the tools are already installed, the following message will be displayed:
```sh
xcode-select: error: command line tools are already installed, use "Software Update" to install updates
```
Once the compilation tools are installed, prepare the environment for building.

## 2. Preparing the environment

Set the compiler to be used:
```sh
export CC=clang CXX=clang
```

For speed reasons I usually do the build on a RAM disk. This also avoids excessive writing on the SSD. A size of 2 GB will be enough. The memory left for the OS and the running applications must be at least 2 GB, so for those not having enough RAM installed (4 GB at least), a directory on the physical disk must be used instead. The size of the RAM disk can't be reduced too much, otherwise several Python tests will fail (at the post-build phase).

Create the environment variable `PYTHON_VERSION` to hold the full version number of Python (like `3.12.3`) to be installed:
```sh
PYTHON_VERSION=3.12.3
```
Create the environment variable `FRAMEWORK_NAME` to hold the name of the framework. I set this to `Python` by default, with the command below:
```sh
FRAMEWORK_NAME=Python
```

Create an environment variable holding the name of the build, based on the current date and time.
```sh
BUILD_NAME="Python_${PYTHON_VERSION}_$(date +%Y%m%d%H%M%S)"
```
If using a RAM disk, the following commands will create a 2 GB RAM disk (the size is given as the number of sectors of 512 bytes) and mount it at `/Volumes/$BUILD_NAME` (the icon of the mounted volume will show on desktop), then set the environment variable `BUILD_PATH` to the build directory:
```sh
diskutil erasevolume HFS+ $BUILD_NAME $(hdiutil attach -nomount ram://4194304)
BUILD_PATH=/Volumes/$BUILD_NAME
```
Otherwise, if not using a RAM disk, set the environment variable `BUILD_PATH` to a temporary folder:
```sh
BUILD_PATH=/private/tmp/$BUILD_NAME
mkdir -p "$BUILD_PATH"
```
The environment variable `FRAMEWORK_VERSION` holding the version of the framework (like `3.12`) will be automatically created by the following command:
```sh
FRAMEWORK_VERSION=$(echo $PYTHON_VERSION | cut -f 1,2 -d .)
```
The environment variable `FRAMEWORK_PATH` will hold the full directory name of the framework. This variable will give the installation prefix for Python's dependencies. It is set with the following command:
```sh
FRAMEWORK_PATH=/Library/Frameworks/$FRAMEWORK_NAME.framework/Versions/$FRAMEWORK_VERSION
```
Record the current directory:
```sh
INITIAL_PATH=$(pwd)
```

## 3. Installing dependencies

### 3.1. Installing Tcl/Tk 8.6.13

Tcl/Tk will be installed in `$FRAMEWORK_PATH`, just like the official installer from [python.org](https://www.python.org). There have been issues with some older version of Tk when the dark mode was introduced on macOS. With Tcl/Tk 8.6.13 all seems right, I didn't notice serious issues.

Change to the building directory, download and unpack Tcl/Tk from [sourceforge.net](https://downloads.sourceforge.net/tcl/) using the `curl` command available by default on macOS:
```sh
cd "$BUILD_PATH"
curl -L https://downloads.sourceforge.net/tcl/tcl8.6.13-src.tar.gz | tar -xf -
curl -L https://downloads.sourceforge.net/tcl/tk8.6.13-src.tar.gz | tar -xf -
```
Pay attention at download errors. If any error occurs, the source subdirectories will be partial. Delete the partially downloaded sources then repeat the download command(s) shown above.  
The extra packages (in the `pkgs` directory of the Tcl source tree) are not needed. Remove them, then configure, build and install Tcl and Tk:
```sh
cd tcl8.6.13/unix
rm -rf ../pkgs/*
./configure                     \
    --enable-shared             \
    --enable-threads            \
    --prefix="$FRAMEWORK_PATH"
make && sudo make install-strip install-binaries install-headers install-libraries install-msgs
cd ../../tk8.6.13/unix
./configure                     \
    --enable-aqua               \
    --enable-shared             \
    --enable-threads            \
    --prefix="$FRAMEWORK_PATH"  \
    --without-x
make && sudo make install-strip install-binaries install-headers install-libraries
```
The environment variable `TCLTK_LIBS` will hold the libraries needed for linking Tcl/Tk with Python.
```sh
TCLTK_LIBS="-ltcl8.6 -ltclstub8.6 -lz -lpthread -framework CoreFoundation -ltk8.6 -ltkstub8.6"
```

### 3.2. Installing XZ tools 5.4.6 (provides LZMA library)

Download and unpack XZ tools from [sourceforge.net](https://sourceforge.net/projects/lzmautils/files/) using `curl`:
```sh
cd "$BUILD_PATH"
curl -L https://sourceforge.net/projects/lzmautils/files/xz-5.4.6.tar.gz | tar -xf -
```
Configure, build and install XZ tools.
```sh
cd xz-5.4.6
./configure                     \
    --disable-doc               \
    --disable-nls               \
    --prefix="$FRAMEWORK_PATH"
make && sudo make install
```

### 3.3. Installing GDBM 1.23

Download and unpack GDBM from [sourceforge.net](https://ftp.gnu.org/gnu/gdbm/) using `curl`:
```sh
cd "$BUILD_PATH"
curl -L https://ftp.gnu.org/gnu/gdbm/gdbm-1.23.tar.gz | tar -xf -
```
Configure, build and install GDBM:
```sh
cd gdbm-1.23
./configure                     \
    --disable-nls               \
    --prefix="$FRAMEWORK_PATH"  \
    --without-readline
make && sudo make install
```

### 3.4. Installing OpenSSL 3.0.13

Download and unpack OpenSSL from [openssl.org](https://www.openssl.org/source/) using `curl`:
```sh
cd "$BUILD_PATH"
curl -L https://www.openssl.org/source/openssl-3.0.13.tar.gz | tar -xf -
```
Configure, build and install OpenSSL. Only the libraries, the configuration files and the headers are needed.
```sh
cd openssl-3.0.13
perl Configure                                  \
    --openssldir="$FRAMEWORK_PATH/etc/openssl"  \
    --prefix="$FRAMEWORK_PATH"                  \
    no-engine                                   \
    no-legacy                                   \
    no-module
make && sudo make install_dev install_ssldirs
```

Remove the `bin`, `lib/pkgconfig`, `man` and `share` directories (for now they contain dependencies):
```sh
sudo rm -fr "$FRAMEWORK_PATH/bin" "$FRAMEWORK_PATH/lib/pkgconfig" "$FRAMEWORK_PATH/man" "$FRAMEWORK_PATH/share"
```

## 4. Installing Python

Download and unpack Python from [python.org](https://www.python.org/ftp/python/) using `curl`:
```sh
cd "$BUILD_PATH"
curl -L https://www.python.org/ftp/python/$PYTHON_VERSION/Python-$PYTHON_VERSION.tar.xz | tar -xf -
```
Configure and build Python:
```sh
cd Python-$PYTHON_VERSION
./configure                                         \
    --enable-framework                              \
    --enable-optimizations                          \
    --with-framework-name=$FRAMEWORK_NAME           \
    --with-openssl="$FRAMEWORK_PATH"                \
    GDBM_CFLAGS="-I$FRAMEWORK_PATH/include"         \
    GDBM_LIBS="-L$FRAMEWORK_PATH/lib -lgdbm"        \
    LIBLZMA_CFLAGS="-I$FRAMEWORK_PATH/include"      \
    LIBLZMA_LIBS="-L$FRAMEWORK_PATH/lib -llzma"     \
    TCLTK_CFLAGS="-I$FRAMEWORK_PATH/include"        \
    TCLTK_LIBS="-L$FRAMEWORK_PATH/lib $TCLTK_LIBS"
make && sudo make install
```
Clean the framework's include directory, keeping only the link to Python's headers:
```sh
cd "$FRAMEWORK_PATH/include"
for NAME in $(ls) ; do
  if [ "$NAME" != "python$FRAMEWORK_VERSION" ] ; then
    sudo rm -fr "$NAME"
  fi
done
```
Clean the `lib` directory, removing static libraries, Tcl and Tk shell scripts and C source files:
```sh
cd "$FRAMEWORK_PATH/lib"
sudo rm -f *.a *.la *.sh
sudo rm -f tcl8.6/tclAppInit.c
sudo rm -f tk8.6/tkAppInit.c
sudo rm -fr tk8.6/demos
```
Clean the building directory and return to the initial directory:
```sh
cd "$BUILD_PATH"
sudo rm -rf *
cd "$INITIAL_PATH"
```
Now the RAM disk used for building (if one exists) can be unmounted:
if [ -d /Volumes/$BUILD_NAME ] ; then
    diskutil unmount /Volumes/$BUILD_NAME
fi
