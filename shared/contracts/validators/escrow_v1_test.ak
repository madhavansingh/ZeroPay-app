use aiken/collection/dict
use aiken/interval
use cardano/address.{Address, VerificationKey}
use cardano/assets
use cardano/transaction.{Input, OutputReference, Transaction, Output, Datum, InlineDatum, NoDatum}
use types.{
  EscrowDatum, Locked, PartiallyReleased, Disputed,
  ReleaseMilestone, AutoRelease, CustomerRefund, RaiseDispute, AdminResolution
}
use escrow_logic

fn get_mock_datum() -> EscrowDatum {
  EscrowDatum {
    merchant_pkh: "merchant",
    customer_pkh: "customer",
    admin_pkh: "admin",
    invoice_id: "inv#1",
    platform_fee_lovelace: 100,
    platform_treasury_pkh: "treasury",
    total_amount: [("", "", 1000)],
    released_amount: [],
    milestone_index: 0,
    total_milestones: 2,
    state: Locked,
    expiry_slot: 1000,
    grace_period_slots: 100,
    agreement_hash: "agreement_ipfs",
    metadata_hash: "metadata",
    contract_version: 1,
  }
}

fn get_mock_tx() -> Transaction {
  Transaction {
    inputs: [],
    reference_inputs: [],
    outputs: [],
    fee: 0,
    mint: assets.zero,
    certificates: [],
    withdrawals: [],
    validity_range: interval.everything,
    extra_signatories: [],
    redeemers: [],
    datums: dict.empty,
    id: "",
    votes: [],
    proposal_procedures: [],
    current_treasury_amount: None,
    treasury_donation: None,
  }
}

// ─── Tests ────────────────────────────────────────────────────────────────────

test test_release_milestone_final_success() {
  let datum = EscrowDatum { ..get_mock_datum(), milestone_index: 1, total_milestones: 2 }
  let redeemer = ReleaseMilestone { payout_amount: [("", "", 500)], fee_payout: 100 }
  
  let merchant_addr = Address { payment_credential: VerificationKey("merchant"), stake_credential: None }
  let treasury_addr = Address { payment_credential: VerificationKey("treasury"), stake_credential: None }
  
  let tx = Transaction {
    ..get_mock_tx(),
    extra_signatories: ["customer"],
    outputs: [
      Output { address: merchant_addr, value: assets.from_lovelace(500), datum: NoDatum, reference_script: None },
      Output { address: treasury_addr, value: assets.from_lovelace(100), datum: NoDatum, reference_script: None },
    ],
  }
  
  let own_ref = OutputReference { transaction_id: "", output_index: 0 }
  
  escrow_logic.validate_spend(Some(datum), redeemer, own_ref, tx)
}

test test_release_milestone_partial_success() {
  let datum = get_mock_datum() // milestone_index: 0, total_milestones: 2
  let redeemer = ReleaseMilestone { payout_amount: [("", "", 500)], fee_payout: 0 }
  
  let merchant_addr = Address { payment_credential: VerificationKey("merchant"), stake_credential: None }
  let own_script_addr = Address { payment_credential: VerificationKey("script"), stake_credential: None }
  
  let next_datum = EscrowDatum {
    ..datum,
    released_amount: [("", "", 500)],
    milestone_index: 1,
    state: PartiallyReleased,
  }
  
  let tx = Transaction {
    ..get_mock_tx(),
    extra_signatories: ["customer"],
    inputs: [
      Input {
        output_reference: OutputReference { transaction_id: "", output_index: 0 },
        output: Output { address: own_script_addr, value: assets.from_lovelace(1100), datum: NoDatum, reference_script: None },
      }
    ],
    outputs: [
      Output { address: merchant_addr, value: assets.from_lovelace(500), datum: NoDatum, reference_script: None },
      Output { address: own_script_addr, value: assets.from_lovelace(600), datum: InlineDatum(next_datum), reference_script: None },
    ],
  }
  
  let own_ref = OutputReference { transaction_id: "", output_index: 0 }
  
  escrow_logic.validate_spend(Some(datum), redeemer, own_ref, tx)
}

