# ZeroPay Escrow Contract

## Overview

The ZeroPay escrow validator is written in **Aiken v1** and deployed on Cardano preprod testnet.

It exposes **two spending paths:**

| Redeemer | Who | Condition |
|----------|-----|-----------|
| `Collect` | Merchant | Must sign + receive ≥ `amount_lovelace` + before `expiry_slot` |
| `Refund` | Customer | Must sign + after `expiry_slot` |

## Datum Structure

```aiken
type EscrowDatum {
  merchant_pkh:   ByteArray,  // merchant payment key hash
  customer_pkh:   ByteArray,  // customer payment key hash
  invoice_id:     ByteArray,  // UTF-8 invoice ID (max 64 bytes)
  amount_lovelace: Int,       // exact lovelace amount
  expiry_slot:    Int,        // POSIX slot for refund unlock
}
```

## Build

```bash
# Install Aiken CLI
curl -sSfL https://install.aiken-lang.org | bash

# Build & type-check
cd contracts/
aiken build

# Run property tests
aiken check

# Output: plutus.json (already committed for demo)
```

## Preprod Deploy

```bash
# 1. Extract script address from plutus.json
aiken address --network preprod

# 2. Create reference script UTxO (pay once, reference forever)
cardano-cli transaction build \
  --tx-out "$(aiken address)"+1500000 \
  --tx-out-reference-script-file plutus.json \
  ...

# 3. Reference script hash stored in backend env as ESCROW_SCRIPT_HASH
```

## MVP Note

For the hackathon demo, ZeroPay uses **direct address payment** (no escrow required). The Aiken contract is deployed on preprod and demonstrates the **trust upgrade path** for v1.1. The `plutus.json` is committed so the judge can inspect the script hash.

Full escrow flow (lock-to-script → Collect by merchant) is activated in production v1.1.

## Script Hash (Preprod)

```
4c9e82e75e83a6e1dd6fc0a7d78f50e2a64c25ee13a69f4c1c0a1dcb
```

Verify on [preprod.cardanoscan.io](https://preprod.cardanoscan.io/script/4c9e82e75e83a6e1dd6fc0a7d78f50e2a64c25ee13a69f4c1c0a1dcb)
