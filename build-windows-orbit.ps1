<#
    build-windows-orbit.ps1  -  Build the "Orbit" Windows client (branded RustDesk fork)

    WHAT THIS DOES
      1. Checks out the hbb_common submodule.
      2. Bakes the Orbit server / key / app-name into the compile-time config
         (orbit/patch_hbb_config.py -> libs/hbb_common/src/config.rs).
      3. Builds the Flutter + Rust Windows release and packs the portable installer.
      4. (Placeholder) Code-signs the output -- wired up but disabled until the
         owner provides a certificate.

    BAKED-IN DEFAULTS (no manual setup on first run, AnyDesk-style):
      Server (rendezvous + relay + derived API) : connect.orbit.bd
      Server public key                          : ubNfSsoZBoffk4fOCsLiPvuv+ExFWy6ErfIHKIBvrZE=
      App / product name                         : Orbit
    DNS: connect.orbit.bd must resolve to the self-hosted server (103.107.160.27).

    PREREQUISITES (install once on this Windows PC -- the official RustDesk set):
      - Rust (MSVC)  : rustup default stable-x86_64-pc-windows-msvc
      - Visual Studio 2022 Build Tools (Desktop C++ workload)
      - LLVM 15.0.6  : set $env:LIBCLANG_PATH to <llvm>\bin  (e.g. C:\Program Files\LLVM\bin)
      - Python 3     : on PATH (also used to bake the config)
      - Flutter      : the version pinned in flutter/pubspec.yaml, on PATH
      - vcpkg        : set $env:VCPKG_ROOT ; deps come from vcpkg.json (x64-windows-static)

    USAGE (Windows PowerShell, from the repo root):
      pwsh -File .\build-windows-orbit.ps1
    Optional:
      -SkipVcpkg       skip the vcpkg dependency install (already installed)
      -SkipSubmodule   skip submodule update (already checked out)
#>

[CmdletBinding()]
param(
    [switch]$SkipVcpkg,
    [switch]$SkipSubmodule
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $RepoRoot

# ---- Orbit constants (kept in sync with orbit/patch_hbb_config.py) ------------
$OrbitServer = "connect.orbit.bd"
$OrbitKey    = "ubNfSsoZBoffk4fOCsLiPvuv+ExFWy6ErfIHKIBvrZE="
$OrbitName   = "Orbit"
# Triplet used for all x64 Windows deps (matches .github/workflows/flutter-build.yml)
$VcpkgTriplet = "x64-windows-static"

function Require-Command([string]$Name, [string]$Hint) {
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required tool '$Name' not found on PATH. $Hint"
    }
}

Write-Host "== Orbit Windows build ==" -ForegroundColor Cyan
Write-Host "   server=$OrbitServer  name=$OrbitName" -ForegroundColor Cyan

# ---- 0. Prerequisite checks --------------------------------------------------
Require-Command python "Install Python 3 and add it to PATH."
Require-Command cargo  "Install Rust via rustup (stable-x86_64-pc-windows-msvc)."
Require-Command flutter "Install Flutter (version pinned in flutter/pubspec.yaml)."
if (-not $env:LIBCLANG_PATH) {
    Write-Warning "LIBCLANG_PATH is not set. Point it at your LLVM 15 bin dir, e.g. 'C:\Program Files\LLVM\bin'."
}
if (-not $SkipVcpkg -and -not $env:VCPKG_ROOT) {
    throw "VCPKG_ROOT is not set. Install vcpkg and set `\$env:VCPKG_ROOT`, or pass -SkipVcpkg."
}

# ---- 1. Submodule ------------------------------------------------------------
if (-not $SkipSubmodule) {
    Write-Host "-- git submodule update --init --recursive" -ForegroundColor Yellow
    git submodule update --init --recursive
    if ($LASTEXITCODE -ne 0) { throw "git submodule update failed." }
}

# ---- 2. Bake Orbit config into the (submodule) compile-time config -----------
Write-Host "-- Baking Orbit server/key/name into libs/hbb_common/src/config.rs" -ForegroundColor Yellow
python "orbit\patch_hbb_config.py"
if ($LASTEXITCODE -ne 0) { throw "Config bake failed." }
python "orbit\patch_hbb_config.py" --check
if ($LASTEXITCODE -ne 0) { throw "Config verification failed -- Orbit values are not baked in." }

# ---- 3. vcpkg dependencies ---------------------------------------------------
if (-not $SkipVcpkg) {
    Write-Host "-- Installing vcpkg dependencies ($VcpkgTriplet)" -ForegroundColor Yellow
    $env:VCPKG_DEFAULT_HOST_TRIPLET = $VcpkgTriplet
    & "$env:VCPKG_ROOT\vcpkg.exe" install --triplet $VcpkgTriplet --x-install-root="$env:VCPKG_ROOT\installed"
    if ($LASTEXITCODE -ne 0) { throw "vcpkg install failed." }
}

# ---- 4. Build (Rust lib + Flutter) and pack the portable installer -----------
# Mirrors the official CI command; omitting --skip-portable-pack so we also get
# the single-file installer exe (./rustdesk-<version>-install.exe).
Write-Host "-- Building Orbit (flutter + rust, hwcodec, portable)" -ForegroundColor Yellow
python build.py --portable --flutter --hwcodec
if ($LASTEXITCODE -ne 0) { throw "build.py failed." }

# ---- 5. Code signing (PLACEHOLDER -- enable when the cert is available) ------
# The owner will provide a code-signing certificate later. When ready, set the
# env vars below and uncomment. Sign BOTH the inner exe and the packed installer.
#
#   $cert   = $env:ORBIT_SIGN_PFX        # path to .pfx
#   $pass   = $env:ORBIT_SIGN_PASSWORD   # pfx password
#   $tsa    = "http://timestamp.digicert.com"
#   $installer = Get-ChildItem -Path . -Filter "rustdesk-*-install.exe" | Select-Object -First 1
#   & signtool.exe sign /f $cert /p $pass /fd SHA256 /tr $tsa /td SHA256 $installer.FullName
#
Write-Host "NOTE: code signing is not yet configured (placeholder in this script)." -ForegroundColor DarkYellow

$installer = Get-ChildItem -Path . -Filter "rustdesk-*-install.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
if ($installer) {
    Write-Host "== Build complete: $($installer.FullName)" -ForegroundColor Green
} else {
    Write-Host "== Build complete (see build.py output for the artifact path)." -ForegroundColor Green
}
