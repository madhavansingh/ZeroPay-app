use aiken/collection/list
use aiken/crypto.{VerificationKeyHash}
use aiken/interval.{Finite}
use cardano/address.{Address, Script, VerificationKey}
use cardano/assets
use cardano/transaction.{Input, OutputReference, Transaction, Output, Datum, InlineDatum}
use types

pub fn must_be_signed_by(tx: Transaction, pkh: VerificationKeyHash) -> Bool {
  list.has(tx.extra_signatories, pkh)
}

pub fn after_slot(tx: Transaction, slot: Int) -> Bool {
  when tx.validity_range.lower_bound.bound_type is {
    Finite(lower) -> lower >= slot
    _ -> False
  }
}

pub fn contains_greater_or_equal(left: assets.Value, right: assets.Value) -> Bool {
  let diff = assets.difference(left, right)
  list.all(
    assets.flatten(diff),
    fn(item) {
      let (_, _, quantity) = item
      quantity >= 0
    },
  )
}

pub fn values_equal(v1: assets.Value, v2: assets.Value) -> Bool {
  assets.is_zero(assets.difference(v1, v2))
}

pub fn paid_amount_to_pkh(tx: Transaction, pkh: VerificationKeyHash, amount: assets.Value) -> Bool {
  let target_addr = Address {
    payment_credential: VerificationKey(pkh),
    stake_credential: None,
  }
  let total_paid = list.foldl(
    tx.outputs,
    assets.zero,
    fn(output, acc) {
      if output.address == target_addr {
        assets.merge(acc, output.value)
      } else {
        acc
      }
    }
  )
  contains_greater_or_equal(total_paid, amount)
}

pub fn paid_lovelace_to_pkh(tx: Transaction, pkh: VerificationKeyHash, min_lovelace: Int) -> Bool {
  let target_addr = Address {
    payment_credential: VerificationKey(pkh),
    stake_credential: None,
  }
  let total_lovelace = list.foldl(
    tx.outputs,
    0,
    fn(output, acc) {
      if output.address == target_addr {
        acc + assets.lovelace_of(output.value)
      } else {
        acc
      }
    }
  )
  total_lovelace >= min_lovelace
}

pub fn find_own_script_outputs(tx: Transaction, own_ref: OutputReference) -> List<Output> {
  expect Some(own_input) =
    list.find(tx.inputs, fn(input) { input.output_reference == own_ref })
  let script_address = own_input.output.address
  list.filter(tx.outputs, fn(output) { output.address == script_address })
}

pub fn to_value(assets_list: List<types.AssetAmount>) -> assets.Value {
  list.foldl(
    assets_list,
    assets.zero,
    fn(item, acc) {
      let (policy_id, asset_name, quantity) = item
      assets.add(acc, policy_id, asset_name, quantity)
    }
  )
}

