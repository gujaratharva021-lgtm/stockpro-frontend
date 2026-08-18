$files = @(
  "C:\Users\Administrator\StudioProjects\stockpro\lib\features\stock_detail\screens\basket_screen.dart",
  "C:\Users\Administrator\StudioProjects\stockpro\lib\features\stock_detail\screens\price_chart.dart",
  "C:\Users\Administrator\StudioProjects\stockpro\lib\features\stock_detail\screens\stock_detail_screen.dart"
)

foreach ($f in $files) {
    $content = Get-Content -Path $f -Raw -Encoding UTF8
    $content = $content.Replace([string]([char]0x00D4+[char]0x00E9+[char]0x2554+[char]0x00B9), [string][char]0x20B9)
    $content = $content.Replace([string]([char]0x251C+[char]0x00F3+[char]0x00D4+[char]0x2019+[char]0x252C+[char]0x00B9), [string][char]0x20B9)
    $content = $content.Replace([string]([char]0x00D4+[char]0x00C7+[char]0x00F3), [string][char]0x2022)
    $content = $content.Replace([string]([char]0x251C+[char]0x00F3+[char]0x00D4+[char]0x00E9+[char]0x00AC+[char]0x00F3), [string][char]0x2022)
    $content = $content.Replace([string]([char]0x251C+[char]0x00F9), [string][char]0x00D7)
    Set-Content -Path $f -Value $content -Encoding UTF8
    Write-Host "Fixed: $f"
}
