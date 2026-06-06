use aiken/crypto.{VerificationKeyHash}

pub type AssetAmount =
  (ByteArray, ByteArray, Int)

pub type EscrowState {
  Locked
  PartiallyReleased
  Disputed
}

pub type EscrowDatum {
  merchant_pkh: VerificationKeyHash,
  customer_pkh: VerificationKeyHash,
  admin_pkh: VerificationKeyHash,
  invoice_id: ByteArray,
  
  // Platform Fee (Lovelace only for predictable fee rates)
  platform_fee_lovelace: Int,
  platform_treasury_pkh: VerificationKeyHash,
  
  // Multi-asset Payout Tracking (List of 3-tuples)
  total_amount: List<AssetAmount>,
  released_amount: List<AssetAmount>,
  
  // Milestone Progress
  milestone_index: Int,
  total_milestones: Int,
  
  // Lifecycle State
  state: EscrowState,
  
  // Expiry parameters (slots)
  expiry_slot: Int,
  grace_period_slots: Int,
  
  // Verification and Hashes
  agreement_hash: ByteArray,
  metadata_hash: ByteArray,
  
  // Smart Contract Versioning
  contract_version: Int,
}

pub type EscrowRedeemer {
  // Customer releases a milestone payout
  ReleaseMilestone { payout_amount: List<AssetAmount>, fee_payout: Int }
  
  // Merchant auto-claims funds after expiry + grace window (if not disputed)
  AutoRelease
  
  // Customer refunds remaining funds after expiry + grace window (if not disputed)
  CustomerRefund
  
  // Merchant or Customer disputes the project, freezing the contract
  RaiseDispute
  
  // Admin resolves the dispute, distributing remaining funds
  AdminResolution {
    merchant_payout: List<AssetAmount>,
    customer_payout: List<AssetAmount>,
    fee_payout: Int,
  }
}
