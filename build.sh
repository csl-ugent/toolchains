#!/bin/bash

set -u

# usage help {{{
print_help_exit() {
cat<<HELP
Usage: $0 -a <ARCHITECTURE> -d <TARGET_DIR> [-c <CONFIG_ID>] [-s] [-n <PAR_PROCESS>] [-p]

    -a ARCHITECTURE         (req) Target architecture for the toolchain,
                                  valid options are: 'arm', 'i486', 'llvm', 'androidarm' or 'unpatched'.
    -l ARM_LIB              (opt) Only for ARMv7 toolchains. Allows choosing how the
                                  toolchain libraries should be compiled. Valid
                                  options are:

                                  default:   'armlib'       =>  no thumb in libc etc.
                                             'thumblib'     =>  thumb in libc etc.
                                             'mixedlib'     =>  strange accidental mix

    -d TARGET_DIR           (req) Directory to put the resulting toolchain in.
    -c CONFIG_ID            (opt) Config id of the desired configuration. See below
                                  for available options. Defaults to 0.
    -s                      (opt) Download and build support tools like autoconf,
                                  automake, gperf,.. If you machine resembles a
                                  Debian 7 host this shouldn't be necessary.
    -n PAR_PROCESS          (opt) How many parallel processes should be used to
                                  build everything. This defaults to 1.
    -p                      (opt) If provided a debian package will be built.
                                  This can ONLY BE DONE ON A DEBIAN SYSTEM with the
                                  necessary software for packing installed.
    -v                      (opt) Use only in combination with -p. Allows to set
                                  the debian package version.
    -g                      (opt) Generate debug information in the compiled libraries (e.g. libc).
    -h/-?                   (opt) Show this text and exit.

  Android-specific flags:
    -A                      (req) Android API-level to create a toolchain for.
                                  This should be a number, for example 18 to create a toolchain for Android 4.3 (Jelly Bean).
                                  Only level 18 has been tested so far.
    -w                      (opt) Generate a tool chain for a 32- or 64-bit host. Defaults to 32, choose between 32 or 64.

Available configurations ARM (use -l to select thumb libs):
    0)  GCC 4.6.4   Binutils 2.23.2    EGLIBC 2.17    armv7     softfp
    1)  GCC 4.8.1   Binutils 2.23.2    EGLIBC 2.17    armv7     softfp
    2)  GCC 4.8.1   Binutils 2.23.2    EGLIBC 2.17    armv7     hardfloat

    3)  GCC 4.8.1   Binutils 2.23.2    EGLIBC 2.17    armv5t    softfp
        NOTE: This toolchain is used to test Thumb-1 support in Diablo.
              As eglibc can't be compiled with only Thumb-1 instructions,
              '-l mixedlib' should be passed to this build script.

    4)  GCC 4.8.1   Binutils 2.23.2    GLIBC 2.17     armv8
    5)  GCC 4.8.1   Binutils 2.23.2    EGLIBC 2.17    armv7     soft

Available configurations x86:
    0)  GCC 4.8.1   Binutils 2.22      EGLIBC 2.17    (default)
    1)  GCC 4.6.4   Binutils 2.22      EGLIBC 2.17
    2)  GCC 4.8.1   Binutils 2.23.2    EGLIBC 2.17
    3)  GCC 4.6.4   Binutils 2.23.2    EGLIBC 2.17

Available configurations llvm options:
    0)  Version 3.2
    1)  Version 3.3
    2)  Version 3.4
    3)  Version 3.5
    4)  Version 3.6

Available configurations Android:
    0)  GCC 4.8          Binutils 2.23.2    armeabi
    1)  LLVM 3.3/GCC 4.8 Binutils 2.23.2    armeabi
    2)  LLVM 3.4/GCC 4.8 Binutils 2.23.2    armeabi
    3)  GCC 4.6          Binutils 2.23.2    armeabi

Available unpatched toolchains for Linux:
    0)  GCC 4.8.1   Binutils 2.23.2   EGLIBC 2.17 (Debian-package python-dev required)

HELP
exit 1
}
#}}}

# Helper functions {{{
# arg1: string to check whether it's not empty¬
# arg2: name of the parameter that should have been set¬
checkempty() {
  if [ x"$1" = x ]; then
    echo
    echo Error: Missing required parameter $2
    echo
    print_help_exit
  fi
}
#}}}

# Different configurations {{{
# ARM configurations
CONFIG_ARM[0]="gcc4.6.4-binutils2.23.2-eglibc2.17-armv7"
ARCH_ARM[0]="armv7"
PACKAGE_DIR_ARM[0]=${CONFIG_ARM[0]}

CONFIG_ARM[1]="gcc4.8.1-binutils2.23.2-eglibc2.17-armv7"
ARCH_ARM[1]="armv7"
PACKAGE_DIR_ARM[1]=${CONFIG_ARM[1]}

CONFIG_ARM[2]="gcc4.8.1-binutils2.23.2-eglibc2.17-armv7hf"
ARCH_ARM[2]="armv7hf"
PACKAGE_DIR_ARM[2]=${CONFIG_ARM[2]}

CONFIG_ARM[3]="gcc4.8.1-binutils2.23.2-eglibc2.17-armv5t"
ARCH_ARM[3]="armv5"
PACKAGE_DIR_ARM[3]=${CONFIG_ARM[3]}

CONFIG_ARM[4]="gcc4.8.1-binutils2.23.2-glibc2.17-armv8"
ARCH_ARM[4]="aarch64"
PACKAGE_DIR_ARM[4]=${CONFIG_ARM[4]}

