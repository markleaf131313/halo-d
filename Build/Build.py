
import argparse
import glob
import os
import platform
import subprocess
import sys
import time

from datetime import datetime, timedelta
from shutil import copyfile

def genMultiLoop(*args):

    values = [ 0 ] * len(args)

    while True:
        yield values

        values[-1] += 1

        i = len(args) - 1
        while values[i] > args[i]:
            if i <= 0:
                return

            values[i] = 0
            values[i - 1] += 1
            i -= 1



def doBuild(buildTarget):

    dflags = []
    lflags = []
    libs = []
    prebuild = lambda: None
    postbuild = lambda: None

    dsrcs = glob.iglob('Source/**/*.d', recursive = True)

    if buildTarget == 'Runtime':
        dflags = [
            '-shared',
            '-I../Build/Imports/',
            '-JText/',
            '-JData/',
        ]

    if platform.system() == 'Windows':
        dflags += [ '-mscrtlib=msvcrt', ]
        lflags += [ '-L/LIBPATH:../Build/Lib/Windows/x64', ]

        if buildTarget == 'Impl':
            dflags += [
                '-of../Build/Bin/Windows/impl.exe',
                '-I../Runtime/Source/',
                '-I../Build/Imports/',
            ]

            libs += [ 'OpenAL32.lib', 'vulkan-1.lib', 'SDL2.lib', 'libvorbis.lib', 'libvorbisfile.lib' ]

        elif buildTarget == 'Runtime':
            def buildBinary(src, dst, defines=[]):
                prog = 'glslangValidator'

                args = [
                    prog,
                    '-V', src,
                    '-o', dst,
                    *defines,
                ]

                print('Running: ', ' '.join(args))
                print(subprocess.check_output(args).decode('ascii', errors='surrogateescape'))

            def buildShaders():
                buildBinary('../Shaders/DebugFrameBuffer.vert', './Data/DebugFrameBuffer-vert.spv')
                buildBinary('../Shaders/DebugFrameBuffer.frag', './Data/DebugFrameBuffer-frag.spv')

                buildBinary('../Shaders/Env.vert', './Data/Env-vert.spv')

                for t, detail, micro in genMultiLoop(2, 2, 2):
                    buildBinary(
                        '../Shaders/Env.frag', './Data/Env-frag-{}-{}-{}.spv'.format(t, detail, micro),
                        [
                            '-DTYPE={}'.format(t),
                            '-DFUNCT_DETAIL={}'.format(detail),
                            '-DFUNCT_MICRO={}'.format(micro),
                        ]
                    )

                    # TODO fix ordering of print
                    # print('Running: ', ' '.join(args))
                    subprocess.check_output(args).decode('ascii', errors='surrogateescape')


            prebuild = buildShaders

            uniqueIdentifer = datetime.today().strftime('%Y%m%d-%H%M%S')

            dflags += [ '-of../Build/Bin/Windows/runtime_out.dll' ]
            lflags += [ '-L/PDB:../Build/Obj/runtime-' + uniqueIdentifer + '.pdb' ]
            libs += [ 'OpenAL32.lib', 'vulkan-1.lib', 'SDL2.lib', 'cimgui.lib', 'libvorbis.lib', 'libvorbisfile.lib' ]

            # possible .dll is created before .pdb, thus dll is loaded without symbols
            # so store it else where and copy it after everything is linked and ready
            postbuild = lambda: copyfile('../Build/Bin/Windows/runtime_out.dll', '../Build/Bin/Windows/runtime.dll')
    elif platform.system() == 'Linux':
        print("Support for building on Linux removed for now")
        return
        # if buildTarget == 'Impl':
        #     dflags = [
        #         '-defaultlib=libphobos2.so',
        #         '-of../Build/Bin/Linux/impl',
        #         '-I../OpenGL/Source/',
        #         '-I../Runtime/Source/',
        #         '-I../Build/Imports/',
        #     ]

        #     lflags = [ '-L-L../Build/Bin/Linux/' ]
        #     libs = [ '-L-lopenal', '-L-lopengl', '-L-lSDL2', '-L-lvorbis', '-L-lvorbisfile' ]

        # elif buildTarget == 'OpenGL':
        #     dflags = [
        #         '-defaultlib=libphobos2.so',
        #         '-shared',
        #         '-fPIC',
        #         '-of../Build/Bin/Linux/libopengl.so',
        #     ]

        # elif buildTarget == 'Runtime':
        #     dflags += [
        #         '-defaultlib=libphobos2.so',
        #         '-fPIC',
        #         '-of../Build/Bin/Linux/libruntime.so',
        #     ]

        #     lflags = [ '-L-L../Build/Bin/Linux/' ]
        #     libs = [ '-L-lopenal', '-L-lopengl', '-L-lSDL2', '-L-lcimgui', '-L-lvorbis', '-L-lvorbisfile' ]

    else:
        print('Error: Unknown platform ' + platform.system() + '.')
        return

    args = [
        'dmd',
        '-m64',
        # '-w',           # warnings
        # '-de',          # treat deprecation as errors
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
        prebuild()
        print(subprocess.check_output(args).decode('ascii', errors='surrogateescape'))
        postbuild()
    except subprocess.CalledProcessError as ex:
        print(ex.output.decode('ascii', errors='surrogateescape'))
        print('--- failed ---')



# main ------------------------------------------------------------------------

startTime = datetime.now()

parser = argparse.ArgumentParser()
parser.add_argument('build', action='append', choices = ['Impl', 'Runtime', 'all'])
args = parser.parse_args()


if args.build[0] == 'all':
    args.build = [ 'Impl', 'Runtime' ] # order matters!

for b in args.build:
    os.chdir(b)
    doBuild(b)
    os.chdir('..')


print('total time: ' + str(datetime.now() - startTime))
