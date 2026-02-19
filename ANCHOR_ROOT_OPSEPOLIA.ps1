Write-Host "`n=== ANCHOR ROOT (OP SEPOLIA) ===`n"

$RPC="https://sepolia.optimism.io"
$C="0x8c6624d4AfF1C8D0E317B40699c2B4933A2c8CfF"

if (!$env:PK) {
  Write-Host "ERROR: env:PK is not set (must be 64 hex chars, no 0x)" -ForegroundColor Red
  exit 1
}

$root = (Get-Content "$PSScriptRoot\merkle_root_v2.txt" -Raw).Trim().ToLower()
if (!$root.StartsWith("0x")) { $root = "0x$root" }

Add-Type -AssemblyName System.Numerics
$rootU=[System.Numerics.BigInteger]::Parse("0"+$root.Substring(2), [System.Globalization.NumberStyles]::AllowHexSpecifier).ToString()

Write-Host "Root:   $root"
Write-Host "RootU:  $rootU"
Write-Host "Contract: $C"
Write-Host "RPC:      $RPC"

# Confirm contract exists
$code = cast code $C --rpc-url $RPC
if (!$code -or $code -eq "0x") {
  Write-Host "ERROR: No code at contract on this RPC" -ForegroundColor Red
  exit 1
}

Write-Host "`nSending anchorRoot(uint256)..."
$TXOUT = cast send $C "anchorRoot(uint256)" $rootU --rpc-url $RPC --private-key $env:PK
$TXOUT | Out-File -Encoding ascii "$PSScriptRoot\anchor_tx.txt"

Write-Host "`nSaved tx output to anchor_tx.txt"
Write-Host $TXOUT
