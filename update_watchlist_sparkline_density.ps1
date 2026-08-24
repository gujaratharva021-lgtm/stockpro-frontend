$ErrorActionPreference = "Stop"

$targetRelPath = "lib\features\watchlist\screens\watchlist_screen.dart"
$targetPath = Join-Path (Get-Location) $targetRelPath

if (-not (Test-Path $targetPath)) {
    Write-Host "ERROR: Can't find $targetRelPath from here." -ForegroundColor Red
    Write-Host "Run this script from the stockpro-frontend repo root (the folder that contains 'lib')." -ForegroundColor Yellow
    exit 1
}

$content = Get-Content -Path $targetPath -Raw -Encoding UTF8

$oldLine = "ApiService.getIntraday(symbol, '15m')"
$newLine = "ApiService.getIntraday(symbol, '5m')"

if ($content -notmatch [regex]::Escape($oldLine)) {
    Write-Host "ERROR: Could not find the expected line:" -ForegroundColor Red
    Write-Host "  $oldLine" -ForegroundColor Yellow
    Write-Host "File may have changed already. No changes made." -ForegroundColor Yellow
    exit 1
}

$updated = $content -replace [regex]::Escape($oldLine), $newLine

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($targetPath, $updated, $utf8NoBom)

Write-Host "Updated: $targetRelPath" -ForegroundColor Green
Write-Host "Intraday interval changed: 15m -> 5m" -ForegroundColor Cyan
Write-Host "This gives 3x more data points per sparkline, so the line will look jagged/zigzag like the reference image." -ForegroundColor Cyan
