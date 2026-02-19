# Security / Challenge Rules

## What this repo proves
- `receipt.json` integrity is verifiable by SHA256
- The root is anchored on-chain (OP Sepolia) via the tx in `anchor_tx.txt`

## Valid break (the only thing that counts)
You may change ONLY `receipt.json`.

A break is:
- `RUN_DEMO.ps1` still prints `ROOT OK` and `ONCHAIN OK`
- while `receipt.json` was modified
- and without modifying any of:
  - `verify.ps1`
  - `RUN_DEMO.ps1`
  - `merkle_root_v2.txt`
  - `anchor_tx.txt`

## Non-breaks (won’t be accepted)
- Editing scripts to weaken checks
- Replacing the root file or tx file
- Changing the definition of verification
