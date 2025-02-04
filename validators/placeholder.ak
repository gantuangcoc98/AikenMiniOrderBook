use aiken/collection/list
use aiken/crypto.{VerificationKeyHash}
use aiken/option
use aiken/primitive/bytearray
use cardano/address.{Address, Script, VerificationKey}
use cardano/assets.{AssetName, PolicyId, lovelace_of, quantity_of}
use cardano/transaction.{OutputReference, Transaction}

pub type OrderRedeemer {
  Accept
  Cancel
}

pub type OrderDatum {
  owner: VerificationKeyHash,
  asset: (PolicyId, AssetName),
  quantity: Int,
}

validator placeholder {
  spend(
    datum: Option<OrderDatum>,
    redeemer: OrderRedeemer,
    _utxo: OutputReference,
    self: Transaction,
  ) {
    let Transaction { outputs, extra_signatories, .. } = self

    when redeemer is {
      Accept -> {
        let matched_output =
          list.find(
            outputs,
            fn(output) {
              let Address { payment_credential, .. } = output.address

              when payment_credential is {
                VerificationKey(verification_key_hash) -> {
                  expect Some(datum) = datum
                  datum.owner == verification_key_hash
                }

                Script(_) -> False
              }
            },
          )

        if option.is_some(matched_output) {
          expect Some(output) = matched_output
          expect Some(datum) = datum

          let (policy_id, asset_name) = datum.asset

          if bytearray.is_empty(policy_id) {
            let lovelace = lovelace_of(output.value)
            lovelace >= datum.quantity
          } else {
            let quantity = quantity_of(output.value, policy_id, asset_name)
            quantity >= datum.quantity
          }
        } else {
          False
        }
      }

      Cancel -> {
        expect Some(datum) = datum
        list.has(extra_signatories, datum.owner)
      }
    }
  }

  else(_) {
    fail
  }

  // // If needs be, remove any of unneeded handlers above, and use:
  //
  // else(_ctx: ScriptContext) {
  //   todo @"fallback logic if none of the other purposes match"
  // }
  //
  // // You will also need an additional import:
  // //
  // // use cardano/script_context.{ScriptContext}
}
