param(
  [switch]$LocalOnly
)

Write-Host "`n=== VATA DEMO EPOCH VERIFIER ===`n"

# ------------------------
# CONFIG (OP SEPOLIA)
# ------------------------
$ANCHOR_CONTRACT = "0x8c6624d4AfF1C8D0E317B40699c2B4933A2c8CfF"
$RPC_URL = "https://sepolia.optimism.io"

# ------------------------
# FILE CHECKS
# ------------------------
if (!(Test-Path ".\receipt.json")) { Write-Host "ERROR: receipt.json not found" -ForegroundColor Red; exit 1 }
if (!(Test-Path ".\merkle_root_v2.txt")) { Write-Host "ERROR: merkle_root_v2.txt not found" -ForegroundColor Red; exit 1 }

$rootFileRaw = (Get-Content ".\merkle_root_v2.txt" -Raw).Trim().ToLower()
$root = if ($rootFileRaw.StartsWith("0x")) { $rootFileRaw } else { "0x$rootFileRaw" }

$receiptHash = "0x" + (Get-FileHash ".\receipt.json" -Algorithm SHA256).Hash.ToLower()

Write-Host "Computed SHA256(receipt.json): $receiptHash"
Write-Host "Root from file:               $root"

if ($receiptHash -ne $root) {
  Write-Host "`nROOT MISMATCH" -ForegroundColor Red
  exit 1
}
Write-Host "`nROOT OK" -ForegroundColor Green

if ($LocalOnly) {
  Write-Host "`n[INFO] LocalOnly: skipping onchain verification."
  Write-Host "`nVerification complete.`n"
  exit 0
}

# Convert root (bytes32 hex) to uint256 decimal for tx-arg comparison
Add-Type -AssemblyName System.Numerics
$rootU = [System.Numerics.BigInteger]::Parse("0" + $root.Substring(2), [System.Globalization.NumberStyles]::AllowHexSpecifier).ToString()

# ------------------------
# ONCHAIN CHECK (TX-INPUT BASED)
# ------------------------
Write-Host "`n[INFO] Onchain check (OP Sepolia): contract=$ANCHOR_CONTRACT"
Write-Host "[INFO] RPC: $RPC_URL"

# Ensure contract exists on OP Sepolia
$code = cast code $ANCHOR_CONTRACT --rpc-url $RPC_URL
if (!$code -or $code -eq "0x") {
  Write-Host "`nWARN: No code at $ANCHOR_CONTRACT on OP Sepolia (RPC issue or wrong address)." -ForegroundColor Yellow
  Write-Host "`nVerification complete.`n"
  exit 0
}

if (!(Test-Path ".\anchor_tx.txt")) {
  Write-Host "`nWARN: anchor_tx.txt not found. Cannot do tx-based onchain verification." -ForegroundColor Yellow
  Write-Host "      Run ANCHOR_ROOT_OPSEPOLIA.ps1 to create it." -ForegroundColor Yellow
  Write-Host "`nVerification complete.`n"
  exit 0
}

$txText = (Get-Content ".\anchor_tx.txt" -Raw).Trim()
if (!($txText -match "(0x[a-fA-F0-9]{64})")) {
  Write-Host "`nWARN: anchor_tx.txt exists but no tx hash found inside." -ForegroundColor Yellow
  Write-Host "`nVerification complete.`n"
  exit 0
}

$txHash = $matches[1].ToLower()
Write-Host "`n[INFO] anchor tx: $txHash"

$tx = cast tx $txHash --rpc-url $RPC_URL
if (!$tx -or $tx.Trim().Length -eq 0) {
  Write-Host "`nWARN: tx not found on OP Sepolia: $txHash" -ForegroundColor Yellow
  Write-Host "`nVerification complete.`n"
  exit 0
}

# Extract tx "to" and "input"
$toLine = ($tx -split "`n" | Where-Object { $_ -match "^\s*to\s+" } | Select-Object -First 1)
$inLine = ($tx -split "`n" | Where-Object { $_ -match "^\s*input\s+" } | Select-Object -First 1)

if (!$toLine -or !$inLine) {
  Write-Host "`nWARN: Could not parse tx fields (to/input)." -ForegroundColor Yellow
  Write-Host "`nVerification complete.`n"
  exit 0
}

$toAddr = ($toLine -replace "^\s*to\s+","").Trim().ToLower()
if ($toAddr -ne $ANCHOR_CONTRACT.ToLower()) {
  Write-Host "`nWARN: Tx 'to' does not match anchor contract." -ForegroundColor Yellow
  Write-Host "      tx.to:    $toAddr"
  Write-Host "      expected: $($ANCHOR_CONTRACT.ToLower())"
  Write-Host "`nVerification complete.`n"
  exit 0
}

$input = ($inLine -replace "^\s*input\s+","").Trim().ToLower()

# selector + 1x uint256 arg
if (!($input -match "^0x[0-9a-f]{8}[0-9a-f]{64}")) {
  Write-Host "`nWARN: Tx input does not look like selector + single uint256 arg." -ForegroundColor Yellow
  Write-Host "      input: $input"
  Write-Host "`nVerification complete.`n"
  exit 0
}

$argHex = "0x" + $input.Substring(10, 64)
$argU = [System.Numerics.BigInteger]::Parse("0" + $argHex.Substring(2), [System.Globalization.NumberStyles]::AllowHexSpecifier).ToString()

if ($argU -eq $rootU) {
  Write-Host "`nONCHAIN OK" -ForegroundColor Green
  Write-Host "[INFO] Tx input arg matches root."
  Write-Host "[INFO] tx=$txHash"
} else {
  Write-Host "`nWARN: Tx input arg does NOT match root." -ForegroundColor Yellow
  Write-Host "      tx arg (uint256): $argU"
  Write-Host "      root   (uint256): $rootU"
}

Write-Host "`nVerification complete.`n"
