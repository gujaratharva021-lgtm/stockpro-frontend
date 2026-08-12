Get-ChildItem -Path "C:\Users\Administrator\StudioProjects\stockpro\lib\features" -Directory | ForEach-Object {
    $files = Get-ChildItem -Path $_.FullName -Recurse -Filter "*.dart"
    $lines = ($files | Get-Content | Measure-Object -Line).Lines
    Write-Host $_.Name ":" $files.Count "files," $lines "lines"
}
