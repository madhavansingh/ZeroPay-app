use cardano/transaction.{OutputReference, Transaction}
use types
use escrow_logic

validator escrow_v1 {
  spend(
    datum_opt: Option<types.EscrowDatum>,
    redeemer: types.EscrowRedeemer,
    own_ref: OutputReference,
    tx: Transaction,
  ) {
    escrow_logic.validate_spend(datum_opt, redeemer, own_ref, tx)
  }
}
