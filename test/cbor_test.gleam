import decode_test
import encode_test
import end_to_end_test
import gleeunit

pub fn main() {
  end_to_end_test.main()
  decode_test.main()
  encode_test.main()
}
