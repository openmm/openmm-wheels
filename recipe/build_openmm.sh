#!/bin/bash

set -ex

if [[ "$target_platform" == "linux-"* ]]; then
  use_conda_compilers=0
else
  use_conda_compilers=1
fi

CMAKE_FLAGS="${CMAKE_ARGS} -DCMAKE_INSTALL_PREFIX=${PREFIX} -DCMAKE_BUILD_TYPE=Release"
if [[ "$with_test_suite" == "true" ]]; then
    CMAKE_FLAGS+=" -DBUILD_TESTING=ON -DOPENMM_BUILD_OPENCL_TESTS=ON -DOPENMM_BUILD_CUDA_TESTS=ON"
else
    CMAKE_FLAGS+=" -DBUILD_TESTING=OFF -DOPENMM_BUILD_CUDA_TESTS=OFF"
fi

if [[ "$use_conda_compilers" == "0" ]]; then
    # Installing just centos-release-scl would use https://mirror.centos.org which is deprecated now.
    # Install a repo that has https://vault.centos.org in it.
    /usr/bin/sudo -n yum install -y https://github.com/isuruf/isuruf.github.io/releases/download/v1.0/centos-release-scl-7-9.2009.noarch.rpm
    /usr/bin/sudo -n yum install -y devtoolset-10-gcc "devtoolset-10-gcc-c++"
    source /opt/rh/devtoolset-10/enable
    LIBGCC_DIR=$(dirname $(gcc -print-libgcc-file-name))
    export LDFLAGS="-L$LIBGCC_DIR $LDFLAGS"
    export CC="$(which gcc) -L$LIBGCC_DIR"
    export CXX="$(which g++) -L$LIBGCC_DIR"
fi


if [[ "$target_platform" == linux* ]]; then
    # CFLAGS
    # JRG: Had to add -ldl to prevent linking errors (dlopen, etc)
    MINIMAL_CFLAGS+=" -O3 -ldl"
    CFLAGS+=" $MINIMAL_CFLAGS"
    CXXFLAGS+=" $MINIMAL_CFLAGS"

    # CUDA is enabled in these platforms
    if [[ "$target_platform" == linux-64 || "$target_platform" == linux-ppc64le ]]; then
        # # CUDA_HOME is defined by nvcc metapackage
        CMAKE_FLAGS+=" -DCUDA_TOOLKIT_ROOT_DIR=${CUDA_HOME}"
        # CUDA tests won't build, disable for now
        # See https://github.com/openmm/openmm/issues/2258#issuecomment-462223634
        CMAKE_FLAGS+=" -DOPENMM_BUILD_CUDA_TESTS=OFF"
        # shadow some CMAKE_ARGS bits that interfere with CUDA detection
        CMAKE_FLAGS+=" -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=BOTH"
    fi

    # OpenCL ICD
    CMAKE_FLAGS+=" -DOPENCL_INCLUDE_DIR=${PREFIX}/include"
    CMAKE_FLAGS+=" -DOPENCL_LIBRARY=${PREFIX}/lib/libOpenCL${SHLIB_EXT}"

elif [[ "$target_platform" == osx* ]]; then
    if [[ "$opencl_impl" == khronos ]]; then
        CMAKE_FLAGS+=" -DOPENCL_INCLUDE_DIR=${PREFIX}/include"
        CMAKE_FLAGS+=" -DOPENCL_LIBRARY=${PREFIX}/lib/libOpenCL${SHLIB_EXT}"
    fi
    # When using opencl_impl == apple, CMake will auto-locate it, so no need to provide the flags
    # On Conda Forge, this will result in:
    #   /Applications/Xcode_12.app/Contents/Developer/Platforms/MacOSX.platform/Developer/...
    #   ...SDKs/MacOSX10.9.sdk/System/Library/Frameworks/OpenCL.framework
    # On local builds, it might be:
    #   /System/Library/Frameworks/OpenCL.framework/OpenCL
fi

# Disambiguate swig location
CMAKE_FLAGS+=" -DSWIG_EXECUTABLE=$(which swig)"

if [[ "$use_conda_compilers" == "1" && "$target_platform" == linux-* ]]; then
    export LDFLAGS="$LDFLAGS -static-libstdc++"
fi

if [[ "$target_platform" == linux-* ]]; then
    export LDFLAGS="$LDFLAGS -Wl,--exclude-libs,ALL -Wl,-rpath,$ORIGIN/../OpenMM.libs/lib"
elif [[ "$target_platform" == osx-* ]]; then
    export LDFLAGS="$LDFLAGS -Wl,-rpath,@loader_path/../OpenMM.libs/lib -Wl,-rpath,@loader_path/."
