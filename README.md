# Building Python from sources on recent macOS

## Foreword

The method presented below is a conventional way of installing software from source the way it's done on classical UNIX systems. It is used by the author of this text since the days of OS X 10.8 when a compatible API with the installed toolchain is required.
This method is not using full Xcode (since it doesn't build an installer) but the Command Line Tools provided by Apple. These tools are already on the system for those having installed Xcode and a second download isn't required.

## Step 1. Obtaining Command Line Tools

Check that clang or gcc (on macOS, gcc is only a frontend to clang) works, with the command:
```
clang -v
```
If the toolchain is installed, an informational message like the one below (taken on a current macOS) will show.
```
Apple LLVM version 9.1.0 (clang-902.0.39.2)
Target: x86_64-apple-darwin17.7.0
Thread model: posix
InstalledDir: /Library/Developer/CommandLineTools/usr/bin
```
If no toolchain is installed, the command above will trigger a dialog requiring the installation of Xcode or Command Line Tools. Alternatively, the tools can be installed with the command:
```
xcode-select --install
```
If the tools are already installed, the following message will show:
```
xcode-select: error: command line tools are already installed, use "Software Update" to install updates
```
Once the compilation tools are installed, prepare the environment for building.

## Step 2. Preparing the environment

For speed reasons (and for protecting the SSD), the author of this text does the build on a RAM disk. A size of 1.5 GB will be enough.
The remaining memory for the OS and applications must be at least 2 GB, so for those not having enough RAM installed (4 GB at least), a directory on disk must be used instead. The size of the RAM disk can't be reduced too much, otherwise several Python tests will fail (at the testing phase).

If there's enough space for a RAM disk, the following command will create a 1.5 GB RAM disk and mount it at /Volumes/BUILD (the icon of the mounted volume will show on desktop):
```
diskutil eraseVolume HFS+ BUILD $(hdiutil attach -nomount ram://3145728)
```
Otherwise, if there's not enough room in RAM, create a temporary folder:
```
mkdir /private/tmp/build
```
Now set an environment variable holding the path to this build root. It would be used throughout the process of building. 
Pay attention to variable name conflicts. Variables like BUILD, DESTDIR, ARCH and others (see within the Makefile of each software built) are used by the building scripts, interfering with them can have unexpected results for the building process.
For a RAM disk, write:
```
export WORK=/Volumes/BUILD
```
Alternatively, for a directory on the disk, write:
```
export WORK=/private/tmp/build
```
Make a subdirectory for sources:
```
mkdir -v $WORK/src
```
Set the compiler program(s) and flags. 
```
export CC=clang CXX=clang++
```
By default, clang or gcc will target the machine's architecture as retrieved with the command uname -m in the terminal. In order to obtain dual-architecture ("fat") binaries write the command below:
```
export CFLAGS="-arch i386 -arch x86_64"
export CXXFLAGS="$CFLAGS"
```
Make subdirectories for C header files and library files within the working root directory:
```
mkdir -v $WORK/{include,lib}
```
Then add the created subdirectories to the C/CXX preprocessor's flags and linker's flags respectively. This is required for the tools to find the include files and compiled libraries:
```
export CPPFLAGS="-I$WORK/include" LDFLAGS="-L$WORK/lib"
```
Set the minimal macOS version to target, for example:
```
export MACOSX_DEPLOYMENT_TARGET=10.13
```
If this variable is not set, the resulting binaries will target the current macOS version. For each of the steps below, make sure the initial directory is $WORK/src (before downloading and building).

## Step 3. Install Tcl/Tk

This step may be skipped by those not installing the tkinter module or by those already having the desired version of Tcl/Tk installed on their systems.
Pay attention that this method installs Tcl/Tk system-wide. A contained install guide will be added to this text if required.

Change to the sources directory:
```
cd $WORK/src
```
Download Tcl/Tk from https://downloads.sourceforge.net/tcl using the curl command available by default on macOS. The download and extract steps can be performed in a single operation:

curl -L https://downloads.sourceforge.net/tcl/tcl8.6.8-src.tar.gz | tar -xf -
curl -L https://downloads.sourceforge.net/tcl/tk8.6.8-src.tar.gz | tar -xf -

Observe the versioning of Tcl/Tk archive names: tcl or tk followed by the version and then followed by -src.tar.gz (to download 8.5.18, for example, the archive names will be tcl8.5.18-src.tar.gz and tk8.5.18-src.tar.gz).
In the end, the subdirectories tcl8.6.8 and tk8.6.8 (the numbers may change according to the downloaded version) appear in the $WORK/src directory.
Pay attention at download errors. If any error occurs, the source subdirectories will be partial and the download procedure must be done again.

When building for 64 bits, the configuration option --enable-64bit can be added to Tcl and Tk, enabling large integers to be used.
Configure and build Tcl:

cd tcl8.6.8/unix
./configure --enable-64bit --enable-dtrace --enable-framework --enable-threads --mandir=/usr/local/share/man --prefix=/usr/local --with-encoding="utf-8"
make -j2 && sudo make NATIVE_TCLSH=/usr/local/bin/tclsh8.6 install
sudo mv /usr/local/bin/tclsh8.6 /Library/Frameworks/Tcl.framework/Versions/8.6
sudo ln -sv ../../../Library/Frameworks/Tcl.framework/Versions/8.6/tclsh8.6 /usr/local/bin
cd $WORK/src

When not building for 64 bits, the option --enable-64bit must be removed. The NATIVE_TCLSH given with the installation command shows the installer which is the tclsh to use when building documentation. If this variable isn't set and no Tcl 8.6 is installed on the system, the HTML documentation step will fail.
Move the tclsh8.6 binary from /usr/local/bin to /Library/Frameworks/Tcl.framework/Versions/8.6 and create a symbolic link to it in /usr/local/bin for consistency with system installed Tcl.
Configure and build Tk:

cd tk8.6.8/unix
./configure --enable-64bit --enable-aqua --enable-framework --enable-threads --mandir=/usr/local/share/man --prefix=/usr/local --without-x
make -j2 && sudo make install
cd $WORK/src

There is no need of NATIVE_TCLSH, as there's certainly a tclsh8.6 previously installed.

Clean the work space:

rm -rf tcl* tk*

Step 4. Install XZ (LZMA) headers

The LZMA library is already available on the system, but there are no C headers available. Download an API-compatible XZ and install headers with the $WORK prefix.

curl -L https://sourceforge.net/projects/lzmautils/files/xz-5.0.0.tar.gz | tar -xf -
cd xz-5.0.0
./configure --disable-nls --prefix=$WORK
cd src/liblzma/api
make install
cd $WORK/src

Observe that only the C headers are installed. Clean the work space:

rm -rf xz*

Step 5. Install SSL headers

This step must be skipped by those installing Python 3.7.X because a full SSL install is needed in this case (the SSL library available on macOS is too old). For Python 3.6.X and lower versions, the case of LZMA repeats. The libraries are available, but no C headers are found.
Pay attention when compiling for older OS versions, there could be old versions of OpenSSL instead of LibreSSL installed on the target system. In that case, one must download https://www.openssl.org/source/old/1.0.2/openssl-1.0.2.tar.gz and follow the steps given below for older SSL versions. Using those versions is not recommended.
Check the available SSL on the system:

openssl version

This will return something like:

LibreSSL 2.2.7

To install headers, download the first version having the same API (2.2.0 in the above case):

curl -L https://ftp.openbsd.org/pub/OpenBSD/LibreSSL/libressl-2.2.0.tar.gz | tar -xf -
cd libressl-2.2.0
./configure --prefix=$WORK
cd include
make install
cd $WORK/src

Observe that only the C headers are installed. Clean the work space:

rm -rf libressl*

Alternatively, to install for the older SSL versions, download:

curl -L https://www.openssl.org/source/old/1.0.2/openssl-1.0.2.tar.gz | tar -xf -

Replace 1.0.2 with the version shown for your system (see above). Ignore the final letters (a-h, etc). Configuring is different than the standard UNIX way:

cd openssl-1.0.2
./Configure threads zlib-dynamic --prefix=$WORK darwin64-x86_64-cc
cd include
make install
cd $WORK/src

Replace darwin64-x64_64-cc with the compiler options shown by Configure in case of error (the name changed between versions). If all is right, only the C headers are installed. Now clean the work space:

rm -rf openssl*

Step 6. Install full SSL

This step mus be skipped by those using Step 5 above, otherwise version conflicts will appear. A newer SSL is strictly required by Python 3.7.X and LibreSSL works well.
Download (version 2.7.4 for example):

curl -L https://ftp.openbsd.org/pub/OpenBSD/LibreSSL/libressl-2.7.4.tar.gz | tar -xf -

Then configure, build and install:

cd libressl-2.7.4
./configure --disable-shared --prefix=$WORK
cd include
make install
cd $WORK/src

Observe the --disable-shared option above: this makes the ssl python module independent of the ssl dynamic library which can be removed in the end.

When using OpenSSL 1.1.0, follow the steps below:

curl -L https://www.openssl.org/source/old/1.1.0/openssl-1.1.0.tar.gz | tar -xf -

Replace 1.1.0 with the last version shown on the site. Configuring is different than the standard UNIX way:

cd openssl-1.1.0
./Configure no-shared threads zlib-dynamic --prefix=$WORK darwin64-x86_64-cc
make -j2 && make install
cd $WORK/src

Replace darwin64-x64_64-cc with the compiler options shown by Configure in case of error (the name changed between versions). If all is right, only the C headers are installed. Now clean the work space:

rm -rf openssl*

Step 7. Install GDBM

Although not required, the dbm module will be complete after installing GDBM.
Download and extract:

curl -L https://ftp.gnu.org/gnu/gdbm/gdbm-1.14.1.tar.gz | tar -xf -

Then configure, build and install (statically compiled version, without readline or nls as only the library will be used):

cd gdbm-1.14.1
./configure --disable-nls --disable-shared --prefix=$WORK --without-readline
make -j2 && make install
cd $WORK/src

Clean the work space:

rm -rf gdbm*

Step 8. Install Python

When installing Python 3.7.X make sure the step 6 and not 5 was performed, otherwise the ssl module will not be built.
The CFLAGS and CXXFLAGS are not needed any more, the configure script provided with Python will set them correctly when --with-universal-archs option is provided. Without this option, these flags will remain set.
To clear the compiler flags, write:

unset CFLAGS CXXFLAGS

Set the variables I_TCLTK and L_TCLTK for the includes, respectively the libraries used when building tkinter. The names were chosen to not interfere with TCL_CFLAGS or TCL_LIBS which may be eventually set by the scripts. Write (example for 8.6):

export I_TCLTK="-I/Library/Frameworks/Tcl.framework/Versions/8.6/Headers -I/Library/Frameworks/Tk.framework/Versions/8.6/Headers"
export L_TCLTK="-L/Library/Frameworks/Tcl.framework/Versions/8.6 -L/Library/Frameworks/Tk.framework/Versions/8.6 -framework Tcl -framework Tk -ltclstub8.6 -ltkstub8.6 -framework CoreFoundation -lpthread -lz"

Now download, configure, build and install for Python 3.7.0:

curl -L https://www.python.org/ftp/python/3.7.0/Python-3.7.0.tar.xz | tar -xf -
cd Python-3.7.0
./configure --enable-ipv6 --enable-framework --enable-optimizations --enable-universalsdk=/ --prefix=/usr/local --with-dtrace --with-ensurepip=upgrade --with-openssl=$WORK --with-tcltk-includes="$I_TCLTK" --with-tcltk-libs="$L_TCLTK" --with-universal-archs=intel-64
make -j2

At this point, one can choose to write:

sudo make install

That command installs all (including PythonLauncher.app and IDLE.app), links the framework version that was built to /Library/Frameworks/Python.framework/Versions/Current and creates links in /usr/local/bin for all the command-line python executables.

Another approach is to manually install only the framework. Write (without sudo):

make install DESTDIR=/private/tmp/python3
cd /private/tmp/python3/Library/Frameworks/Python.framework/Versions

Now change the owner of the whole (-R for recursively) framework that was built (3.7 in the example):

sudo chown -R root:wheel 3.7

Then move the framework at its place (making sure the correct framework path exists with the first command):

sudo mkdir -p /Library/Frameworks/Python.framework/Versions 
sudo mv 3.7 /Library/Frameworks/Python.framework/Versions

The built framework can be made default:

sudo ln -sf 3.7 /Library/Frameworks/Python.framework/Versions/Current

sudo ln -sf Versions/Current/Headers /Library/Frameworks/Python.framework/Headers
sudo ln -sf Versions/Current/Python /Library/Frameworks/Python.framework/Python
sudo ln -sf Versions/Current/Resources /Library/Frameworks/Python.framework/Resources

To have python3 in the PATH, manually create links to /usr/local/bin as desired, or extend PATH in .bash_profile to include /Library/Frameworks/Python.framework/Versions/3.7/bin and that's all.

Time for cleaning:

rm -rf /private/tmp/python3
diskutil eject $WORK

With the last command, the volatile disk used for building disappears freeing RAM.
