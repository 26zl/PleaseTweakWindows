@echo off
setlocal enabledelayedexpansion

echo ============================================
echo  PleaseTweakWindows - WPF Build Script
echo ============================================
echo.

:: Check .NET SDK. SDK selection is pinned to .NET 10 by global.json.
dotnet --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: No compatible .NET SDK found. Install the .NET 10 SDK from
    echo        https://dotnet.microsoft.com/download ^(see global.json^).
    exit /b 1
)

:: This project targets net10.0-windows and requires the .NET 10 SDK.
for /f "tokens=1 delims=." %%v in ('dotnet --version') do set DOTNET_MAJOR=%%v
if NOT "!DOTNET_MAJOR!"=="10" (
    echo ERROR: The .NET 10 SDK is required. Found:
    dotnet --version
    exit /b 1
)

set PROJECT=src\PleaseTweakWindows\PleaseTweakWindows.csproj
set TESTS=src\PleaseTweakWindows.Tests\PleaseTweakWindows.Tests.csproj

echo [1/4] Restoring (locked) and running tests...
:: --locked-mode fails if packages.lock.json is stale, matching CI: the committed lock
:: files are the source of truth for a reproducible restore. Tests/build then run
:: --no-restore against it. (Publish below restores unlocked — see its note.)
dotnet restore PleaseTweakWindows.sln --locked-mode
if errorlevel 1 (
    echo ERROR: Locked restore failed - packages.lock.json is out of date.
    echo        Run "dotnet restore" and commit the updated lock files.
    exit /b 1
)
:: NOTE: Build.bat is a LOCAL convenience gate that runs only a SUBSET of CI.
:: It does NOT run PSScriptAnalyzer, Test-ActionRouting, checksum-freshness checks,
:: or the coverage floor. A green Build.bat does NOT guarantee green CI; use the
:: GitHub Actions workflow as the source of truth before tagging a release.
dotnet test %TESTS% -c Release --no-restore --verbosity quiet -p:TreatWarningsAsErrors=true
if errorlevel 1 (
    echo ERROR: Tests failed.
    exit /b 1
)
echo       Tests passed.
echo.

echo [2/4] Building Release...
dotnet build %PROJECT% -c Release --no-restore --verbosity quiet -p:TreatWarningsAsErrors=true
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
    --no-restore ^
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

:: Copy EXE (scripts are embedded; the EXE is self-contained)
copy dist\publish\PleaseTweakWindows.exe dist\PleaseTweakWindows\ >nul

:: Copy docs if present
if exist README.md copy README.md dist\PleaseTweakWindows\ >nul
if exist LICENSE copy LICENSE dist\PleaseTweakWindows\ >nul
if exist THIRD-PARTY-NOTICES.md copy THIRD-PARTY-NOTICES.md dist\PleaseTweakWindows\ >nul
if exist licenses xcopy licenses dist\PleaseTweakWindows\licenses\ /e /i /q >nul

:: Include the .NET redistribution notices when the SDK layout exposes them.
for /f "delims=" %%d in ('where dotnet 2^>nul') do (
    set DOTNET_DIR=%%~dpd
    goto :dotnet_notices
)
:dotnet_notices
if not defined DOTNET_DIR (
    echo ERROR: Could not locate the .NET installation directory.
    exit /b 1
)
if not exist "!DOTNET_DIR!LICENSE.txt" (
    echo ERROR: .NET redistribution LICENSE.txt not found under !DOTNET_DIR!.
    exit /b 1
)
if not exist "!DOTNET_DIR!ThirdPartyNotices.txt" (
    echo ERROR: .NET redistribution ThirdPartyNotices.txt not found under !DOTNET_DIR!.
    exit /b 1
)
copy "!DOTNET_DIR!LICENSE.txt" dist\PleaseTweakWindows\licenses\dotnet-LICENSE.txt >nul
copy "!DOTNET_DIR!ThirdPartyNotices.txt" dist\PleaseTweakWindows\licenses\dotnet-ThirdPartyNotices.txt >nul

:: Copy license/notice files for redistributed CommunityToolkit and Microsoft packages.
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$ErrorActionPreference='Stop';" ^
    "$ids=@('communitytoolkit.mvvm','microsoft.extensions.dependencyinjection','microsoft.extensions.dependencyinjection.abstractions','microsoft.extensions.logging','microsoft.extensions.logging.abstractions','microsoft.extensions.options','microsoft.extensions.primitives');" ^
    "foreach($id in $ids){$root=Join-Path $env:USERPROFILE \".nuget\packages\$id\";$pkg=Get-ChildItem $root -Directory|Sort-Object {[version]$_.Name} -Descending|Select-Object -First 1;if(-not $pkg){throw \"Package directory missing: $id\"};$files=Get-ChildItem $pkg.FullName -File|Where-Object {$_.Name -match '^(license|notice|third-party)'};if(-not $files){throw \"No license/notice found for $id\"};$target=Join-Path 'dist\PleaseTweakWindows\licenses' $id;New-Item -ItemType Directory -Path $target -Force|Out-Null;$files|Copy-Item -Destination $target -Force}"
if errorlevel 1 (
    echo ERROR: Could not collect dependency license files.
    exit /b 1
)

:: Generate the CycloneDX SBOM so the local package matches the CI release (the README
:: promises an SBOM with every release). The tool install is best-effort — it may already
:: be present — and the bom.json existence check below is the real gate.
echo       Generating SBOM...
set "PATH=%PATH%;%USERPROFILE%\.dotnet\tools"
dotnet tool install --global CycloneDX --version 6.2.0 >nul 2>&1
dotnet CycloneDX %PROJECT% -o dist\publish --json >nul 2>&1
if exist dist\publish\bom.json (
    copy dist\publish\bom.json dist\PleaseTweakWindows\SBOM.json >nul
) else (
    echo       WARNING: CycloneDX unavailable - skipping local SBOM. CI still generates it for real releases.
)

:: Create ZIP
echo       Creating ZIP archive...
pushd dist
if exist PleaseTweakWindows.zip del PleaseTweakWindows.zip
powershell -NoProfile -Command "Compress-Archive -Path 'PleaseTweakWindows\*' -DestinationPath 'PleaseTweakWindows.zip'"
:: Publish a checksum users can verify the download against (matches the CI SHA256SUMS.txt asset).
if exist SHA256SUMS.txt del SHA256SUMS.txt
powershell -NoProfile -Command "$h=(Get-FileHash -Algorithm SHA256 -Path 'PleaseTweakWindows.zip').Hash; \"$h  PleaseTweakWindows.zip\" | Out-File -Encoding ascii SHA256SUMS.txt"
popd

echo.
echo ============================================
echo  BUILD COMPLETE
echo ============================================
echo  EXE:    dist\PleaseTweakWindows\PleaseTweakWindows.exe
echo  ZIP:    dist\PleaseTweakWindows.zip
echo  SHA256: dist\SHA256SUMS.txt
echo ============================================
