@echo off
setlocal enabledelayedexpansion

echo ============================================
echo  PleaseTweakWindows - Avalonia Build Script
echo ============================================
echo.

:: Check .NET SDK
dotnet --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: .NET SDK not found. Install .NET 9 SDK from https://dotnet.microsoft.com/download
    exit /b 1
)

:: Verify .NET 9
for /f "tokens=1 delims=." %%v in ('dotnet --version') do set DOTNET_MAJOR=%%v
if !DOTNET_MAJOR! LSS 9 (
    echo ERROR: .NET 9 or later is required. Found:
    dotnet --version
    exit /b 1
)

set PROJECT=PleaseTweakWindows.Avalonia\src\PleaseTweakWindows\PleaseTweakWindows.csproj
set TESTS=PleaseTweakWindows.Avalonia\src\PleaseTweakWindows.Tests\PleaseTweakWindows.Tests.csproj

echo [1/4] Running tests...
dotnet test %TESTS% -c Release --verbosity quiet
if errorlevel 1 (
    echo ERROR: Tests failed.
    exit /b 1
)
echo       Tests passed.
echo.

echo [2/4] Building Release...
dotnet build %PROJECT% -c Release --verbosity quiet
if errorlevel 1 (
    echo ERROR: Build failed.
    exit /b 1
)
echo       Build succeeded.
echo.

echo [3/4] Publishing single-file EXE...
dotnet publish %PROJECT% ^
    -c Release ^
    -r win-x64 ^
    --self-contained true ^
    -p:PublishSingleFile=true ^
    -p:IncludeNativeLibrariesForSelfExtract=true ^
    -o dist\publish
if errorlevel 1 (
    echo ERROR: Publish failed.
    exit /b 1
)
echo       Publish succeeded.
echo.

echo [4/4] Creating distribution package...
if exist dist\PleaseTweakWindows rd /s /q dist\PleaseTweakWindows
mkdir dist\PleaseTweakWindows
mkdir dist\PleaseTweakWindows\scripts

:: Copy EXE
copy dist\publish\PleaseTweakWindows.exe dist\PleaseTweakWindows\ >nul

:: Copy shared PowerShell scripts
xcopy /s /e /q src\main\resources\scripts\* dist\PleaseTweakWindows\scripts\ >nul

:: Copy docs if present
if exist README.md copy README.md dist\PleaseTweakWindows\ >nul
if exist LICENSE copy LICENSE dist\PleaseTweakWindows\ >nul

:: Create ZIP
echo       Creating ZIP archive...
pushd dist
if exist PleaseTweakWindows.zip del PleaseTweakWindows.zip
powershell -NoProfile -Command "Compress-Archive -Path 'PleaseTweakWindows\*' -DestinationPath 'PleaseTweakWindows.zip'"
popd

echo.
echo ============================================
echo  BUILD COMPLETE
echo ============================================
echo  EXE: dist\PleaseTweakWindows\PleaseTweakWindows.exe
echo  ZIP: dist\PleaseTweakWindows.zip
echo ============================================
