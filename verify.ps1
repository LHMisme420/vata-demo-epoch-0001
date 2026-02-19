
Write-Host "`n=== VATA DEMO EPOCH VERIFIER ===`n"

# ------------------------
# CONFIG
# ------------------------

# Anchor contract (from your earlier $OP_REG)
$ANCHOR_CONTRACT = "0x8c6624d4AfF1C8D0E317B40699c2B4933A2c8CfF"

# RPCs to try (add/remove as needed)
$RPCS = @(
  "https://ethereum-rpc.publicnode.com",          # Ethereum mainnet
  "https://ethereum-sepolia-rpc.publicnode.com",  # Sepolia
  "https://sepolia.optimism.io",                  # OP Sepolia
  "https://mainnet.optimism.io"                   # OP Mainnet
)

# How far back to scan (blocks)
$MAX_SCAN = 2000000


# Scan chunk size (keep <= provider limits; 10k is usually safe)
$CHUNK = 10000

# Event signature (commitment is indexed in your ABI snippet)
$EVENT_SIG = "ProofAnchored(bytes32,address)"

# ------------------------
# FILE CHECKS
# ------------------------

if (!(Test-Path ".\receipt.json")) { Write-Host "ERROR: receipt.json not found" -ForegroundColor Red; exit 1 }
if (!(Test-Path ".\merkle_root_v2.txt")) { Write-Host "ERROR: merkle_root_v2.txt not found" -ForegroundColor Red; exit 1 }

$rootFileRaw = (Get-Content ".\merkle_root_v2.txt" -Raw).Trim()

# Normalize root to 0x-prefixed lowercase 64-hex
$root = $rootFileRaw.ToLower()
if ($root.StartsWith("0x")) { $root = $root } else { $root = "0x$root" }

$receiptHash = ("0x" + (Get-FileHash ".\receipt.json" -Algorithm SHA256).Hash.ToLower())

Write-Host "Computed SHA256(receipt.json): $receiptHash"
Write-Host "Root from file:               $root"

if ($receiptHash -ne $root) {
  Write-Host "`nROOT MISMATCH" -ForegroundColor Red
  exit 1
}

Write-Host "`nROOT OK" -ForegroundColor Green

# ------------------------
# ONCHAIN CHECK
# ------------------------

Write-Host "`n[INFO] Onchain check (logs): contract=$ANCHOR_CONTRACT"
$topic0 = cast keccak "$EVENT_SIG"

$onchainFound = $false
$foundRpc = $null
$foundLine = $null

foreach ($rpc in $RPCS) {

  Write-Host "`n[INFO] Trying RPC: $rpc"

  # 1) Ensure contract exists on this chain
  $code = cast code $ANCHOR_CONTRACT --rpc-url $rpc
  if (!$code -or $code -eq "0x") {
    Write-Host "[WARN] No code at this address on this RPC. Skipping." -ForegroundColor Yellow
    continue
  }

  # 2) Get latest block
  $latestStr = cast block-number --rpc-url $rpc
  if (-not $latestStr) {
    Write-Host "[WARN] Could not fetch block number. Skipping." -ForegroundColor Yellow
    continue
  }
  $latest = [int]$latestStr

  $fromLimit = $latest - $MAX_SCAN
  if ($fromLimit -lt 0) { $fromLimit = 0 }

  # 3) Scan backwards in chunks using TOPIC FILTERING (fast and exact)
  for ($to = $latest; $to -ge $fromLimit; $to -= $CHUNK) {

    $from = $to - ($CHUNK - 1)
    if ($from -lt $fromLimit) { $from = $fromLimit }

    Write-Host "[INFO] Scanning blocks $from .. $to"
    $logs = cast logs `
      --rpc-url $rpc `
      --address $ANCHOR_CONTRACT `
      --from-block $from `
      --to-block $to `
      "$EVENT_SIG" `
      $root

   

    if ($logs -and ($logs -match "transactionHash|txHash|blockNumber|logIndex|topics")) {
      $onchainFound = $true
      $foundRpc = $rpc
      $foundLine = $logs
      break
    }
  }

  if ($onchainFound) { break }
}

if ($onchainFound) {
  Write-Host "`nONCHAIN OK" -ForegroundColor Green
  Write-Host "[INFO] Found on: $foundRpc"
  # Print a small snippet so it's screenshot-friendly
  $snippet = ($foundLine -split "`n" | Select-Object -First 30) -join "`n"
  Write-Host $snippet
} else {
  Write-Host "`nWARN: Did NOT find root within last ~$MAX_SCAN blocks on any configured RPC." -ForegroundColor Yellow
  Write-Host "      If it was anchored earlier, increase `$MAX_SCAN or add the correct RPC." -ForegroundColor Yellow
}

Write-Host "`nVerification complete.`n"
