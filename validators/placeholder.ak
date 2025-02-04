use aiken/collection/list
use aiken/crypto.{VerificationKeyHash}
use cardano/address.{Address, VerificationKey}
use cardano/assets.{AssetName, PolicyId, Value}
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
      Accept ->
        list.for_each(
          outputs,
          do: fn(output) {
            let Address { payment_credential, .. } = output.address

            when payment_credential is {
              VerificationKey(verification_key_hash) -> {
                expect Some(datum) = datum
                if datum.owner == verification_key_hash {
                  let (policy_id, asset_name) = datum.asset
                  let quantity =
                    output.value.quantity_of(
                      policy_id: policy_id,
                      asset_name: asset_name,
                    )
                  quantity >= datum.quantity
                } else {
                  False
                }
              }
            }
          },
        )

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