pub fn validate_spend(
  datum_opt: Option<types.EscrowDatum>,
  redeemer: types.EscrowRedeemer,
  own_ref: OutputReference,
  tx: Transaction,
) -> Bool {
  expect Some(datum) = datum_opt
  let total_amount = to_value(datum.total_amount)
  let released_amount = to_value(datum.released_amount)

  when redeemer is {
    types.ReleaseMilestone { payout_amount: payout_amount_data, fee_payout } -> {
      let payout_amount = to_value(payout_amount_data)
      let is_signed = must_be_signed_by(tx, datum.customer_pkh)
      let is_not_disputed =
        when datum.state is {
          types.Disputed -> False
          _ -> True
        }
      
      let has_merchant_payout = paid_amount_to_pkh(tx, datum.merchant_pkh, payout_amount)
      let has_fee_payout = if fee_payout > 0 {
        paid_lovelace_to_pkh(tx, datum.platform_treasury_pkh, fee_payout)
      } else {
        True
      }
      
      let is_final = datum.milestone_index + 1 == datum.total_milestones
      
      if is_final {
        is_signed && is_not_disputed && has_merchant_payout && has_fee_payout
      } else {
        let own_outputs = find_own_script_outputs(tx, own_ref)
        expect Some(next_script_output) = list.head(own_outputs)
        expect InlineDatum(raw_next_datum) = next_script_output.datum
        expect next_datum: types.EscrowDatum = raw_next_datum
        let next_total_amount = to_value(next_datum.total_amount)
        let next_released_amount = to_value(next_datum.released_amount)
        
        let has_valid_next_state =
          when next_datum.state is {
            types.PartiallyReleased -> True
            _ -> False
          }

        let valid_next_datum = 
          next_datum.merchant_pkh == datum.merchant_pkh &&
          next_datum.customer_pkh == datum.customer_pkh &&
          next_datum.admin_pkh == datum.admin_pkh &&
          next_datum.invoice_id == datum.invoice_id &&
          next_datum.platform_fee_lovelace == datum.platform_fee_lovelace &&
          next_datum.platform_treasury_pkh == datum.platform_treasury_pkh &&
          values_equal(next_total_amount, total_amount) &&
          values_equal(next_released_amount, assets.merge(released_amount, payout_amount)) &&
          next_datum.milestone_index == datum.milestone_index + 1 &&
          next_datum.total_milestones == datum.total_milestones &&
          has_valid_next_state &&
          next_datum.expiry_slot == datum.expiry_slot &&
          next_datum.grace_period_slots == datum.grace_period_slots &&
          next_datum.agreement_hash == datum.agreement_hash &&
          next_datum.metadata_hash == datum.metadata_hash &&
          next_datum.contract_version == datum.contract_version
          
        expect Some(own_input) =
          list.find(tx.inputs, fn(input) { input.output_reference == own_ref })
        let expected_remaining_value =
          assets.difference(
            own_input.output.value,
            assets.merge(payout_amount, assets.from_lovelace(fee_payout)),
          )
        let has_valid_remaining_value = values_equal(next_script_output.value, expected_remaining_value)
          
        is_signed && is_not_disputed && has_merchant_payout && has_fee_payout && valid_next_datum && has_valid_remaining_value
      }
    }

    types.AutoRelease -> {
      let is_signed = must_be_signed_by(tx, datum.merchant_pkh)
      let is_not_disputed =
        when datum.state is {
          types.Disputed -> False
          _ -> True
        }
      let is_expired = after_slot(tx, datum.expiry_slot + datum.grace_period_slots)
      
      let remaining_amount = assets.difference(total_amount, released_amount)
      let has_merchant_payout = paid_amount_to_pkh(tx, datum.merchant_pkh, remaining_amount)
      let has_fee_payout = paid_lovelace_to_pkh(tx, datum.platform_treasury_pkh, datum.platform_fee_lovelace)
      
      is_signed && is_not_disputed && is_expired && has_merchant_payout && has_fee_payout
    }

    types.CustomerRefund -> {
      let is_signed = must_be_signed_by(tx, datum.customer_pkh)
      let is_not_disputed =
        when datum.state is {
          types.Disputed -> False
          _ -> True
        }
      let is_expired = after_slot(tx, datum.expiry_slot + datum.grace_period_slots)
      
      let remaining_amount = assets.difference(total_amount, released_amount)
      let has_customer_refund = paid_amount_to_pkh(tx, datum.customer_pkh, remaining_amount)
      
      is_signed && is_not_disputed && is_expired && has_customer_refund
    }

    types.RaiseDispute -> {
      let is_signed = must_be_signed_by(tx, datum.customer_pkh) || must_be_signed_by(tx, datum.merchant_pkh)
      let is_not_already_disputed =
        when datum.state is {
          types.Disputed -> False
          _ -> True
        }
      
      let own_outputs = find_own_script_outputs(tx, own_ref)
      expect Some(next_script_output) = list.head(own_outputs)
      expect InlineDatum(raw_next_datum) = next_script_output.datum
      expect next_datum: types.EscrowDatum = raw_next_datum
      let next_total_amount = to_value(next_datum.total_amount)
      let next_released_amount = to_value(next_datum.released_amount)
      
      let has_valid_next_state =
        when next_datum.state is {
          types.Disputed -> True
          _ -> False
        }

      let valid_next_datum = 
        next_datum.merchant_pkh == datum.merchant_pkh &&
        next_datum.customer_pkh == datum.customer_pkh &&
        next_datum.admin_pkh == datum.admin_pkh &&
        next_datum.invoice_id == datum.invoice_id &&
        next_datum.platform_fee_lovelace == datum.platform_fee_lovelace &&
        next_datum.platform_treasury_pkh == datum.platform_treasury_pkh &&
        values_equal(next_total_amount, total_amount) &&
        values_equal(next_released_amount, released_amount) &&
        next_datum.milestone_index == datum.milestone_index &&
        next_datum.total_milestones == datum.total_milestones &&
        has_valid_next_state &&
        next_datum.expiry_slot == datum.expiry_slot &&
        next_datum.grace_period_slots == datum.grace_period_slots &&
        next_datum.agreement_hash == datum.agreement_hash &&
        next_datum.metadata_hash == datum.metadata_hash &&
        next_datum.contract_version == datum.contract_version
        
      expect Some(own_input) =
        list.find(tx.inputs, fn(input) { input.output_reference == own_ref })
      let value_preserved = values_equal(next_script_output.value, own_input.output.value)
        
      is_signed && is_not_already_disputed && valid_next_datum && value_preserved
    }

    types.AdminResolution { merchant_payout: merchant_payout_data, customer_payout: customer_payout_data, fee_payout } -> {
      let merchant_payout = to_value(merchant_payout_data)
      let customer_payout = to_value(customer_payout_data)
      let is_signed = must_be_signed_by(tx, datum.admin_pkh)
      
      let has_merchant_payout = paid_amount_to_pkh(tx, datum.merchant_pkh, merchant_payout)
      let has_customer_payout = paid_amount_to_pkh(tx, datum.customer_pkh, customer_payout)
      let has_fee_payout = if fee_payout > 0 {
        paid_lovelace_to_pkh(tx, datum.platform_treasury_pkh, fee_payout)
      } else {
        True
      }
      
      is_signed && has_merchant_payout && has_customer_payout && has_fee_payout
    }
  }
}
