#!/bin/bash -ex
# Cross-compile pygame_sdl2 for Emscripten, as dynamic modules

# Copyright (C) 2019  Sylvain Beucler

# Permission is hereby granted, free of charge, to any person
# obtaining a copy of this software and associated documentation files
# (the "Software"), to deal in the Software without restriction,
# including without limitation the rights to use, copy, modify, merge,
# publish, distribute, sublicense, and/or sell copies of the Software,
# and to permit persons to whom the Software is furnished to do so,
# subject to the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

CACHEROOT=$(dirname $(readlink -f $0))/../cache
BUILD=$(dirname $(readlink -f $0))/../build
INSTALLDIR=$(dirname $(readlink -f $0))/../install
PATCHESDIR=$(dirname $(readlink -f $0))/../patches
HOSTPYTHON=$(dirname $(readlink -f $0))/../python-emscripten/2.7.10/build/hostpython/bin/python

PYGAME_SDL2_ROOT=$BUILD/pygame_sdl2-dynamic
if [ ! -d "$PYGAME_SDL2_ROOT/.git" ]; then
    git clone https://github.com/renpy/pygame_sdl2 $PYGAME_SDL2_ROOT
    (cd "$PYGAME_SDL2_ROOT" && git checkout f2b6ff38d5793a1904970daa192915da377bb315)  # master as of 2018-11-19
else
    : #(cd "$PYGAME_SDL2_ROOT" && git pull)
fi

(
    cd $PYGAME_SDL2_ROOT/
    if [ ! -e .pc ]; then
	QUILT_SERIES=series-dynamic QUILT_PATCHES=$PATCHESDIR/pygame_sdl2 quilt push -a
    fi
    # PYGAME_SDL2_CFLAGS='': inhibit running sdl2-config --cflags
    # PYGAME_SDL2_LDFLAGS='': inhibit running sdl2-config --libs
    CC=emcc LDSHARED=emcc \
      CFLAGS="-I$INSTALLDIR/include -I$INSTALLDIR/include/SDL2 -s USE_SDL=2 -s USE_SDL_TTF=2 -s USE_ZLIB=1" \
      LDFLAGS="" \
      PYGAME_SDL2_CFLAGS='' PYGAME_SDL2_LDFLAGS='' \
      $HOSTPYTHON \
      setup.py \
        build_ext --include-dirs $INSTALLDIR/include/python2.7 \
          -t emscripten-dynamic/build-temp \
        build \
	install -O2 --prefix $INSTALLDIR
    $HOSTPYTHON setup.py install_headers -d $INSTALLDIR/include/
    
    # https://github.com/emscripten-core/emscripten/wiki/Linking
    # https://github.com/emscripten-core/emscripten/wiki/WebAssembly-Standalone
    (
	cd $INSTALLDIR/lib/python2.7/site-packages/pygame_sdl2/
	for i in *.so; do
            if file $i | grep -q 'LLVM IR bitcode'; then
		base=${i%.so}
		mv $i $base.bc
		# TODO: store .so variants for ASMJS and for WASM somewhere
		# ASMJS
		#emcc $base.bc -o $base.js \
                #     -s SIDE_MODULE=1 -s EXPORT_ALL=1 \
		#     -s EMULATE_FUNCTION_POINTER_CASTS=1 -O2 -s WASM=0
		#mv $base.js $base.so
		# WASM
		emcc $base.bc -o $base.wasm \
                     -s SIDE_MODULE=1 -s EXPORT_ALL=1 \
		     -s EMULATE_FUNCTION_POINTER_CASTS=1 -O2
		mv $base.wasm $base.so
            fi
	done
    )
)
