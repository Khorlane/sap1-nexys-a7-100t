param(
    [switch]$Program,
    [switch]$NoProgram,
    [switch]$OnlyProgram,
    [switch]$Clean,
    [switch]$OnlyClean,
    [int]$Jobs = 8,
    [string]$VivadoRoot = "E:\AMDDesignTools\2025.2",
    [string]$Project = "SAP-1.xpr"
)

$ErrorActionPreference = "Stop"

function Clear-VivadoSessionLogs {
    param(
        [string]$Path
    )

    $cleanupPatterns = @(
        "vivado*.jou",
        "vivado*.log",
        "vivado*.str",
        "xvlog.log",
        "xvlog.pb",
        "dfx_runtime.txt"
    )

    foreach ($pattern in $cleanupPatterns) {
        Get-ChildItem -Path $Path -Filter $pattern -File -ErrorAction SilentlyContinue |
            Remove-Item -Force
    }

    Write-Host "Cleaned generated Vivado session logs."
}

function Show-Usage {
    Write-Host "Usage:"
    Write-Host "  .\build.ps1 -NoProgram   [-Clean] [-Jobs <n>] [-VivadoRoot <path>] [-Project <path>]"
    Write-Host "  .\build.ps1 -Program     [-Clean] [-Jobs <n>] [-VivadoRoot <path>] [-Project <path>]"
    Write-Host "  .\build.ps1 -OnlyProgram [-Clean] [-VivadoRoot <path>] [-Project <path>]"
    Write-Host "  .\build.ps1 -OnlyClean"
}

$buildModeCount = @($Program, $NoProgram, $OnlyProgram) | Where-Object { $_ } | Measure-Object | Select-Object -ExpandProperty Count

if ($OnlyClean -and ($Program -or $NoProgram -or $OnlyProgram -or $Clean)) {
    Show-Usage
    throw "Use -OnlyClean by itself."
}

if ($buildModeCount -gt 1) {
    Show-Usage
    throw "Choose only one mode: -Program, -NoProgram, or -OnlyProgram."
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

if ($OnlyClean) {
    Clear-VivadoSessionLogs -Path $scriptDir
    exit 0
}

if ($buildModeCount -eq 0) {
    Show-Usage
    exit 1
}

$projectPath = Join-Path $scriptDir $Project
$vivadoBat = Join-Path $VivadoRoot "Vivado\bin\vivado.bat"
$flowTcl = Join-Path $scriptDir "build.tcl"

if (-not (Test-Path $vivadoBat)) {
    throw "Vivado was not found at: $vivadoBat"
}

if (-not (Test-Path $projectPath)) {
    throw "Vivado project was not found at: $projectPath"
}

$argsList = @(
    "-mode", "batch",
    "-source", $flowTcl,
    "-tclargs", $projectPath, $Jobs
)

if ($Program) {
    $argsList += "program"
} elseif ($OnlyProgram) {
    $argsList += "only_program"
} else {
    $argsList += "build"
}

Write-Host "Running Vivado flow..."
Write-Host "Project: $projectPath"
Write-Host "Mode:    $(if ($Program) { 'build and program' } elseif ($OnlyProgram) { 'program existing bitstream only' } else { 'build only' })"

& $vivadoBat @argsList
$vivadoExitCode = $LASTEXITCODE

if ($vivadoExitCode -eq 0 -and $Clean) {
    Clear-VivadoSessionLogs -Path $scriptDir
}

exit $vivadoExitCode
