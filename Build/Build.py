
import argparse
import glob
import os
import platform
import subprocess
import sys
import time

from datetime import datetime, timedelta
from shutil import copyfile

def doBuild(buildTarget):

    dflags = []
    lflags = []
    libs = []
    postbuild = lambda: None

    dsrcs = glob.iglob('source/**/*.d', recursive = True)

    if platform.system() == 'Windows':
        if buildTarget == 'impl':
            dflags = [
                '-of../build/bin/impl.exe',
                '-I../opengl/source/',
                '-I../runtime/source/',
                '-I../build/imports/',
            ]

            libs = [ 'OpenAL32.lib', 'opengl.lib', 'sdl2.lib', 'libvorbis.lib', 'libvorbisfile.lib' ]

        elif buildTarget == 'opengl':
            dflags = [
                '-shared',
                '-of../build/bin/opengl.dll',
            ]

            lflags = [ '-L/IMPLIB:../build/lib/opengl.lib' ]

        elif buildTarget == 'runtime':
            uniqueIdentifer = datetime.today().strftime('%Y%m%d-%H%M%S')

            dflags = [
                '-shared',
                '-of../build/bin/runtime_out.dll',
                '-I../opengl/source/',
                '-I../build/imports/',
                '-Jtext/',
            ]

            lflags = [ '-L/PDB:../build/obj/runtime-' + uniqueIdentifer + '.pdb' ]
            libs = [ 'OpenAL32.lib', 'opengl.lib', 'sdl2.lib', 'cimgui.lib', 'libvorbis.lib', 'libvorbisfile.lib' ]

            # possible .dll is created before .pdb, thus dll is loaded without symbols
            # so store it else where and copy it after everything is linked and ready
            postbuild = lambda: copyfile('../build/bin/runtime_out.dll', '../build/bin/runtime.dll')

    else:
        print('Error: Unknown platform ' + platform.system() + '.')
        return

    args = [
        'dmd',
        '-m64',
        '-mscrtlib=msvcrt',
        # '-w',           # warnings
        '-de',          # treat deprecation as errors
        '-gc',          # debug symbols (C format)
        #'-inline',
        *dflags,
        *dsrcs,
        '-L/LIBPATH:../build/lib/',
        '-L/LIBPATH:/D/dmd2/windows/lib64/',
        '-L/LIBPATH:\"/Program Files (x86)/Windows Kits/10/Lib/10.0.14393.0/um/x64\"',
        '-L/LIBPATH:\"/Program Files (x86)/Windows Kits/10/Lib/10.0.14393.0/ucrt/x64\"',
        *lflags,
        *libs,
    ]

    print('running: ' + ' '.join(args), flush=True)

    try:
        print(subprocess.check_output(args).decode('ascii', errors='surrogateescape'))
        postbuild()
    except subprocess.CalledProcessError as ex:
        print(ex.output.decode('ascii', errors='surrogateescape'))



# main ------------------------------------------------------------------------

startTime = time.clock()

parser = argparse.ArgumentParser()
parser.add_argument('build', action='append', choices = ['impl', 'opengl', 'runtime', 'all'])
args = parser.parse_args()


if args.build[0] == 'all':
    args.build = [ 'opengl', 'impl', 'runtime' ] # order matters!

for b in args.build:
    os.chdir(b)
    doBuild(b)
    os.chdir('..')


print('total time: ' + str(timedelta(seconds=time.clock() - startTime)))