CONFIG_ARM[5]="gcc4.8.1-binutils2.23.2-eglibc2.17-armv7-soft"
ARCH_ARM[5]="armv7-soft"
PACKAGE_DIR_ARM[5]=${CONFIG_ARM[5]}

# x86 configurations
CONFIG_X86[0]="gcc4.8.1-binutils2.22-eglibc2.17"
ARCH_X86[0]="i486"
PACKAGE_DIR_X86[0]=${CONFIG_X86[0]}

CONFIG_X86[1]="gcc4.6.4-binutils2.22-eglibc2.17"
ARCH_X86[1]="i486"
PACKAGE_DIR_X86[1]=${CONFIG_X86[1]}

CONFIG_X86[2]="gcc4.8.1-binutils2.23.2-eglibc2.17"
ARCH_X86[2]="i486"
PACKAGE_DIR_X86[2]=${CONFIG_X86[2]}

CONFIG_X86[3]="gcc4.6.4-binutils2.23.2-eglibc2.17"
ARCH_X86[3]="i486"
PACKAGE_DIR_X86[3]=${CONFIG_X86[3]}

# llvm configurations
CONFIG_LLVM[0]="release_32"    # git tag name
PACKAGE_DIR_LLVM[0]="llvm3.2"
CONFIG_LLVM[1]="release_33"    # git tag name
PACKAGE_DIR_LLVM[1]="llvm3.3"
CONFIG_LLVM[2]="release_34"    # git tag name
PACKAGE_DIR_LLVM[2]="llvm3.4"
CONFIG_LLVM[3]="release_35"
PACKAGE_DIR_LLVM[3]="llvm3.5"
CONFIG_LLVM[4]="release_36"
PACKAGE_DIR_LLVM[4]="llvm3.6"
# }}}

CONFIG_ANDROID[0]="gcc4.8-binutils2.23"
CONFIG_ANDROID[1]="gcc4.8-binutils2.23-llvm3.3"
CONFIG_ANDROID[2]="gcc4.8-binutils2.23-llvm3.4"
CONFIG_ANDROID[3]="gcc4.6-binutils2.23"

# unpatched configurations
CONFIG_UNPATCHED[0]="gcc4.8.1-binutils2.23.2-eglibc2.17"
ARCH_UNPATCHED[0]="x86_64"
PACKAGE_DIR_UNPATCHED[0]=${CONFIG_UNPATCHED[0]}

INSTALL_DIR=
ARCH=
INSTALL_PREFIX="opt/diablo-toolchains"
BUILD_SUPPORT=0
PACKAGE=0
PACKAGE_VERSION="1.0-1"
PARALL_PROC=1
GENERATE_DEBUG=0
CONFIG_ID=0
ARM_LIB="arm"
ANDROID_API=
WORD_SIZE=32

START_DIR=$(cd `dirname $0` && pwd)
PATCHES_DIR="diablo-patches"
PATCH_PREFIX=999

# only for the build process of the Android tool chain:
# Needed to be able to replace the libraries (libc.a, libm.a and libstdc++.a) in the toolchain
# by the Diablo-enhanced libraries.
SKIP_ANDROIDBUILD=
BUILD_ANDROID_LLVM=

# Parse arguments {{{
while getopts a:A:l:d:c:sn:pn:v:w:hgS\? opt; do
    case $opt in
        a) ARCH="$OPTARG"
            ;;
        d) INSTALL_DIR="$OPTARG"
            ;;
        c) CONFIG_ID="$OPTARG"
            ;;
        s) BUILD_SUPPORT=1
            ;;
        p) PACKAGE=1
            ;;
        v) PACKAGE_VERSION="$OPTARG"
            ;;
        n) PARALL_PROC="$OPTARG"
            ;;
        g) GENERATE_DEBUG=1
            ;;
        l) ARM_LIB="$OPTARG"
            ;;
        A) ANDROID_API="$OPTARG"
            ;;
        w) WORD_SIZE="$OPTARG"
            ;;
        h | \?) print_help_exit
            ;;
        S) SKIP_ANDROIDBUILD=echo
            ;;
    esac
done
shift `expr $OPTIND - 1`

checkempty "$INSTALL_DIR" -d
checkempty "$ARCH" -a

if [ "$ARCH" == "androidarm" ]; then
    checkempty "$ANDROID_API" -A
fi

# check for valid architecture argument
if [ "$ARCH" != "arm" ] && [ "$ARCH" != "i486" ] && [ "$ARCH" != "llvm" ] && [ "$ARCH" != "androidarm" ] && [ "$ARCH" != "unpatched" ]; then
    echo -e "\nIllegal architecture argument: $ARCH"
    print_help_exit
fi

# check for valid word size argument
if [ "$WORD_SIZE" != "32" ] && [ "$WORD_SIZE" != "64"  ]; then
    echo -e "\nIllegal value for the word size ($WORD_SIZE), must be '32' or '64'"
    print_help_exit
fi

package_dir=
compiler=
additional_link_params=""

