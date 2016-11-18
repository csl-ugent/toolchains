# Diablo Toolchains

This repository provides a script able to build a number of toolchains that produce
[Diablo][1]-compatible binaries. The supported combinations can be listed by executing the commad `./build.sh -h`.

**Please note** that when building an LLVM toolchain the result will only use
LLVM/clang to compile. Assembling and linking will still require a GCC/Binutils
toolchain built with this script. We did however make the necessary fixes in
order for the resulting clang compiler to invoke the Binutils tools without
issues ( but with some required arguments ).

When using the built toolchain some arguments are required to produce a rewriteable
binary. The `example` directory contains two makefiles showing what extra arguments
to pass when using a toolchain;

- When invoking GCC for ARM the linker needs the following arguments:

    `-Wl,--no-merge-exidx-entries`

- Clang needs these to be able to use Binutils for assembling and linking (with
TRIPLET either being "arm-diablo-linux-gnueabi" or "i486-diablo-linux-gnu"):

    `-isysroot $(TCPATH)/$(BINUTILSPREFIX)/sysroot -no-integrated-as -gcc-toolchain $(TCPATH) -ccc-gcc-name TRIPLET -target TRIPLET`

- When compiling for x86 these arguments are needed with both Clang an GCC:

    `-march=i486 -m32`

**Remark** whenever you want to rewrite a binary with Diablo the object files have
to be available. In order to enforce this make sure to pass the `-save-temps` flag
when compiling.

## Repository Overview
None of the files in the following directories should be changed in order to build
a toolchain. Only modify them if you know what you are doing.

- **diablo-patches**
This directory contains all our patches for the different versions of GCC,
LLVM, EGLIBC and Binutils. The patches found in here are applied when building
a toolchain that uses the corresponding versions of the tools.

- **config**
A collection of all our crosstool-ng configuration files. One such file can be
found in here for each supported toolchain version.

- **example**
This folder contains an example 'Hello World'-project with makefiles for i486
and arm. The makefiles are set up with all the necessary options to compile for
and rewrite with Diablo.

- **package**
This directory contains some templates for building Debian packages of the
toolchains.

## Prerequisites
The following packages are assumed to be installed on the system where you want to build tool chains:
- gperf
- flex
- bison
- g++
- libncurses-dev
- subversion
- git

On Debian-based Linux distributions, these packages can be installed like this:
```
sudo apt-get install gperf flex bison g++ libncurses-dev subversion git
```

## Usage
All the required functionality implemented in this repository is accessible through a single shell script, `build.sh`, in the root of this repository. Documentation on how this script should be invoked can be retrieved by running the following command:
```
./build.sh -h
```

##### Example 
The followig command generates a Diablo-compatible GCC 4.8.1/binutils 2.22 toolchain for generating i486-compatible binaries:
```
./build.sh -a i486 -d /opt/my-toolchain -c 0 -n 5
```
    
  [1]: http://diablo.elis.ugent.be/
