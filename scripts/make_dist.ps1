# scripts/make_dist.ps1
param(
    [string]$Root = "C:\Users\SAMEER\OneDrive\Desktop\Prob_Proj"
)

$ErrorActionPreference = "Stop"

$distDir = Join-Path $Root "dist"
if (!(Test-Path $distDir)) {
    New-Item -ItemType Directory -Path $distDir -Force | Out-Null
}

$zipPath = Join-Path $distDir "Prob_Proj_FINAL.zip"
if (Test-Path $zipPath) {
    Remove-Item $zipPath -Force
}

$stagingDir = Join-Path $distDir "staging"
if (Test-Path $stagingDir) {
    Remove-Item $stagingDir -Recurse -Force
}
New-Item -ItemType Directory -Path $stagingDir -Force | Out-Null

$itemsToCopy = @(
    "app.R",
    "RUN_PROJECT.bat",
    "README.md",
    "PROGRESS.md",
    "R",
    "scripts",
    "tests",
    "reports",
    "outputs",
    "models"
)

foreach ($item in $itemsToCopy) {
    $src = Join-Path $Root $item
    if (Test-Path $src) {
        Copy-Item -Path $src -Destination (Join-Path $stagingDir $item) -Recurse -Force
    }
}

# Copy curated processed data, fixtures, and data manifest
New-Item -ItemType Directory -Path (Join-Path $stagingDir "data") -Force | Out-Null
Copy-Item -Path (Join-Path $Root "data\DATA_MANIFEST.md") -Destination (Join-Path $stagingDir "data\DATA_MANIFEST.md") -Force
Copy-Item -Path (Join-Path $Root "data\fixtures") -Destination (Join-Path $stagingDir "data\fixtures") -Recurse -Force
Copy-Item -Path (Join-Path $Root "data\processed") -Destination (Join-Path $stagingDir "data\processed") -Recurse -Force

# Create raw placeholder readme
New-Item -ItemType Directory -Path (Join-Path $stagingDir "data\raw") -Force | Out-Null
$rawReadme = @"
Large raw datasets (1.18 GB total across 6 external sources) are retained in the main project directory:
- data/raw/usaspending/usaspending.csv (226 MB)
- data/raw/creditcard.csv/creditcard.csv (144 MB)
- data/raw/PS_20174392719_1491204439457_log.csv (470 MB)
- data/raw/online+retail/Online Retail.xlsx (23 MB)
- WDI_CSV_2026_10_01/ (270 MB)

This distribution archive contains all complete application code, tests, trained models, reports, generated analytical figures, tables, curated panel data, and fixtures.
"@
Set-Content -Path (Join-Path $stagingDir "data\raw\README_RAW_DATA.txt") -Value $rawReadme

Add-Type -AssemblyName System.IO.Compression.FileSystem
$compressionLevel = [System.IO.Compression.CompressionLevel]::Optimal
[System.IO.Compression.ZipFile]::CreateFromDirectory($stagingDir, $zipPath, $compressionLevel, $false)

Remove-Item $stagingDir -Recurse -Force

$zipFile = Get-Item $zipPath
Write-Host "Created archive:" $zipFile.FullName
Write-Host "Size:" ([math]::Round($zipFile.Length / 1MB, 2)) "MB"