test test_raise_dispute_success() {
  let datum = get_mock_datum()
  let redeemer = RaiseDispute
  
  let own_script_addr = Address { payment_credential: VerificationKey("script"), stake_credential: None }
  
  let next_datum = EscrowDatum {
    ..datum,
    state: Disputed,
  }
  
  let tx = Transaction {
    ..get_mock_tx(),
    extra_signatories: ["customer"],
    inputs: [
      Input {
        output_reference: OutputReference { transaction_id: "", output_index: 0 },
        output: Output { address: own_script_addr, value: assets.from_lovelace(1100), datum: NoDatum, reference_script: None },
      }
    ],
    outputs: [
      Output { address: own_script_addr, value: assets.from_lovelace(1100), datum: InlineDatum(next_datum), reference_script: None },
    ],
  }
  
  let own_ref = OutputReference { transaction_id: "", output_index: 0 }
  
  escrow_logic.validate_spend(Some(datum), redeemer, own_ref, tx)
}

test test_auto_release_success() {
  let datum = get_mock_datum()
  let redeemer = AutoRelease
  
  let merchant_addr = Address { payment_credential: VerificationKey("merchant"), stake_credential: None }
  let treasury_addr = Address { payment_credential: VerificationKey("treasury"), stake_credential: None }
  
  let tx = Transaction {
    ..get_mock_tx(),
    extra_signatories: ["merchant"],
    // Expiry slot is 1000, grace period is 100. Auto-release allowed after slot 1100.
    validity_range: interval.after(1101),
    outputs: [
      Output { address: merchant_addr, value: assets.from_lovelace(1000), datum: NoDatum, reference_script: None },
      Output { address: treasury_addr, value: assets.from_lovelace(100), datum: NoDatum, reference_script: None },
    ],
  }
  
  let own_ref = OutputReference { transaction_id: "", output_index: 0 }
  
  escrow_logic.validate_spend(Some(datum), redeemer, own_ref, tx)
}

test test_customer_refund_success() {
  let datum = get_mock_datum()
  let redeemer = CustomerRefund
  
  let customer_addr = Address { payment_credential: VerificationKey("customer"), stake_credential: None }
  
  let tx = Transaction {
    ..get_mock_tx(),
    extra_signatories: ["customer"],
    // Expiry slot is 1000, grace period is 100. Refund allowed after slot 1100.
    validity_range: interval.after(1101),
    outputs: [
      Output { address: customer_addr, value: assets.from_lovelace(1000), datum: NoDatum, reference_script: None },
    ],
  }
  
  let own_ref = OutputReference { transaction_id: "", output_index: 0 }
  
  escrow_logic.validate_spend(Some(datum), redeemer, own_ref, tx)
}

test test_admin_resolution_success() {
  let datum = EscrowDatum { ..get_mock_datum(), state: Disputed }
  let redeemer = AdminResolution {
    merchant_payout: [("", "", 400)],
    customer_payout: [("", "", 600)],
    fee_payout: 100,
  }
  
  let merchant_addr = Address { payment_credential: VerificationKey("merchant"), stake_credential: None }
  let customer_addr = Address { payment_credential: VerificationKey("customer"), stake_credential: None }
  let treasury_addr = Address { payment_credential: VerificationKey("treasury"), stake_credential: None }
  
  let tx = Transaction {
    ..get_mock_tx(),
    extra_signatories: ["admin"],
    outputs: [
      Output { address: merchant_addr, value: assets.from_lovelace(400), datum: NoDatum, reference_script: None },
      Output { address: customer_addr, value: assets.from_lovelace(600), datum: NoDatum, reference_script: None },
      Output { address: treasury_addr, value: assets.from_lovelace(100), datum: NoDatum, reference_script: None },
    ],
  }
  
  let own_ref = OutputReference { transaction_id: "", output_index: 0 }
  
  escrow_logic.validate_spend(Some(datum), redeemer, own_ref, tx)
}