# select right strings based on config
case "$ARCH" in
    "arm" )         arch_path=${CONFIG_ARM["$CONFIG_ID"]}
                    arch_name=${ARCH_ARM["$CONFIG_ID"]}
                    free_space_dir="crosstool-ng/.build"
                    package_dir=${PACKAGE_DIR_ARM["$CONFIG_ID"]}
                    compiler=gcc
                    additional_link_params="--no-demangle --no-merge-exidx-entries"
        ;;
    "i486" )        arch_path=${CONFIG_X86["$CONFIG_ID"]}
                    arch_name=${ARCH_X86["$CONFIG_ID"]}
                    free_space_dir="crosstool-ng/.build"
                    package_dir=${PACKAGE_DIR_X86["$CONFIG_ID"]}
                    compiler=gcc
                    additional_link_params="--no-demangle"
        ;;
    "llvm" )        arch_path=${CONFIG_LLVM["$CONFIG_ID"]}
                    arch_name=llvm
                    free_space_dir=".llvm_src"
                    package_dir=${PACKAGE_DIR_LLVM["$CONFIG_ID"]}
                    compiler=llvm
        ;;
    "androidarm" )  arch_path=${CONFIG_ANDROID["$CONFIG_ID"]}-api${ANDROID_API}
                    arch_name=${CONFIG_ANDROID["$CONFIG_ID"]}
                    free_space_dir=".android_src"
                    package_dir=${CONFIG_ANDROID["$CONFIG_ID"]}-api${ANDROID_API}-androidarm
                    compiler=android-gcc
                    if [ ! -z `echo "$arch_name" | grep llvm` ]; then
                      compiler=android-llvm
                    fi
                    additional_link_params="--no-demangle --no-merge-exidx-entries"
        ;;
    "unpatched" )   arch_path=${CONFIG_UNPATCHED["$CONFIG_ID"]}
                    arch_name=${ARCH_UNPATCHED["$CONFIG_ID"]}
                    free_space_dir="crosstool-ng/.build"
                    package_dir=${PACKAGE_DIR_UNPATCHED["$CONFIG_ID"]}
                    compiler=gcc
                    additional_link_params=""
        ;;
esac

case "$ARCH" in
    "androidarm" ) PATCHES_DIR="$PATCHES_DIR/android"
        ;;
    * )         PATCHES_DIR="$PATCHES_DIR/generic"
        ;;
esac

HOST_DISTRO=unknown
if [ -f /etc/os-release ]; then
  . /etc/os-release
  HOST_DISTRO=$ID
else
  echo "WARNING: Unrecognised distribution because the file /etc/os-release was not found."
  echo "         The build process will continue, but may result in errors."
fi

