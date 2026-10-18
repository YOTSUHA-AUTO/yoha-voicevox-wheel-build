$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$policy = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'build-policy.json') -Raw | ConvertFrom-Json
if ($env:GITHUB_REPOSITORY -cne $policy.repository -or $env:GITHUB_EVENT_NAME -ne 'workflow_dispatch') { throw 'CONTEXT_REJECTED' }
$source = Join-Path $PSScriptRoot 'upstream'
$head = & git -C $source rev-parse HEAD
if ($LASTEXITCODE -ne 0 -or $head -cne $policy.source_commit) { throw 'SOURCE_REJECTED' }
$dirty = & git -C $source status --porcelain --untracked-files=all
if ($LASTEXITCODE -ne 0 -or $dirty) { throw 'DIRTY_SOURCE_REJECTED' }
foreach ($property in $policy.submodules.PSObject.Properties) {
    $actual = & git -C (Join-Path $source $property.Name) rev-parse HEAD
    if ($LASTEXITCODE -ne 0 -or $actual -cne $property.Value) { throw 'SUBMODULE_REJECTED' }
}
$submodules = @(& git -C $source submodule status --recursive)
if ($LASTEXITCODE -ne 0 -or $submodules.Count -ne 2 -or ($submodules | Where-Object { $_ -notmatch '^ [0-9a-f]{40} ' })) { throw 'SUBMODULE_REJECTED' }
# Use the runner's installed toolchain only; never install/update it.
$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
$installation = & $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if ($LASTEXITCODE -ne 0 -or -not $installation) { throw 'TOOLCHAIN_UNAVAILABLE' }
$vcvars = Join-Path $installation 'VC/Auxiliary/Build/vcvarsall.bat'
$toolset = Join-Path $installation ('VC/Tools/MSVC/' + $policy.msvc_toolset)
if (-not (Test-Path -LiteralPath $toolset -PathType Container)) { throw 'PINNED_TOOLSET_UNAVAILABLE' }
$initialization = '""' + $vcvars + '" x64 ' + $policy.windows_sdk + ' -vcvars_ver=' + $policy.msvc_toolset + ' >nul && set"'
$environment = & $env:ComSpec /d /s /c $initialization
if ($LASTEXITCODE -ne 0) { throw 'TOOLCHAIN_INIT_FAILED' }
foreach ($line in $environment) {
    if ($line -match '^([^=]+)=(.*)$') { [Environment]::SetEnvironmentVariable($matches[1], $matches[2], 'Process') }
}
if ($env:VCToolsVersion.TrimEnd('\') -ne $policy.msvc_toolset -or $env:WindowsSDKVersion.TrimEnd('\') -ne $policy.windows_sdk) { throw 'TOOLCHAIN_VERSION_REJECTED' }
$compiler = (Get-Command cl.exe -ErrorAction Stop).Source
if (-not $compiler.StartsWith($toolset + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'COMPILER_PATH_REJECTED' }
# Prevent setuptools from rediscovering another Visual Studio/toolset.
$env:DISTUTILS_USE_SDK = '1'
$env:MSSdk = '1'
foreach ($name in @('CL','_CL_','LINK','CFLAGS','CXXFLAGS','LDFLAGS','SETUPTOOLS_SCM_PRETEND_VERSION')) { [Environment]::SetEnvironmentVariable($name, $null, 'Process') }
$env:CL = '/O2 /Brepro'
$env:LINK = '/Brepro'
$env:CMAKE_GENERATOR = 'NMake Makefiles'
$env:PIP_CONFIG_FILE = 'NUL'
$env:PIP_DISABLE_PIP_VERSION_CHECK = '1'
$env:PYTHONDONTWRITEBYTECODE = '1'
$env:SOURCE_DATE_EPOCH = & git -C $source show -s --format=%ct HEAD
# Fixed input hashes, wheels only; no dynamic build-dependency installation.
& python -I -B -m pip --isolated install --index-url https://pypi.org/simple --require-hashes --only-binary=:all: --no-cache-dir -r (Join-Path $PSScriptRoot 'build-requirements.lock') *> $null
if ($LASTEXITCODE -ne 0) { throw 'BUILD_DEPENDENCY_INSTALL_FAILED' }
& python -I -B -c "import sys,struct,importlib.metadata as m; assert sys.version_info[:3]==(3,11,9) and struct.calcsize('P')==8; assert m.version('cmake')=='3.31.6'; assert m.version('numpy')=='2.2.4'"
if ($LASTEXITCODE -ne 0) { throw 'BUILD_ENVIRONMENT_REJECTED' }
# The pip CMake entry point is in the selected Python Scripts directory.
$scripts = & python -I -B -c "import sysconfig; print(sysconfig.get_path('scripts'))"
$env:PATH = $scripts + ';' + $env:PATH
& cmake --version *> $null
if ($LASTEXITCODE -ne 0) { throw 'CMAKE_UNAVAILABLE' }
& python -I -B -m pip --isolated wheel --no-build-isolation --no-deps --no-index --no-cache-dir --wheel-dir (Join-Path $PSScriptRoot 'dist') $source *> $null
if ($LASTEXITCODE -ne 0) { throw 'WHEEL_BUILD_FAILED' }
& python -I -B (Join-Path $PSScriptRoot 'finalize.py')
if ($LASTEXITCODE -ne 0) { throw 'ARTIFACT_VALIDATION_FAILED' }
Write-Output 'BUILD_AND_STRUCTURAL_CHECK_PASS'
