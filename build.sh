#!/bin/sh

set -e
set -u

jflag=
jval=2

while getopts 'j:' OPTION
do
  case $OPTION in
  j)	jflag=1
        	jval="$OPTARG"
	        ;;
  ?)	printf "Usage: %s: [-j concurrency_level] (hint: your cores + 20%%)\n" $(basename $0) >&2
		exit 2
		;;
  esac
done
shift $(($OPTIND - 1))

if [ $# -gt 0 ]
then
  jval="$1"
fi

if [ "$jflag" ]
then
  if [ "$jval" ]
  then
    printf "Option -j specified (%d)\n" $jval
  fi
fi

cd `dirname $0`
ENV_ROOT=`pwd`
. ./env.source

#if you want a rebuild
#rm -rf "$BUILD_DIR" "$TARGET_DIR"
mkdir -p "$BUILD_DIR" "$TARGET_DIR" "$DOWNLOAD_DIR" "$BIN_DIR"

#download and extract package
download(){
filename="$1"
if [ ! -z "$2" ];then
	filename="$2"
fi
../download.pl "$DOWNLOAD_DIR" "$1" "$filename" "$3" "$4"
#disable uncompress
CACHE_DIR="$DOWNLOAD_DIR" ../fetchurl "http://cache/$filename"
}

echo "#### FFmpeg static build ####"

#this is our working directory
cd $BUILD_DIR

download \
	"yasm-1.3.0.tar.gz" \
	"" \
	"fc9e586751ff789b34b1f21d572d96af" \
	"http://www.tortall.net/projects/yasm/releases/"

download \
	"last_stable_x264.tar.bz2" \
	"" \
	"" \
	"https://download.videolan.org/pub/videolan/x264/snapshots/"

download \
	"x265_2.9.tar.gz" \
	"" \
	"" \
	"https://bitbucket.org/multicoreware/x265/downloads/"

download \
	"master" \
	"fdk-aac.tar.gz" \
	"" \
	"https://github.com/mstorsjo/fdk-aac/tarball"

download \
	"lame-3.99.5.tar.gz" \
	"" \
	"84835b313d4a8b68f5349816d33e07ce" \
	"http://downloads.sourceforge.net/project/lame/lame/3.99"

download \
	"opus-1.1.tar.gz" \
	"" \
	"c5a8cf7c0b066759542bc4ca46817ac6" \
	"http://downloads.xiph.org/releases/opus"

download \
	"faac-1.28.tar.bz2" \
	"" \
	"c5dde68840cefe46532089c9392d1df0" \
	"http://downloads.sourceforge.net/faac/"

download \
	"n4.1.tar.gz" \
	"" \
	"" \
	"https://github.com/FFmpeg/FFmpeg/archive/"

echo "*** Building yasm ***"
cd $BUILD_DIR/yasm*
./configure --prefix=$TARGET_DIR --bindir=$BIN_DIR
make -j $jval
make install

echo "*** Building x264 ***"
cd $BUILD_DIR/x264*
PATH="$BIN_DIR:$PATH" ./configure --prefix=$TARGET_DIR --enable-static --disable-shared --disable-opencl --enable-pic
PATH="$BIN_DIR:$PATH" make -j $jval
make install

echo "*** Building x265 ***"
cd $BUILD_DIR/x265*
cd build/linux
PATH="$BIN_DIR:$PATH" cmake -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX="$TARGET_DIR" -DENABLE_SHARED:bool=off ../../source
make -j $jval
make install

echo "*** Building fdk-aac ***"
cd $BUILD_DIR/mstorsjo-fdk-aac*
autoreconf -fiv
./configure --prefix=$TARGET_DIR --disable-shared
make -j $jval
make install

echo "*** Building mp3lame ***"
cd $BUILD_DIR/lame*
./configure --prefix=$TARGET_DIR --enable-nasm --disable-shared
make -j $jval

echo "*** Building opus ***"
cd $BUILD_DIR/opus*
./configure --prefix=$TARGET_DIR --disable-shared
make -j $jval

# FFMpeg
echo "*** Building FFmpeg ***"
cd $BUILD_DIR/FFmpeg*
PATH="$BIN_DIR:$PATH" \
PKG_CONFIG_PATH="$TARGET_DIR/lib/pkgconfig" ./configure \
  --prefix="$TARGET_DIR" \
  --pkg-config-flags="--static" \
  --extra-cflags="-I$TARGET_DIR/include -I$TARGET_DIR/include/bm -std=c11" \
  --extra-ldflags="-L$TARGET_DIR/lib" \
  --bindir="$BIN_DIR" \
  --enable-static \
  --enable-decklink \
  --enable-gpl \
  --enable-libfdk-aac \
  --enable-libx264 \
  --enable-nonfree \
  --extra-cflags="-I/home/mteg_vas/capture/Blackmagic_DeckLink_SDK_10.11.4/Linux/include/" \
  --extra-ldflags="-L/home/mteg_vas/capture/Blackmagic_DeckLink_SDK_10.11.4/Linux/include/"
# Stupid hack to override ffmpeg's too-automatic build process
make -j $jval
make install -j $jval
make distclean
hash -r
