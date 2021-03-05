#!/bin/bash
# Build script for lisa-fig68k
#
# This script is a flimsy alternative to a Makefile or similar, and it has been
# created for use with the EASy68k command-line assembler distributed by Ray
# Arachelian (https://github.com/rayarachelian/EASy68K-asm). If you have an
# `asy68k` binary available, you must supply a path to it here:
ASM=../EASy68K-asm/ASM68Kv5.15.4/asy68k

# You will also need a copy of the `build_bootable_disk_image.py` script from
# the `bootloader_hd` project (https://github.com/stepleton/bootloader_hd).
# Supply a path to this script here:
BUILD_HD=../bootloader_hd/build_bootable_disk_image.py 

# Finally, you'll need the `srec_cat` utility from the srecord project
# (http://srecord.sourceforge.net/). On recent Debian and similar Linux
# distributions (e.g. Ubuntu, Raspberry Pi OS), you can obtain this by running
# `apt install srecord`.
SREC_CAT=srec_cat

# After you've adapted the path specifications above, simply cd to the
# directory containing this script and then run the script without any
# arguments. In a few seconds you should end up with three compressed hard
# drive image files: forth.blu.zip, forth.dc42.zip, and forth.image.zip.

# It's possible that other 68000 assemblers that support Motorola syntax will
# work --- the code itself is fairly uncomplicated and uses no advanced
# features like macros. To adapt this build procedure to a different
# assembler, you will need to account for the following:
#
# * The assembler must produce a listing file called `forth.L68` (note capital
#   letter L). For each line of code, this listing file must list memory
#   addresses in hexadecimal, starting from the leftmost text column. At least
#   one space character must follow each address. Example:
#
#       0000092A  4E75                     200              RTS
#
# * The assembler must emit an SRecord output file called `forth.S68` (note
#   capital letter S).
#
# Look a few lines below for the phrase "Edit here" to find the place where
# the assembler is invoked. Make changes there that will cause your assembler
# to produce the outputs just mentioned.
#
# ----------
#
# This is free and unencumbered software released into the public domain.
# 
# Anyone is free to copy, modify, publish, use, compile, sell, or
# distribute this software, either in source code form or as a compiled
# binary, for any purpose, commercial or non-commercial, and by any
# means.
#
# In jurisdictions that recognize copyright laws, the author or authors
# of this software dedicate any and all copyright interest in the
# software to the public domain. We make this dedication for the benefit
# of the public at large and to the detriment of our heirs and
# successors. We intend this dedication to be an overt act of
# relinquishment in perpetuity of all present and future rights to this
# software under copyright law.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
# IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR
# OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
# ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.
#
# For more information, please refer to <http://unlicense.org>
#
# ----------
#
# Changelog:
#
# 2021/05/03: Initial release. Tom Stepleton <stepleton@gmail.com>, London


# make clean
rm -f forth.L68 forth.S68 forth.bin forth-squished.bin
rm -f forth.image forth.dc42 forth.blu
rm -f forth.image.zip forth.dc42.zip forth.blu.zip

# Assemble and look for errors in the listing
$ASM --macroexpand forth.x68  # XXX Edit here to use a different assembler XXX
grep 'errors detected' forth.L68
grep -C 4 -m 1 ERROR: forth.L68

# If the assembly succeded, then build drive images
# XXX You may have to modify this "success detection" heuristic here, too XXX
if grep -q 'No errors detected' forth.L68; then
  # Convert ASM68K S-record output to binary
  $SREC_CAT -Disable-Sequence-Warnings forth.S68 \
     --offset -0x800 -o forth.bin -binary

  # Identify how much of that binary comes before the big run of zeros that
  # make up the free space for user definitions
  part1hexbytes=$(grep 'INITDP.*EQU' forth.L68 | cut -f 1 -d ' ')
  part1size=$((0x$part1hexbytes - 0x800))

  # Copy that part of the binary into a new file
  dd if=forth.bin of=forth-squished.bin bs=$part1size count=1 status=none

  # Identify the size and starting location of the binary that goes after
  # big run of zeros
  part2hexstart=$(grep 'kHiMemStart.*EQU' forth.L68 | cut -f 1 -d ' ')
  part2hexend=$(grep 'kHiMemEnd.*EQU' forth.L68 | cut -f 1 -d ' ')
  part2size=$((0x$part2hexend - 0x$part2hexstart))
  part2skipbytes=$((0x$part2hexstart - 0x800))

  # Tack it onto the binary data just under construction---no big run of zeros
  dd if=forth.bin of=forth-squished.bin skip=$part2skipbytes \
     bs=$part2size count=1 status=none \
     iflag=skip_bytes oflag=append conv=notrunc

  # Assemble the hard drive images
  python3 -B $BUILD_HD forth-squished.bin -f raw -o forth.image
  python3 -B $BUILD_HD forth-squished.bin -f dc42 -o forth.dc42
  python3 -B $BUILD_HD forth-squished.bin -f blu -o forth.blu

  # And package them into zip archives
  for i in image dc42 blu; do zip forth.$i.zip forth.$i; done
fi
