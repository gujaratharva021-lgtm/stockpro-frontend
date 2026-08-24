$ErrorActionPreference = "Stop"
$file = "lib\features\auth\screens\login_screen.dart"

if (-not (Test-Path $file)) {
    Write-Host "File not found: $file" -ForegroundColor Red
    exit 1
}

$raw = [System.IO.File]::ReadAllText($file, [System.Text.Encoding]::UTF8)
$content = $raw -replace "`r`n", "`n"

$old = @'
            Center(
              child: GestureDetector(
                onTap: _loginWithBiometric,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.fingerprint, color: AppColors.primary, size: 24),
                      SizedBox(width: 8),
                      Text('Login with Biometric', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
'@
$new = @'
          ],
          const SizedBox(height: 20),
'@

$count = ([regex]::Matches($content, [regex]::Escape($old))).Count
if ($count -eq 1) {
    $content = $content.Replace($old, $new)
    Write-Host "OK: biometric button removed." -ForegroundColor Green
} else {
    Write-Host "SKIP: pattern matched $count times (expected 1). Please check file manually around line 176-198." -ForegroundColor Yellow
    exit 1
}

$final = $content -replace "`n", "`r`n"
[System.IO.File]::WriteAllText($file, $final, [System.Text.UTF8Encoding]::new($false))
Write-Host "Done." -ForegroundColor Cyan
