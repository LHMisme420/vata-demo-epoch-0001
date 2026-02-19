
Write-Host "`n=== VATA DEMO EPOCH VERIFIER ===`n"

# ------------------------
# CONFIG
# ------------------------
$ANCHOR_CONTRACT = "0x8c6624d4AfF1C8D0E317B40699c2B4933A2c8CfF"

# Try likely chains. Keep only ones where `cast code` returns non-0x.
$RPCS = @(
  "https://ethereum-rpc.publicnode.com",   # Ethereum mainnet
  "https://sepolia.optimism.io"           # OP Sepolia
)

$EVENT_SIG = "ProofAnchored(bytes32,address)"

# scan controls
$MAX_SCAN = 2000000
     # increase if needed (e.g. 2000000)
$CHUNK    = 10000      # provider-safe chunk size

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

# ------------------------
# ONCHAIN CHECK (EVENT SCAN)
# ------------------------
Write-Host "`n[INFO] Onchain check (logs): contract=$ANCHOR_CONTRACT"
$onchainFound = $false
$foundRpc = $null
$foundLogs = $null

foreach ($rpcUrl in $RPCS) {

  Write-Host "`n[INFO] Trying RPC: $rpcUrl"

  # Ensure contract exists on this chain
  $code = cast code $ANCHOR_CONTRACT --rpc-url $rpcUrl
  if (!$code -or $code -eq "0x") {
    Write-Host "[WARN] No code at this address on this RPC. Skipping." -ForegroundColor Yellow
    continue
  }

  $latest = [int](cast block-number --rpc-url $rpcUrl)
  $minBlock = $latest - $MAX_SCAN
  if ($minBlock -lt 0) { $minBlock = 0 }

  for ($toBlock = $latest; $toBlock -ge $minBlock; $toBlock -= $CHUNK) {

    $fromBlock = $toBlock - ($CHUNK - 1)
    if ($fromBlock -lt $minBlock) { $fromBlock = $minBlock }

    Write-Host "[INFO] Scanning blocks $fromBlock .. $toBlock"

    # cast logs syntax for your version:
    # cast logs ... [SIG_OR_TOPIC] [TOPICS...]
    $logs = cast logs `
      --rpc-url $rpcUrl `
      --address $ANCHOR_CONTRACT `
      --from-block $fromBlock `
      --to-block $toBlock `
      "$EVENT_SIG" `
      $root

    if ($logs -and $logs.Trim().Length -gt 0) {
      $onchainFound = $true
      $foundRpc = $rpcUrl
      $foundLogs = $logs
      break
    }
  }

  if ($onchainFound) { break }
}

if ($onchainFound) {
  Write-Host "`nONCHAIN OK" -ForegroundColor Green
  Write-Host "[INFO] Found on: $foundRpc"
  $snippet = ($foundLogs -split "`n" | Select-Object -First 40) -join "`n"
  Write-Host $snippet
} else {
  Write-Host "`nWARN: Did NOT find root within last ~$MAX_SCAN blocks on configured RPCs." -ForegroundColor Yellow
  Write-Host "      If it was anchored earlier, increase `$MAX_SCAN." -ForegroundColor Yellow
}

Write-Host "`nVerification complete.`n"