fi

# Build in subdirectory and install.
mkdir -p build
cd build
cmake ${CMAKE_FLAGS} ${SRC_DIR}
make -j$CPU_COUNT
make install

cd python
rm -rf dist
rm -rf fixed_wheels
export OPENMM_LIB_PATH=$PREFIX/lib
export OPENMM_INCLUDE_PATH=$PREFIX/include
$PYTHON -m pip wheel . --wheel-dir=dist

# vendor include directories and libraries
for whl in $PWD/dist/*.whl; do
  pushd $PREFIX
    plugins=""
    for plugin in lib/plugins/*${SHLIB_EXT}; do
      if [[ "$plugin" != *CUDA.so ]]; then
        plugins="$plugins $plugin"
      fi
    done
    $BUILD_PREFIX/bin/python \
      $RECIPE_DIR/vendor_wheel.py \
      $whl \
      include/openmm \
      include/OpenMM* \
      include/AmoebaOpenMM* \
      include/lepton \
      lib/libOpenMM${SHLIB_EXT} \
      lib/libOpenMMRPMD${SHLIB_EXT} \
      lib/libOpenMMAmoeba${SHLIB_EXT} \
      lib/libOpenMMDrude${SHLIB_EXT} \
      $plugins
  popd
done

if [[ "$ARCH" == "64" ]]; then
  ARCH=x86_64
fi

function repair() {
  # Repair the wheels in dist
  if [[ "$target_platform" == "linux-"* ]]; then
    rm -rf $PREFIX/lib/libstdc++.*
    rm -rf $PREFIX/lib/libgcc*
    auditwheel repair dist/*.whl \
      -w $PWD/fixed_wheels \
      --plat manylinux2014_${ARCH} \
      --exclude libOpenMM.so \
      --exclude libOpenMMCUDA.so \
      --exclude libOpenMMOpenCL.so \
      --exclude libOpenMMDrude.so \
      --exclude libOpenMMAmoeba.so \
      --exclude libOpenMMRPMD.so \
      --exclude libOpenCL.so.1 \
      --exclude libcuda.so.1 \
      --exclude libcufft.so.11 \
      --exclude libcufft.so.10 \
      --exclude libnvrtc.so.11.2 \
      --exclude libnvrtc.so.12 \
      --lib-sdir=$LIB_SDIR
  else
    $BUILD_PREFIX/bin/python $(which delocate-wheel) \
      -w fixed_wheels \
      --sanitize-rpaths \
      -v \
      dist/*.whl \
      --exclude libOpenMM.dylib \
      --exclude libOpenMMCUDA.dylib \
      --exclude libOpenMMOpenCL.dylib \
      --exclude libOpenMMDrude.dylib \
      --exclude libOpenMMAmoeba.dylib \
      --exclude libOpenMMRPMD.dylib
  fi
}

LIB_SDIR=".libs/lib" repair
rm -rf dist
mkdir dist
for whl in fixed_wheels/*.whl; do
  whl_tag="${whl##*-}"
done

if [[ "$cuda_compiler_version" != "None" ]]; then
  pushd openmm-cuda
    $PYTHON -m pip wheel .
    for whl in $PWD/*.whl; do
      whl_name=$(basename $whl)
      whl_name="${whl_name::${#whl_name}-7}$whl_tag"
      pushd $PREFIX
        $BUILD_PREFIX/bin/python \
          $RECIPE_DIR/vendor_wheel.py \
          $whl \
          lib/plugins/libOpenMMCUDA.so \
          lib/plugins/libOpenMMDrudeCUDA.so \
          lib/plugins/libOpenMMAmoebaCUDA.so \
          lib/plugins/libOpenMMRPMDCUDA.so
      popd
      cp $whl ../dist/$whl_name
    done
  popd
  LIB_SDIR=".libs" repair
fi

rm -rf $PREFIX/lib/plugins
rm -rf $PREFIX/lib/libOpenMM*
rm -rf $PREFIX/include/openmm
rm -rf $PREFIX/include/lepton
rm -rf $PREFIX/share/openmm

# Copy the wheel to destination
for whl in fixed_wheels/*.whl; do
  if [[ "$build_platform" == "osx-"* ]]; then
    WHL_DEST=$RECIPE_DIR/../build_artifacts/pypi_wheels
  elif [[ "$build_platform" == "linux-"* ]]; then
    WHL_DEST=/home/conda/feedstock_root/build_artifacts/pypi_wheels
  fi
  mkdir -p $WHL_DEST
  cp $whl $WHL_DEST
done

# Install the wheel
for whl in fixed_wheels/*.whl; do
  $PYTHON -m pip install $whl
done
