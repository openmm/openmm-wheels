import sys
from os.path import join as pjoin
import os
import shutil
from glob import glob
import tempfile
import subprocess

from delocate import wheeltools

cwd = os.getcwd()

def add_library(lib_paths, wheel_name):
    print('Processing', wheel_name)
    with wheeltools.InWheel(wheel_name, wheel_name):
        for lib_path in lib_paths:
            d = os.path.dirname(pjoin('OpenMM.libs', lib_path))
            os.makedirs(d, exist_ok=True)
            f = pjoin(cwd, lib_path)
            if os.path.isdir(f):
                shutil.copytree(f, pjoin('OpenMM.libs', lib_path), dirs_exist_ok=True)
            else:
                shutil.copy2(f, pjoin('OpenMM.libs', lib_path))

def main():
    args = list(sys.argv)
    args.pop(0)
    dist_path = args.pop(0)
    lib_paths = []
    for arg in args:
        lib_paths.extend(glob(arg))
    add_library(lib_paths, dist_path)

if __name__ == '__main__':
    main()
