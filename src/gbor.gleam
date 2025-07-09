pub type CBOR {
  CBInt(Int)
  CBString(String)
  CBFloat(Float)
  CBMap(List(#(CBOR, CBOR)))
  CBArray(List(CBOR))
  CBBool(Bool)
  CBNull
  CBUndefined
  CBBinary(BitArray)
  CBTagged(Int, CBOR)
}

// Placeholder for LSP
pub const a = Nil
