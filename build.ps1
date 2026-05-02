param(
    [switch]$Program,
    [int]$Jobs = 8,
    [string]$VivadoRoot = "E:\AMDDesignTools\2025.2",
    [string]$Project = "SAP-1.xpr"
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
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
} else {
    $argsList += "build"
}

Write-Host "Running Vivado flow..."
Write-Host "Project: $projectPath"
Write-Host "Mode:    $(if ($Program) { 'build and program' } else { 'build only' })"

& $vivadoBat @argsList
$vivadoExitCode = $LASTEXITCODE

if ($vivadoExitCode -eq 0) {
    $cleanupPatterns = @(
        "vivado*.jou",
        "vivado*.log",
        "vivado*.str",
        "xvlog.log",
        "xvlog.pb",
        "dfx_runtime.txt"
    )

    foreach ($pattern in $cleanupPatterns) {
        Get-ChildItem -Path $scriptDir -Filter $pattern -File -ErrorAction SilentlyContinue |
            Remove-Item -Force
    }

    Write-Host "Cleaned generated Vivado session logs."
}

exit $vivadoExitCode
