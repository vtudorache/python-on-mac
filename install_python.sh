#!/bin/sh

PYTHON_VERSION=3.12.3

FRAMEWORK_NAME=Python

BUILD_NAME="Python_${PYTHON_VERSION}_$(date +%Y%m%d%H%M%S)"

diskutil erasevolume HFS+ $BUILD_NAME $(hdiutil attach -nomount ram://4194304)

BUILD_PATH=/Volumes/$BUILD_NAME

FRAMEWORK_VERSION=$(echo $PYTHON_VERSION | cut -f 1,2 -d .)

FRAMEWORK_PATH=/Library/Frameworks/$FRAMEWORK_NAME.framework/Versions/$FRAMEWORK_VERSION

if [ -d "$FRAMEWORK_PATH" ] ; then
    echo "The framework is already installed. Delete the old framework and retry."
    exit 1
fi

INITIAL_PATH=$(pwd)

set -e

cd "$BUILD_PATH"
curl -L https://downloads.sourceforge.net/tcl/tcl8.6.13-src.tar.gz | tar -xf -
curl -L https://downloads.sourceforge.net/tcl/tk8.6.13-src.tar.gz | tar -xf -
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

TCLTK_LIBS="-ltcl8.6 -ltclstub8.6 -lz -lpthread -framework CoreFoundation -ltk8.6 -ltkstub8.6"

cd "$BUILD_PATH"
curl -L https://sourceforge.net/projects/lzmautils/files/xz-5.4.6.tar.gz | tar -xf -
cd xz-5.4.6
./configure                     \
    --disable-doc               \
    --disable-nls               \
    --prefix="$FRAMEWORK_PATH"
make && sudo make install

cd "$BUILD_PATH"
curl -L https://ftp.gnu.org/gnu/gdbm/gdbm-1.23.tar.gz | tar -xf -
cd gdbm-1.23
./configure                     \
    --disable-nls               \
    --prefix="$FRAMEWORK_PATH"  \
    --without-readline
make && sudo make install

cd "$BUILD_PATH"
curl -L https://www.openssl.org/source/openssl-3.0.13.tar.gz | tar -xf -
cd openssl-3.0.13
perl Configure                                  \
    --openssldir="$FRAMEWORK_PATH/etc/openssl"  \
    --prefix="$FRAMEWORK_PATH"                  \
    no-engine                                   \
    no-legacy                                   \
    no-module
make && sudo make install_dev install_ssldirs

sudo rm -fr "$FRAMEWORK_PATH/bin" "$FRAMEWORK_PATH/lib/pkgconfig" "$FRAMEWORK_PATH/man" "$FRAMEWORK_PATH/share"

cd "$BUILD_PATH"
curl -L https://www.python.org/ftp/python/$PYTHON_VERSION/Python-$PYTHON_VERSION.tar.xz | tar -xf -
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

cd "$FRAMEWORK_PATH/include"
for NAME in $(ls) ; do
  if [ "$NAME" != "python$FRAMEWORK_VERSION" ] ; then
    sudo rm -fr "$NAME"
  fi
done

cd "$FRAMEWORK_PATH/lib"
sudo rm -f *.a *.la *.sh
sudo rm -f tcl8.6/tclAppInit.c
sudo rm -f tk8.6/tkAppInit.c

cd "$BUILD_PATH"
sudo rm -rf *
cd "$INITIAL_PATH"

if [ -d /Volumes/$BUILD_NAME ] ; then
    diskutil unmount /Volumes/$BUILD_NAME
fi
