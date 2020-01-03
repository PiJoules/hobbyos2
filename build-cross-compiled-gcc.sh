set -ex

if [ -z "$1" ]; then
  echo "Expected a valid GCC target (x86_64-elf, i686-elf, etc.)"
  exit 1
else
  TARGET="$1"
fi

PREFIX="/usr/local/$TARGET-gcc"
GCC_VERSION="9.2.0"
J=50

mkdir -p toolchain-dir
cd toolchain-dir
TOOLCHAIN_DIR=$(pwd)
rm -rf *

# The final binaries will be under ./toolchain-dir/usr/local/$TARGET-gcc/bin/

# Make binutils
# Look for a ore recent version if this 404s
curl -O http://ftp.gnu.org/gnu/binutils/binutils-2.24.tar.gz
tar xf binutils-2.24.tar.gz
mkdir binutils-build
cd binutils-build
../binutils-2.24/configure --target=$TARGET --enable-interwork --enable-multilib --disable-nls --disable-werror --prefix=$PREFIX
export PATH=$TOOLCHAIN_DIR/$PREFIX/bin:$PATH
make all -j $J
make DESTDIR=$TOOLCHAIN_DIR install

# Make GCC
cd $TOOLCHAIN_DIR
curl -O https://ftp.gnu.org/gnu/gcc/gcc-$GCC_VERSION/gcc-$GCC_VERSION.tar.gz
tar xf gcc-$GCC_VERSION.tar.gz
cd gcc-$GCC_VERSION
./contrib/download_prerequisites
cd ..
mkdir gcc-build
cd gcc-build
../gcc-$GCC_VERSION/configure --target=$TARGET --prefix="$PREFIX" --disable-nls --disable-libssp --enable-languages=c,c++ --without-headers
make all-gcc -j $J
make all-target-libgcc -j $J
make DESTDIR=$TOOLCHAIN_DIR install-gcc
make DESTDIR=$TOOLCHAIN_DIR install-target-libgcc
