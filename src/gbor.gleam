import gleam/dict.{type Dict}

pub type GborValue {
  GInt(Int)
  GArray(List(GborValue))
  GMap(Dict(GborValue, GborValue))
  GString(String)
  GBinary(BitArray)
  GFloat(Float)
  GBool(Bool)
  GNull
  GUndefined
}

pub type GBorError {
  MajorTypeError(Int)
  Unknown
}
