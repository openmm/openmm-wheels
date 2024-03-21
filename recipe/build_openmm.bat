@echo on
setlocal EnableDelayedExpansion

mkdir build
cd build

set "CUDA_TOOLKIT_ROOT_DIR=%CUDA_PATH:\=/%"

if "%with_test_suite%"=="true" (
    set "CMAKE_FLAGS=-DBUILD_TESTING=ON  -DOPENMM_BUILD_CUDA_TESTS=ON  -DOPENMM_BUILD_OPENCL_TESTS=ON"
) else (
    set "CMAKE_FLAGS=-DBUILD_TESTING=OFF -DOPENMM_BUILD_CUDA_TESTS=OFF -DOPENMM_BUILD_OPENCL_TESTS=OFF"
)

cmake.exe .. -G "NMake Makefiles JOM" ^
    -DCMAKE_BUILD_TYPE=Release ^
    -DCMAKE_INSTALL_PREFIX="%LIBRARY_PREFIX%" ^
    -DCMAKE_PREFIX_PATH="%LIBRARY_PREFIX%" ^
    -DCUDA_TOOLKIT_ROOT_DIR="%CUDA_TOOLKIT_ROOT_DIR%" ^
    -DOPENCL_INCLUDE_DIR="%LIBRARY_INC%" ^
    -DOPENCL_LIBRARY="%LIBRARY_LIB%\opencl.lib" ^
    %CMAKE_FLAGS% ^
    || goto :error

jom -j %NUMBER_OF_PROCESSORS% || goto :error
jom -j %NUMBER_OF_PROCESSORS% install || goto :error

cd python
rmdir /s /q dist
rmdir /s /q fixed_wheels
set "OPENMM_LIB_PATH=%LIBRARY_LIB%"
set "OPENMM_INCLUDE_PATH=%LIBRARY_INC%"
%PYTHON% -m pip wheel . --wheel-dir=dist
if errorlevel 1 exit 1

dir
dir dist

cd %LIBRARY_PREFIX%
for %%f in (dist\*.whl) do (
  echo "fixing %%f"
  %PYTHON% ^
      %RECIPE_DIR%\vendor_wheel.py ^
      %%f ^
      include\openmm ^
      include\lepton ^
      lib\OpenMM.dll ^
      lib\OpenMMRPMD.dll ^
      lib\OpenMMAmoeba.dll ^
      lib\OpenMMDrude.dll ^
      lib\plugins\OpenMMOpenCL.dll ^
      lib\plugins\OpenMMRPMDOpenCL.dll ^
      lib\plugins\OpenMMAmoebaOpenCL.dll ^
      lib\plugins\OpenMMDrudeOpenCL.dll ^
      lib\plugins\OpenMMCPU.dll ^
      lib\plugins\OpenMMRPMDReference.dll ^
      lib\plugins\OpenMMAmoebaReference.dll ^
      lib\plugins\OpenMMDrudeReference.dll
  if errorlevel 1 exit 1
  delvewheel repair ^
    -w %cd%\fixed_wheels ^
    --lib-sdir=.libs\lib ^
    ----ignore-in-wheel ^
    --no-dll OpenCL.dll
  if errorlevel 1 exit 1
)
cd %SRC_DIR%\build\python

for %%f in (fixed_wheels\*.whl) do (
  copy %%f %RECIPE_DIR%\..\build_artifacts\pypi_wheels\
  if errorlevel 1 exit 1
  %PYTHON% -m pip install %%f
)

goto :EOF

:error
echo Failed with error #%errorlevel%.
exit /b %errorlevel%
