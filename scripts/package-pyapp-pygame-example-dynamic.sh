#!/bin/bash -e

# Packages pygame-example files with pygame_sdl2 as .so-s

# Copyright (C) 2019  Sylvain Beucler

# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.


FILE_PACKAGER="python $(dirname $(which emcc))/tools/file_packager.py"
PACKAGEDIR=build/package-pyapp-pygame-example
OUTDIR=build/t


rm -rf $PACKAGEDIR/
mkdir -p $PACKAGEDIR

# Compile Ren'Py Python scripts
for i in $(cd pygame-example/ && find . -name "*.py"); do
    if [ pygame-example/$i -nt pygame-example/${i%.py}.pyo ]; then
	python -OO -m py_compile pygame-example/$i
    fi
done

# Copy game data and remove source files
cp -a pygame-example/* $PACKAGEDIR/
# pygame_sdl2-dynamic
# TODO: store .so variants for ASMJS and for WASM somewhere
mkdir -p $PACKAGEDIR/lib/python2.7/site-packages/pygame_sdl2/threads
for i in $(cd install && find lib/python2.7/site-packages/pygame_sdl2/ -name "*.pyo" -o -name "*.so"); do
   cp -a install/$i $PACKAGEDIR/$i
done
find $PACKAGEDIR/ \( -name "*.py" -o -name "*.pyc" \
    -o -name "*.pyx" -o -name "*.pxd" \
    -o -name "*.rpy" -o -name "*.rpym" \) -print0 \
  | xargs -r0 rm

# Entry point
# TODO: Python doesn't like .pyo entry points?
cp -aL pygame-example/main.py $PACKAGEDIR/main.py

# use-preload-plugins to pre-compile .so-s in Chromium on startup
# https://emscripten.org/docs/porting/files/packaging_files.html#preloading-files
preloadso=''
if [ "$1" == "wasm" ]; then
    preloadso='--use-preload-plugins'
fi
    preloadso='--use-preload-plugins'
$FILE_PACKAGER \
    $OUTDIR/pyapp.data --js-output=$OUTDIR/pyapp-data.js \
    --preload $PACKAGEDIR@/ \
    $preloadso \
    --use-preload-cache --no-heap-copy
