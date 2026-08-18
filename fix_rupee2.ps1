$files = @(
  "C:\Users\Administrator\StudioProjects\stockpro\lib\features\stock_detail\screens\stock_detail_screen.dart",
  "C:\Users\Administrator\StudioProjects\stockpro\lib\features\stock_detail\screens\basket_screen.dart",
  "C:\Users\Administrator\StudioProjects\stockpro\lib\features\stock_detail\screens\price_chart.dart"
)

foreach ($f in $files) {
    $content = Get-Content -Path $f -Raw -Encoding UTF8
    $content = $content.Replace([string]([char]226+[char]8364+[char]162), [string][char]0x2022)
    $content = $content.Replace([string]([char]226+[char]8218+[char]185), [string][char]0x20B9)
    Set-Content -Path $f -Value $content -Encoding UTF8
    Write-Host "Fixed: $f"
}
