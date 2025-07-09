pub type CBOR {
  Int(Int)
  String(String)
  Float(Float)
  Map(List(#(CBOR, CBOR)))
  Array(List(CBOR))
  Bool(Bool)
  Null
  Undefined
  Binary(BitArray)
  Tagged(Int, CBOR)
}
