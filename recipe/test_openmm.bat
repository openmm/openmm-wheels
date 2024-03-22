@echo on

:: Are we running on CI? CONFIG is defined for the whole Azure pipeline
:: and we are bringing it in through `script_env` in meta.yaml
if not "%CONFIG%"=="" set CI="True"

:: Debug silent errors in plugin loading
python -c "import openmm as mm; print('---Loaded---', *mm.pluginLoadedLibNames, '---Failed---', *mm.Platform.getPluginLoadFailures(), sep='\n')"

:: Check that hardcoded library path was correctly replaced by conda-build
python -c "import os, openmm.version as v; print(v.openmm_library_path); assert os.path.isdir(v.openmm_library_path), 'Directory does not exist'" || goto :error

:: Check all platforms
python -m openmm.testInstallation

:: On CI, Windows will only see 2 platforms because the driver nvcuda.dll is missing and that throws a 126 error
:: We expect that people running this locally will have Nvidia properly installed, so they should all platforms (4)
if "%CI%"=="" (
    set n_platforms=4
) else (
    set n_platforms=2
)
python -c "from openmm import Platform as P; n = P.getNumPlatforms(); assert n == %n_platforms%, f'n_platforms ({n}) != %n_platforms%'" || goto :error

(set \n=^
%=This hack is required to store newlines=%
)

:: Run the full test suite, if requested
if "%with_test_suite%"=="true" (
    SETLOCAL EnableDelayedExpansion
    @echo off
    cd %LIBRARY_PREFIX%\share\openmm\tests

    :: Start with C++ tests
    if not "%CI%"=="" (
        del /Q /F TestCuda* TestOpenCL*
    )
    set count=0
    set exitcode=0
    set summary=
    FOR %%F IN ( Test* ) do (
        set testexe=%%~F
        set /a count=!count!+1
        echo;
        echo #!count!: !testexe!
        .\!testexe!
        set thisexitcode=!errorlevel!
        set summary=!summary!
        if not "!thisexitcode!"=="0" ( set "summary=!summary!#!count! !testexe!\n!" )
        set /a exitcode=!exitcode!+!thisexitcode!
    )
    if not "!exitcode!"=="0" (
        echo;
        echo ------------
        echo Failed tests
        echo ------------
        echo;
        echo !summary!
        exit /b !exitcode!
    )
    @echo on
    :: Python unit tests
    cd python
    python -m pytest -v -n %CPU_COUNT% || goto :error

    ENDLOCAL
)

goto :EOF

:error
echo Failed with error #%errorlevel%.
exit /b %errorlevel%
