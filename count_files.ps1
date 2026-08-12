Get-ChildItem -Path "C:\Users\Administrator\StudioProjects\stockpro\lib\features" -Directory | ForEach-Object {
    $count = (Get-ChildItem -Path $_.FullName -Recurse -Filter "*.dart" | Measure-Object).Count
    Write-Host $_.Name ":" $count "files"
}
