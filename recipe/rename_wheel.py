import os
import shutil
import sys

def rename(fname, new_suffix, new_dest):
    assert fname.endswith(".whl")
    prefix, dash, _ = fname.rpartition("-")
    new_fname = os.path.basename(prefix + dash + new_suffix)
    shutil.move(fname, os.path.join(new_dest, new_fname))

if __name__ == "__main__":
    rename(*sys.argv[1:])