# make install dir absolute if necesarry
if [[ "$INSTALL_DIR" != /* ]]
then
    INSTALL_DIR=$START_DIR/$INSTALL_DIR
fi

# underscores are not allowed in package names
# (Debian dpkg-deb tool)
package_dir=$(echo $package_dir | tr "_" -)

# if packaging is on we should nest the install dir
if [ $PACKAGE -ne 0 ]; then
    PACKAGE_NAME="diablo-$package_dir-toolchain"
    PACKAGING_DIR=$INSTALL_DIR/$PACKAGE_NAME
    TOP_INSTALL_DIR=$INSTALL_DIR
    INSTALL_DIR=$INSTALL_DIR/$PACKAGE_NAME/$INSTALL_PREFIX/$package_dir
fi

# check whether GCC 4.8 is used to create the toolchain.
# Using GCC 4.9 results in an internal GCC error when trying to build an ARM toolchain.
GCCEXEC=gcc
if [[ -v CC ]]; then
    GCCEXEC=$CC
fi
GCCVERSION=`"$GCCEXEC" --version|head -1 |sed -e 's/([^\)]*)//g'|egrep -o "[0-9]*\.[0-9]*"|head -1`
GCCMAJORVERSION=`echo $GCCVERSION | cut -d '.' -f 1`
GCCMINORVERSION=`echo $GCCVERSION | cut -d '.' -f 2`
if test \( $GCCMAJORVERSION -gt 4 \) -o \( $GCCMAJORVERSION -eq 4 -a $GCCMINORVERSION -gt 8 \) ; then
    # using GCC 4.9 to build an Android toolchain (NDK) is allowed
    if [ "$ARCH" != "androidarm" ]; then
        echo -e "Please use GCC 4.8 to build the toolchain. Using GCC 4.9 results in an internal assembler error when building the toolchain."
        echo -e "  Detected GCC version: $GCCMAJORVERSION.$GCCMINORVERSION"
        exit 1
    fi
fi

# Get git revision
GIT_REVISION=
if [ -d $START_DIR/.git ]; then
  # This directory is version controlled by git
  GIT_REVISION=$(cd $START_DIR && git rev-parse --short=10 HEAD)
else
  # This directory is not version controlled by git
  if [ ! -f $START_DIR/.git-revision ]; then
    echo -e "Could not find git revision (file .git-revision does not exist)!"
    exit 1
  fi

  GIT_REVISION=`cat .git-revision`
fi
REPO_VERSION_STRING="DiabloTC-$GIT_REVISION"

# create destination directory
mkdir -p "$INSTALL_DIR" 2>/dev/null
if [ $? -ne 0 ]; then
    echo Unable to create directory "$INSTALL_DIR"
    exit 1
fi
echo -e "\nCreated toolchain target directory..."

# get absolute toolchain targetdir
TARGET_DIR=`cd "$INSTALL_DIR" && pwd`/

#}}}

function patch_diablo_patches {
  patchdirectory=$1
  prefix=$2

  # replace reserved keywords in patch files
  find $patchdirectory -type f -iname '*.patch' -exec sed -i "s+DIABLO_GAS_COMMENT+\"${prefix}binutils_gas-$REPO_VERSION_STRING\"+" "{}" +;
}

function print_required_android {
  local machine=$(uname -m)
  local i386suffix=

  if [ $machine == 'x86_64' ]; then
    i386suffix=":i386"
  fi

cat<<HELP
The following packages must be installed on your system to be able to properly build an Android toolchain
   (debian package names are used here, and may differ across different versions or distros):

  autoconf, automake, bison, flex, g++, g++-multilib, gcc, gcc-multilib,
  git, gperf, libtool, subversion, texinfo,
  libc6-dev${i386suffix}, libncurses5-dev${i386suffix}, libreadline-gplv2-dev${i386suffix}
HELP
}

function check_required_android {
  case $HOST_DISTRO in
    debian)
      ;&
    ubuntu)
      i386suffix=
      machine=`uname -m`
      if [ $machine == 'x86_64' ]; then
        i386suffix=":i386"
      fi

      pkglist=("autoconf" "automake" "bison" "flex" "g++" "g++-multilib" "gcc" "gcc-multilib" "git" "gperf" "libtool" "subversion" "texinfo" "libc6-dev${i386suffix}" "libncurses5-dev${i386suffix}" "libreadline*-dev${i386suffix}")
      pkglistno=("qemu-user" "qemu-user-static")

      for pkgname in "${pkglist[@]}"
      do
        dpkg-query -l $pkgname | tail -n 1 | egrep "^ii" > /dev/null 2>&1
        if [ $? -ne 0 ]; then
          echo "Package '$pkgname' is required."
          print_required_android
          exit 1
        fi
      done

      for pkgname in "${pkglistno[@]}"
      do
        dpkg-query -l $pkgname | tail -n 1 | egrep "^ii" > /dev/null 2>&1
        if [ $? -eq 0 ]; then
          echo "Package '$pkgname' must be removed from this system. After successfully building the toolchain, you can reinstall this package safely."
          exit 1
        fi
      done
      ;;

    arch)
	# TODO: add support for ArchLinux
      ;&
    *)
      echo "WARNING: can't check for required pre-installed packages because this distro is not supported: $HOST_DISTRO"
      print_required_android
      ;;
  esac
}

function copy_diablo_patches_to_android {
    srcpatchdir=`cd $1 && pwd`
    dstpatchdir=`cd $2 && pwd`
    appendpath=$3

    for patchfile in `(cd $srcpatchdir && find . -name "*.patch")`; do
        cp $srcpatchdir/`basename $patchfile` $dstpatchdir/`basename $patchfile`
        sed -ri "s:^(\+\+\+|---)\s+(a|b):\1 \2/$appendpath:" $dstpatchdir/`basename $patchfile`
    done
}

function generate_and_patch_spec_file {
  root_directory=$1
  abi=$(cd $1/bin && find . -name "*gcc" -exec basename {} \; | sed 's/-gcc$//')
  string_to_append="$2"

  # aarch64 (ARMv8) does not support exidx section merging
  echo $arch_name | grep "aarch64" > /dev/null
  if [ $? -eq 0 ]; then
    string_to_append=`echo "$string_to_append" | sed 's/--no-merge-exidx-entries//'`
  fi

  if [ -z "$string_to_append" ]; then
    return
  fi

  # first make the target directory owner-writable
  spec_file=$root_directory/$abi/lib
  chmod u+w $spec_file
  spec_file=$spec_file/specs

  # generate the spec file
  $root_directory/bin/$abi-gcc -dumpspecs > $spec_file

  # find the line number of the linke to be replaced and append the string to that line
  line_nr_to_replace=`grep -A1 -n "\*link:$" $spec_file | tail -n1 | grep -o "^[0-9]\+"`
  sed -i "${line_nr_to_replace}s/\(.*\)$/\1 ${string_to_append}/" $spec_file
}

function build_android {
    # the AOSP build scripts only support sh pointing to bash, not dash
    if [ -z `$START_DIR/shelltest.sh` ]; then
        echo
        echo "The default shell is not bash. However, the Android build scripts expect /bin/sh to point to a valid bash binary."
        echo "If you are running Debian or Ubuntu this can be fixed by running the following command, answering \"NO\" on the question asked:"
        echo "   sudo dpkg-reconfigure dash"
        echo
        echo "After this, you can run this script again."
        exit 1
    fi

    androidbinutilsversion=$(echo "$arch_name" | perl -ne '$_=m/binutils([^-]*)/;print $1')
    androidgccversion=$(echo "$arch_name" | perl -ne '$_=m/gcc([^-]*)/;print $1')

    androidllvmversion=
    androidllvmversion_nodot=
    if [ ! -z `echo "$arch_name" | grep llvm` ]; then
        BUILD_ANDROID_LLVM=1
        androidllvmversion=$(echo "$arch_name" | perl -ne '$_=m/llvm([^-]*)/;print $1')
        androidllvmversion_nodot=$(echo "$androidllvmversion" | sed 's/\.//')
    fi

    local MACHINE=$(uname -m)
    if [ ! -f /usr/bin/${MACHINE}-linux-gnu-ar ] || [ ! -f /usr/bin/${MACHINE}-linux-gnu-ranlib ]; then
        echo -e "${MACHINE}-linux-gnu-{ar,ranlib} not found, please create symbolic links like so:"
        echo -e "   sudo ln -s /usr/bin/ar /usr/bin/${MACHINE}-linux-gnu-ar"
        echo -e "   sudo ln -s /usr/bin/ranlib /usr/bin/${MACHINE}-linux-gnu-ranlib"
        exit 1
    fi

    # comma-separated list, could add linux-x86_64 but not fully supported by NDK yet
    androidpythonarchs="linux-x86"
    try64=
    standalonesystem="linux-x86"

    # setup parameters for possible 64-bit host toolchain
    if [ "$WORD_SIZE" == "64" ]; then
        echo "Building a 64-bit host toolchain"
        androidpythonarchs="linux-x86,linux-x86_64"
        try64="--try-64"
        standalonesystem="linux-x86_64"
    fi

    echo "Building an Android toolchain for API level $ANDROID_API (GCC $androidgccversion/binutils $androidbinutilsversion)"

    # checkout the NDK and development repositories
    mkdir -p $START_DIR/android
    androiddir=`cd $START_DIR/android && pwd`

    if [[ ! -d $androiddir/ndk ]]; then
        git clone https://android.googlesource.com/platform/ndk $androiddir/ndk
        cd $androiddir/ndk
        git checkout be9ba71abf2b898fa62a169659ab0b6f8baaa5ca

        for i in `ls $START_DIR/script-patches/ndk-*.patch`; do
          patch -p1 < $i
        done

        cd -
    fi
    ndkdir=`cd $androiddir/ndk && pwd`

    if [[ ! -d $androiddir/development ]]; then
        git clone https://android.googlesource.com/platform/development $androiddir/development
        cd $androiddir/development
        git checkout 72bd04795b38b8dbbbf5d4b6e8c5cac2a4322702
        cd -
    fi
    devdir=`cd $androiddir/development && pwd`

    # copy the necessary patches for binutils
    mkdir -p $ndkdir/build/tools/toolchain-patches/binutils/
    copy_diablo_patches_to_android $PATCHES_DIR/binutils/$androidbinutilsversion/ $ndkdir/build/tools/toolchain-patches/binutils binutils-$androidbinutilsversion

    patch_diablo_patches $ndkdir/build/tools/toolchain-patches/binutils "android"

    # copy the necessary patches for LLVM
    for llvm_release in `ls $PATCHES_DIR/llvm`; do
      llvmdotversion=`echo "$llvm_release" | egrep -o "[0-9]+" | sed -r 's/([0-9])/\1\./g' | sed -r 's/\.$//'`

      mkdir -p $ndkdir/build/tools/toolchain-patches/llvm-$llvmdotversion/
      copy_diablo_patches_to_android $PATCHES_DIR/llvm/$llvm_release/llvm/ $ndkdir/build/tools/toolchain-patches/llvm-$llvmdotversion llvm
      copy_diablo_patches_to_android $PATCHES_DIR/llvm/$llvm_release/clang/ $ndkdir/build/tools/toolchain-patches/llvm-$llvmdotversion clang
    done

    # copy the necessary patches for GCC
    for gcc_version in `ls $PATCHES_DIR/gcc`; do
      mkdir -p $ndkdir/build/tools/toolchain-patches/gcc/
      copy_diablo_patches_to_android $PATCHES_DIR/gcc/$gcc_version/ $ndkdir/build/tools/toolchain-patches/gcc/ gcc-$gcc_version
    done

    mkdir -p $START_DIR/.android_src
    ndksourcedir=`cd $START_DIR/.android_src && pwd`

    # by default, the NDK uses /tmp for storing temporary files
    # The size of /tmp is dependent on the OS. On ArchLinux, this is half the RAM size
    # by default, and apparently 4 GB is not enough in this case (these toolchains have
    # been built and tested on a machine with 4 GB of /tmp space).
    # This issue can be prevented by changing the default temporary directory to the current
    # directory, of which we assume it is large enough.
    #
    # Note that the contents of this temporary directory are erased when all sources
    #      have been downloaded and patched.
    export NDK_TMPDIR=$START_DIR/.android_temp
    mkdir -p $NDK_TMPDIR

    # download and patch the sources
    if [[ ! -f $ndksourcedir/SOURCES ]]; then
        $ndkdir/build/tools/download-toolchain-sources.sh $ndksourcedir
    fi

    # PPL 0.11.2 should be patched if it is to be compiled with GCC 4.9
    if test \( $GCCMAJORVERSION -gt 4 \) -o \( $GCCMAJORVERSION -eq 4 -a $GCCMINORVERSION -gt 8 \) ; then
        pplversion="ppl-1.0"

        # only patch PPL if a patch file is found
        if [[ -f $START_DIR/$PATCHES_DIR/ppl/fix-build-$pplversion-with-gcc-4.9.patch ]]; then
            old=`pwd`
            echo "Patching $pplversion so it can be compiled with GCC 4.9"
            cd $ndksourcedir/ppl
            tar xpf $pplversion.tar.bz2
            mv $pplversion.tar.bz2 $pplversion.orig.tar.bz2
            cd $pplversion
            # don't complain when the patch is already applied
            patch -N -p1 < $START_DIR/$PATCHES_DIR/ppl/fix-build-$pplversion-with-gcc-4.9.patch
            cd ..
            tar cjf $pplversion.tar.bz2 $pplversion
            cd $old
        fi

        pplversion="ppl-0.11.2"

        # only patch PPL if a patch file is found
        if [[ -f $START_DIR/$PATCHES_DIR/ppl/fix-build-$pplversion-with-gcc-4.9.patch ]]; then
            old=`pwd`
            echo "Patching $pplversion so it can be compiled with GCC 4.9"
            cd $ndksourcedir/ppl
            tar xpf $pplversion.tar.bz2
            mv $pplversion.tar.bz2 $pplversion.orig.tar.bz2
            cd $pplversion
            # don't complain when the patch is already applied
            patch -N -p1 < $START_DIR/$PATCHES_DIR/ppl/fix-build-$pplversion-with-gcc-4.9.patch
            cd ..
            tar cjf $pplversion.tar.bz2 $pplversion
            cd $old
        fi
    fi

    # build a proper sysroot directory
    echo "Generate minimal platform information"
    $SKIP_ANDROIDBUILD $ndkdir/build/tools/gen-platforms.sh --src-dir=$devdir/ndk --ndk-dir=$ndkdir --arch=arm --minimal

    # build the GCC/binutils toolchain
    echo "Build GCC $androidgccversion/binutils $androidbinutilsversion toolchain"
    $SKIP_ANDROIDBUILD $ndkdir/build/tools/build-gcc.sh $ndksourcedir $ndkdir arm-linux-androideabi-$androidgccversion --binutils-version=$androidbinutilsversion --diablotc-version="androidgcc-$REPO_VERSION_STRING" $try64

    if [ x"$BUILD_ANDROID_LLVM" != x ]; then
        echo "Build LLVM $androidllvmversion toolchain"
        $SKIP_ANDROIDBUILD $ndkdir/build/tools/build-llvm.sh $ndksourcedir $ndkdir llvm-$androidllvmversion --binutils-version=$androidbinutilsversion --diablotc-version="androidllvm-$REPO_VERSION_STRING" $try64

        if [ ! -d $ndkdir/toolchains/llvm-$androidllvmversion/prebuilt/linux-x86_64 ]; then
            ln -s linux-x86 $ndkdir/toolchains/llvm-$androidllvmversion/prebuilt/linux-x86_64
        fi
    fi

    extrallvmoptions=
    gcc_or_clang_version="--gcc-version=$androidgccversion"
    if [ x"$BUILD_ANDROID_LLVM" != x ]; then
        extrallvmoptions="--llvm-version=$androidllvmversion"
        gcc_or_clang_version="--llvm-version=$androidllvmversion"
    fi

    # create sysroots for the different Android platforms
    # TODO: samples should not be generated, but the are useful for testing purposes
    echo "Generate full platform information"
    $SKIP_ANDROIDBUILD $ndkdir/build/tools/gen-platforms.sh --src-dir=$devdir/ndk --ndk-dir=$ndkdir --arch=arm --samples --gcc-version=$androidgccversion $extrallvmoptions

    # III.2: Generation of gdbserver
    echo "Build GDB server"
    $SKIP_ANDROIDBUILD $ndkdir/build/tools/build-gdbserver.sh $ndksourcedir $ndkdir arm-linux-androideabi-$androidgccversion $try64

    # III.3: Generating C++ runtime prebuilt binaries
    echo "Build gabi++"
    $SKIP_ANDROIDBUILD $ndkdir/build/tools/build-cxx-stl.sh --stl=gabi++  --ndk-dir=$ndkdir --abis=armeabi $gcc_or_clang_version
    echo "Build stlport"
    $SKIP_ANDROIDBUILD $ndkdir/build/tools/build-cxx-stl.sh --stl=stlport --ndk-dir=$ndkdir --abis=armeabi $gcc_or_clang_version
    echo "Build libc++"
    $SKIP_ANDROIDBUILD $ndkdir/build/tools/build-cxx-stl.sh --stl=libc++  --ndk-dir=$ndkdir --abis=armeabi $gcc_or_clang_version
    echo "Build libstdc++"
    $SKIP_ANDROIDBUILD $ndkdir/build/tools/build-gnu-libstdc++.sh $ndksourcedir --ndk-dir=$ndkdir --abis=armeabi --gcc-version-list=$androidgccversion

    # IV.1 : Building 'ndk-stack'
    echo "Build NDK stack"
    $SKIP_ANDROIDBUILD $ndkdir/build/tools/build-ndk-stack.sh --ndk-dir=$ndkdir
    echo "Build NDK depends"
    $SKIP_ANDROIDBUILD $ndkdir/build/tools/build-ndk-depends.sh --ndk-dir=$ndkdir

    # build host python
    # Note that '--force' is needed here, otherwise the build apparently silently finishes without installing the binaries
    echo "Build python"
    $SKIP_ANDROIDBUILD $ndkdir/build/tools/build-host-python.sh --toolchain-src-dir=$ndksourcedir --ndk-dir=$ndkdir --systems=$androidpythonarchs --force

    # build a standalone toolchain
    echo "Make standalone toolchain"
    $ndkdir/build/tools/make-standalone-toolchain.sh --ndk-dir=$ndkdir --abis=armeabi --install-dir=$INSTALL_DIR --platform=android-$ANDROID_API --toolchain=arm-linux-androideabi-$androidgccversion --system=$standalonesystem $extrallvmoptions

    # tell the user to copy over Diablo-enhanced static libraries
cat<<END
The Android tool chain for API level $ANDROID_API has been created.
If you have not done so yet, copy over the following Diablo-enhanced static libraries (i.e. libraries built from the AOSP (or other Android) tree using one of the Diablo compilers):

* IF you just want to use the tool chain as-is, i.e. don't create a Debian package using this script:
  cp <path>/libc.a $INSTALL_DIR/sysroot/usr/lib/libc.a
  cp <path>/libm.a $INSTALL_DIR/sysroot/usr/lib/libm.a
  cp <path>/libstdc++.a $INSTALL_DIR/sysroot/usr/lib/libstdc++.a

* IF you want to create a Debian package:
  cp <path>/libc.a $ndkdir/platforms/android-$ANDROID_API/arch-arm/usr/lib/libc.a
  cp <path>/libm.a $ndkdir/platforms/android-$ANDROID_API/arch-arm/usr/lib/libm.a
  cp <path>/libstdc++.a $ndkdir/platforms/android-$ANDROID_API/arch-arm/usr/lib/libstdc++.a

  ./build.sh <original build parameters> -S -p
END
}

# llvm build {{{
function build_llvm {
    rm -rf $START_DIR/.llvm_src
    mkdir -p $START_DIR/.llvm_src

    clangbuilddir=`cd $START_DIR/.llvm_src && pwd`

    # checkouts
    git clone -b ${CONFIG_LLVM["$CONFIG_ID"]} --depth 1 --single-branch http://llvm.org/git/llvm.git $clangbuilddir
    cd $clangbuilddir/tools
    git clone -b ${CONFIG_LLVM["$CONFIG_ID"]} --depth 1 --single-branch http://llvm.org/git/clang.git
    cd $clangbuilddir/projects
    git clone -b ${CONFIG_LLVM["$CONFIG_ID"]} --depth 1 --single-branch http://llvm.org/git/compiler-rt.git

    cd $clangbuilddir
    git apply $START_DIR/$PATCHES_DIR/llvm/${CONFIG_LLVM["$CONFIG_ID"]}/*.patch

    # build
    mkdir build
    cd $clangbuilddir/build && cmake $clangbuilddir -DCMAKE_INSTALL_PREFIX=$INSTALL_DIR -DC_INCLUDE_DIRS=/usr/include -DCMAKE_BUILD_TYPE=Release -DDIABLO_TC_REV="\"llvm-$REPO_VERSION_STRING\""
    make -j$PARALL_PROC && make install
}
# }}}

# crosstools-ng build {{{
function build_with_ct {
    # download and build versions autconf/automake/libtool that are known to work {{{
    if [ $BUILD_SUPPORT -ne 0 ]; then
        echo "Building support tools ..."

        mkdir -p support
        supportprefix=`cd support && pwd`

        wget -r "ftp://ftp.gnu.org/gnu/autoconf/autoconf-2.69.tar.gz"
        wget -r "ftp://ftp.gnu.org/gnu/automake/automake-1.14.tar.gz"
        wget -r "ftp://ftp.gnu.org/gnu/libtool/libtool-2.4.2.tar.gz"
        wget -r "ftp://ftp.gnu.org/gnu/gperf/gperf-3.0.4.tar.gz"

        tar xzf ftp.gnu.org/gnu/autoconf/autoconf-2.69.tar.gz
        cd autoconf-2.69
        ./configure --prefix="$supportprefix"
        make -j $PARALL_PROC
        make install
        cd ..
        rm -rf autoconf-2.69

        # the next tools can already depend on the installed ones
        export PATH="$supportprefix"/bin:"$PATH"

        tar xzf ftp.gnu.org/gnu/automake/automake-1.14.tar.gz
        cd automake-1.14
        ./configure --prefix="$supportprefix"
        make -j $PARALL_PROC
        make install
        cd ..
        rm -rf automake-1.14

        tar xzf ftp.gnu.org/gnu/libtool/libtool-2.4.2.tar.gz
        cd libtool-2.4.2
        ./configure --prefix="$supportprefix"
        make -j $PARALL_PROC
        make install
        cd ..
        rm -rf libtool-2.4.2

        tar xzf ftp.gnu.org/gnu/gperf/gperf-3.0.4.tar.gz
        cd gperf-3.0.4
        ./configure --prefix="$supportprefix"
        make -j $PARALL_PROC
        make install
        cd ..
        rm -rf gperf-3.0.4
        echo -e "\nDownloaded and built autoconf, automake, libtool and gperf..."
    else
        if [ -d support ]; then
            # use previously built tools
            supportprefix=`cd support && pwd`
            export PATH="$supportprefix"/bin:"$PATH"
        fi
    fi
    #}}}

    ct_tarball=crosstool-ng.tar.bz2
    if [ ! -f $ct_tarball ]; then
      wget https://diablo.elis.ugent.be/sites/diablo/files/toolchains/support/$ct_tarball
    fi

    eglibc_tarball=eglibc-2_17.tar.bz2
    if [ ! -f $eglibc_tarball ]; then
      wget https://diablo.elis.ugent.be/sites/diablo/files/toolchains/support/$eglibc_tarball
    fi

    #{{{ unpack and build crosstool-ng
    tar xjf $ct_tarball
    cd $START_DIR/crosstool-ng

    # check if we need a bootstrap first
    if [ ! -f ./configure ]; then
        ./bootstrap
    fi

    ./configure --enable-local
    if [ $? -ne 0 ]; then
        echo "Failed to configure crosstool-ng"
        exit 1
    fi

    make
    if [ $? -ne 0 ]; then
        echo "Failed to make crosstool-ng"
        exit 1
    else
        echo -e "\nCrosstool-ng built..."
    fi
    #}}}

    # install patches and crosstool config{{{
    # copy over our patches with a prefix
    cd $START_DIR/$PATCHES_DIR
    find ./ -type d -exec mkdir $START_DIR/crosstool-ng/patches/{} 2> /dev/null \;
    if [ $? -ne 0 ]; then
        echo Failed to create the patch directories in crosstool-ng.
        exit 1
    fi

    find ./ -name "*.patch" -exec sh -c 'cp -r {} '"$START_DIR"'/crosstool-ng/patches/`dirname {}`/'"$PATCH_PREFIX"'_`basename {}`' \;
    if [ $? -ne 0 ]; then
        echo Failed to copying over the toolchain patches for Diablo.
        exit 1
    fi

    # select and copy over crosstools profile {{{
    cd $START_DIR/crosstool-ng
    SAMPLE_PATH=$ARCH-$arch_path
    mkdir -p samples/$SAMPLE_PATH
    if [ $? -ne 0 ]; then
        echo "Failed to create samples directory: $SAMPLE_PATH"
        exit 1
    fi

    cp ../config/$ARCH/$arch_path/* samples/$SAMPLE_PATH/
    if [ $? -ne 0 ]; then
        echo "Failed to copy crosstool-ng Diablo toolchain profile"
        exit 1
    fi

    # generate libraries with debug info if desired
    if [ $GENERATE_DEBUG -ne 0 ]; then
        sed -ri 's/CT_EXTRA_CFLAGS_FOR_BUILD="/CT_EXTRA_CFLAGS_FOR_BUILD="-ggdb -g /' samples/$SAMPLE_PATH/crosstool.config
        sed -ri 's/CT_EXTRA_LDFLAGS_FOR_BUILD="/CT_EXTRA_LDFLAGS_FOR_BUILD="-ggdb -g /' samples/$SAMPLE_PATH/crosstool.config
        sed -ri 's/CT_EXTRA_CFLAGS_FOR_HOST="/CT_EXTRA_CFLAGS_FOR_HOST="-ggdb -g /' samples/$SAMPLE_PATH/crosstool.config
        sed -ri 's/CT_EXTRA_LDFLAGS_FOR_HOST="/CT_EXTRA_LDFLAGS_FOR_HOST="-ggdb -g /' samples/$SAMPLE_PATH/crosstool.config
    fi

    #}}}

    # adjust crosstool-ng config file to specify target dir {{{
    mv samples/$SAMPLE_PATH/crosstool.config samples/$SAMPLE_PATH/crosstool.config-org
    sed -e "s+^CT_PREFIX_DIR=.*+CT_PREFIX_DIR=\"$TARGET_DIR\"+" < samples/$SAMPLE_PATH/crosstool.config-org > samples/$SAMPLE_PATH/crosstool.config
    #}}}

    # adapt config file to build libs with thumb / arm or a strange mix | ARM ONLY {{{
    if [ "$ARM_LIB" = "mixedlib" ] || [ "$ARM_LIB" = "thumblib" ]; then
        sed -ri 's/CT_ARCH_ARM_MODE="arm"/CT_ARCH_ARM_MODE="thumb"/' samples/$SAMPLE_PATH/crosstool.config
        sed -ri 's/CT_ARCH_ARM_MODE_ARM=y/# CT_ARCH_ARM_MODE_ARM is not set/' samples/$SAMPLE_PATH/crosstool.config
        sed -ri 's/# CT_ARCH_ARM_MODE_THUMB is not set/CT_ARCH_ARM_MODE_THUMB=y/' samples/$SAMPLE_PATH/crosstool.config
    fi

    if [ "$ARM_LIB" == "thumblib" ]; then
        sed -ri 's/CT_TARGET_CFLAGS="-mno-thumb-interwork -marm"/CT_TARGET_CFLAGS="-mno-thumb-interwork"/' samples/$SAMPLE_PATH/crosstool.config
    fi
    #}}}

    # Patch ct-ng so the reported name/version for the compiled GCC/binutils binaries includes Diablo version information
    sed -ri "s+^(export CT_VERSION:=)(.*)+\1\2 ct-$REPO_VERSION_STRING+" ct-ng

    patch_diablo_patches "$START_DIR"/crosstool-ng/patches/ ""

    echo -e "\nPatches and crosstool configuration selected and copied over..."
    #}}}

    # load the profile {{{
    ./ct-ng $SAMPLE_PATH
    if [ $? -ne 0 ]; then
        echo "Failed to load crosstool-ng Diablo toolchain profile"
        exit 1
    fi
    # }}}

    # copy over the eglibc tarball because it can't be downloaded anymore
    mkdir -p .build/tarballs
    cp ../$eglibc_tarball .build/tarballs/eglibc-2_17.tar.bz2

    # build everything {{{
    echo -e "\nCrosstool-ng loaded the profile, starting to build..."
    ./ct-ng build."$PARALL_PROC"
    if [ $? -ne 0 ]; then
        echo "Failed to build crosstool-ng Diablo toolchain"
        exit 1
    fi
    #}}}
}
# }}}

if [ "$ARCH" == "llvm" ]; then
    build_llvm
elif [ "$ARCH" == "androidarm" ]; then
    check_required_android
    build_android
else
    build_with_ct
fi

generate_and_patch_spec_file "$INSTALL_DIR" "$additional_link_params"

# package if necesarry {{{
if [ $PACKAGE -ne 0 ]; then
    # create debian package files
    cd $START_DIR
    echo -e "\nCopying over Debian packaging files... $PACKAGING_DIR"
    mkdir -p $PACKAGING_DIR/DEBIAN
    cd $PACKAGING_DIR/DEBIAN
    cp $START_DIR/package/control $START_DIR/package/postinst $START_DIR/package/prerm .

    # substitute right values
    sed -i -e "s/VAR_PACKAGE_DIR/$package_dir/" *
    sed -i -e "s/VAR_ARCH/$arch_name/" *
    sed -i -e "s/VAR_COMPILER/$compiler/" *
    sed -i -e "s/VAR_SYSTEM/`dpkg --print-architecture`/" *
    sed -i -e "s/VAR_VERSIONS/$arch_path/" *
    sed -i -e "s/VAR_PACKAGE_VERSION/$PACKAGE_VERSION/" *

    # remove some unwanted files
    echo -e "\nRemoving unwanted files from package..."
    cd ..
    find . -type d -exec chmod u+w {} \;
    find -name "*.config" -exec rm -f {} \;
    find ./ -name "*.bz2" -exec rm -f {} \;

    # package up
    cd ..
    echo -e "\nPackaging..."
    dpkg-deb -b $PACKAGE_NAME ..

    # clean up
    echo -e "\nPackaging clean up..."
    cd $START_DIR
    chmod a+w -R $PACKAGING_DIR
    rm -rf $PACKAGING_DIR
fi
# }}}

#{{{ done!
echo
echo "Finished!"
echo "The cross toolchain has been installed under $INSTALL_DIR"
echo
echo "To free up space, you delete the $free_space_dir"
echo "directory (or you can simply delete the entire directory where you"
echo "unpacked this, it's no longer necessary)."
echo
echo "Enjoy!"
echo
#}}}
