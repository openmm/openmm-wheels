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
%PYTHON% -m pip wheel . --wheel-dir=dist -vv
if errorlevel 1 exit 1

mkdir -p fixed_wheels
dir
dir dist

for %%f in (dist\*.whl) do (
  echo "fixing %%f"
  cd %LIBRARY_PREFIX%
  %BUILD_PREFIX%\python.exe ^
      %RECIPE_DIR%\vendor_wheel.py ^
      %SRC_DIR%\build\python\%%f ^
      include\openmm ^
      include\lepton ^
      include\OpenMM* ^
      include\AmoebaOpenMM* ^
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
  cd %SRC_DIR%\build\python
  move %%f fixed_wheels\
  if errorlevel 1 exit 1
)

cd openmm-cuda
%PYTHON% -m pip wheel . --wheel-dir=%SRC_DIR%\build\python\dist -vv
cd %SRC_DIR%\build\python

for %%f in (dist\*.whl) do (
  echo "fixing %%f"
  cd %LIBRARY_PREFIX%
  %BUILD_PREFIX%\python.exe ^
      %RECIPE_DIR%\vendor_wheel.py ^
      %SRC_DIR%\build\python\%%f ^
      lib\plugins\OpenMMCUDA.dll ^
      lib\plugins\OpenMMRPMDCUDA.dll ^
      lib\plugins\OpenMMAmoebaCUDA.dll ^
      lib\plugins\OpenMMDrudeCUDA.dll
  if errorlevel 1 exit 1
  cd %SRC_DIR%\build\python
  %PYTHON% %RECIPE_DIR%\rename_wheel.py %%f win_amd64.whl fixed_wheels
  if errorlevel 1 exit 1
)

cd %SRC_DIR%\build\python
mkdir %RECIPE_DIR%\..\build_artifacts\pypi_wheels\

for %%f in (fixed_wheels\*.whl) do (
  copy %%f %RECIPE_DIR%\..\build_artifacts\pypi_wheels\
  if errorlevel 1 exit 1
  %PYTHON% -m pip install %%f
)

rmdir /s /q %LIBRARY_LIB%\plugins
rmdir /s /q %LIBRARY_INC%\openmm
rmdir /s /q %LIBRARY_INC%\lepton
rmdir /s /q %LIBRARY_PREFIX%\examples
del /q /f %LIBRARY_LIB%\OpenMM*

goto :EOF

:error
echo Failed with error #%errorlevel%.
exit /b %errorlevel%
