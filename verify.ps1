Write-Host "`n=== VATA DEMO EPOCH VERIFIER ===`n"

if (!(Test-Path ".\receipt.json")) {
    Write-Host "ERROR: receipt.json not found" -ForegroundColor Red
    exit 1
}

if (!(Test-Path ".\merkle_root_v2.txt")) {
    Write-Host "ERROR: merkle_root_v2.txt not found" -ForegroundColor Red
    exit 1
}

$rootFile = (Get-Content ".\merkle_root_v2.txt" -Raw).Trim().ToLower()
$receiptHash = (Get-FileHash ".\receipt.json" -Algorithm SHA256).Hash.ToLower()

Write-Host "Computed SHA256(receipt.json): $receiptHash"
Write-Host "Root from file:               $rootFile"

if ($receiptHash -eq $rootFile) {
    Write-Host "`nROOT OK" -ForegroundColor Green
} else {
    Write-Host "`nROOT MISMATCH" -ForegroundColor Red
    exit 1
}

Write-Host "`nVerification complete.`n"
