#!/bin/bash
set -ex
with_cuda="no"

## Do they work properly?
# Debug silent errors in plugin loading
python -c "import openmm as mm; print('---Loaded---', *mm.pluginLoadedLibNames, '---Failed---', *mm.Platform.getPluginLoadFailures(), sep='\n')"
# Check that hardcoded library path was correctly replaced by conda-build
python -c "import os, openmm.version as v; print(v.openmm_library_path); assert os.path.isdir(v.openmm_library_path), 'Directory does not exist'"

# Check all platforms
if [[ "$target_platform" == linux-ppc64le || "$target_platform" == linux-aarch64 ]]; then
    python -m openmm.testInstallation || true  # OpenCL will fail but that's ok
else
    python -m openmm.testInstallation
fi
if [[ $with_cuda == yes ]]; then
    # Linux64 / PPC see all 4 platforms, but CUDA is not usable because there's no GPU there
    n_platforms=4
else
    # MacOS / ARM only see 3 because CUDA is not available there
    n_platforms=3
fi
# testing cuda 12 changes, see https://github.com/conda-forge/openmm-feedstock/pull/108#issuecomment-1692190752
#python -c "from openmm import Platform as P; n = P.getNumPlatforms(); assert n == $n_platforms, f'n_platforms ({n}) != $n_platforms'"

# Check version metadata looks ok, only for final releases, RCs are not checked!
if [[ ${PKG_VERSION} != *"rc"* && ${PKG_VERSION} != *"beta"* && ${PKG_VERSION} != *"dev"* ]]; then
    python -c "from openmm import Platform; v = Platform.getOpenMMVersion(); assert \"$PKG_VERSION\" in (v, v+'.0'), v + \"!=$PKG_VERSION\""
    git_revision=$(git ls-remote https://github.com/openmm/openmm.git $PKG_VERSION | awk '{ print $1}')
    python -c "from openmm.version import git_revision; r = git_revision; assert r == \"$git_revision\", r + \"!=$git_revision\""
else
    echo "!!! WARNING !!!"
    echo "This is a release candidate build ($PKG_VERSION). Please check versions and git hashes manually!"
fi

if [[ $with_test_suite == "true" ]]; then
    # Python tests
    set -ex
    cd python
    python -m pytest -v -n $CPU_COUNT
fi
