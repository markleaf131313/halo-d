
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

    dsrcs = glob.iglob('Source/**/*.d', recursive = True)

    if buildTarget == 'Runtime':
        dflags = [
            '-shared',
            '-I../OpenGL/Source/',
            '-I../Build/Imports/',
            '-JText/',
        ]

    if platform.system() == 'Windows':
        dflags += [ '-mscrtlib=msvcrt', ]
        lflags += [ '-L/LIBPATH:../Build/Lib/', ]

        if buildTarget == 'Impl':
            dflags += [
                '-of../Build/Bin/Windows/impl.exe',
                '-I../OpenGL/Source/',
                '-I../Runtime/Source/',
                '-I../Build/Imports/',
            ]

            libs += [ 'OpenAL32.lib', 'opengl.lib', 'sdl2.lib', 'libvorbis.lib', 'libvorbisfile.lib' ]

        elif buildTarget == 'OpenGL':
            dflags += [
                '-shared',
                '-of../Build/Bin/Windows/opengl.dll',
            ]

            lflags += [ '-L/IMPLIB:../Build/Lib/opengl.lib' ]

        elif buildTarget == 'Runtime':
            uniqueIdentifer = datetime.today().strftime('%Y%m%d-%H%M%S')

            dflags += [ '-of../Build/Bin/Windows/runtime_out.dll' ]
            lflags += [ '-L/PDB:../Build/Obj/runtime-' + uniqueIdentifer + '.pdb' ]
            libs += [ 'OpenAL32.lib', 'opengl.lib', 'sdl2.lib', 'cimgui.lib', 'libvorbis.lib', 'libvorbisfile.lib' ]

            # possible .dll is created before .pdb, thus dll is loaded without symbols
            # so store it else where and copy it after everything is linked and ready
            postbuild = lambda: copyfile('../Build/Bin/Windows/runtime_out.dll', '../Build/Bin/Windows/runtime.dll')
    elif platform.system() == 'Linux':
        if buildTarget == 'Impl':
            dflags = [
                '-defaultlib=libphobos2.so',
                '-of../Build/Bin/Linux/impl',
                '-I../OpenGL/Source/',
                '-I../Runtime/Source/',
                '-I../Build/Imports/',
            ]

            lflags = [ '-L-L../Build/Bin/Linux/' ]
            libs = [ '-L-lopenal', '-L-lopengl', '-L-lSDL2', '-L-lvorbis', '-L-lvorbisfile' ]

        elif buildTarget == 'OpenGL':
            dflags = [
                '-defaultlib=libphobos2.so',
                '-shared',
                '-fPIC',
                '-of../Build/Bin/Linux/libopengl.so',
            ]

        elif buildTarget == 'Runtime':
            dflags += [
                '-defaultlib=libphobos2.so',
                '-fPIC',
                '-of../Build/Bin/Linux/libruntime.so',
            ]

            lflags = [ '-L-L../Build/Bin/Linux/' ]
            libs = [ '-L-lopenal', '-L-lopengl', '-L-lSDL2', '-L-lcimgui', '-L-lvorbis', '-L-lvorbisfile' ]

            # possible .dll is created before .pdb, thus dll is loaded without symbols
            # so store it else where and copy it after everything is linked and ready
            # postbuild = lambda: copyfile('../build/bin/runtime_out.dll', '../build/bin/runtime.dll')
    else:
        print('Error: Unknown platform ' + platform.system() + '.')
        return

    args = [
        'dmd',
        '-m64',
        # '-w',           # warnings
        '-de',          # treat deprecation as errors
        '-g',           # debug symbols (C format)
        '-debug',
        #'-inline',
        *dflags,
        *dsrcs,
        *lflags,
        *libs,
    ]

    print('running: ' + ' '.join(args), flush=True)

    try:
        print(subprocess.check_output(args).decode('ascii', errors='surrogateescape'))
        postbuild()
    except subprocess.CalledProcessError as ex:
        print(ex.output.decode('ascii', errors='surrogateescape'))
        print('--- failed ---')



# main ------------------------------------------------------------------------

startTime = datetime.now()

parser = argparse.ArgumentParser()
parser.add_argument('build', action='append', choices = ['Impl', 'OpenGL', 'Runtime', 'all'])
args = parser.parse_args()


if args.build[0] == 'all':
    args.build = [ 'OpenGL', 'Impl', 'Runtime' ] # order matters!

for b in args.build:
    os.chdir(b)
    doBuild(b)
    os.chdir('..')


print('total time: ' + str(datetime.now() - startTime))
