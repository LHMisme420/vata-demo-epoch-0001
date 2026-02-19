Write-Host "`n=== TAMPER TEST ===`n"

$src = "$PSScriptRoot\receipt.json"
$tmp = "$PSScriptRoot\receipt.tampered.json"

if (!(Test-Path $src)) {
  Write-Host "ERROR: receipt.json not found" -ForegroundColor Red
  exit 1
}

Copy-Item $src $tmp -Force

# Flip 1 byte in the copied file (guaranteed change)
$bytes = [System.IO.File]::ReadAllBytes($tmp)
$bytes[0] = ($bytes[0] -bxor 1)
[System.IO.File]::WriteAllBytes($tmp, $bytes)

$hash = "0x" + (Get-FileHash $tmp -Algorithm SHA256).Hash.ToLower()

$root = (Get-Content "$PSScriptRoot\merkle_root_v2.txt" -Raw).Trim().ToLower()
if (!$root.StartsWith("0x")) { $root = "0x$root" }

Write-Host "SHA256(tampered): $hash"
Write-Host "Root (expected):  $root"

if ($hash -eq $root) {
  Write-Host "`nUNEXPECTED: tampered file still matches root (should never happen)" -ForegroundColor Red
  exit 1
} else {
  Write-Host "`nPASS: tampering breaks integrity as expected" -ForegroundColor Green
}
