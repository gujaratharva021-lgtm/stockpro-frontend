$lines = Get-Content -Path "C:\Users\Administrator\StudioProjects\stockpro\lib\features\stock_detail\screens\stock_detail_screen.dart" -Encoding UTF8
$line = $lines[193]
Write-Host $line
foreach ($ch in $line.ToCharArray()) {
    Write-Host ([int]$ch) "-" $ch
}
