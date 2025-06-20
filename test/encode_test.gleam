import gleam/bit_array
import gleam/string
import gleeunit
import gleeunit/should

import encode

pub fn main() {
  gleeunit.main()
}

pub fn x_test() {
  encode.int(23)
  |> encode.to_bit_array
  |> bit_array.base16_encode
  |> should.equal("17")

  encode.int(24)
  |> encode.to_bit_array
  |> bit_array.base16_encode
  |> should.equal("1818")

  encode.int(0x100)
  |> encode.to_bit_array
  |> bit_array.base16_encode
  |> should.equal("190100")

  encode.int(0x10000)
  |> encode.to_bit_array
  |> bit_array.base16_encode
  |> should.equal("1A00010000")

  encode.int(0x100000000)
  |> encode.to_bit_array
  |> bit_array.base16_encode
  |> should.equal("1B0000000100000000")

  encode.int(0xffffffffffffffff)
  |> encode.to_bit_array
  |> bit_array.base16_encode
  |> should.equal("1BFFFFFFFFFFFFFFFF")
}

pub fn int_test() {
  encode.int(-23)
  |> encode.to_bit_array
  |> bit_array.base16_encode
  |> should.equal("36")

  encode.int(-{ 0x100 })
  |> encode.to_bit_array
  |> bit_array.base16_encode
  |> should.equal("38FF")
}

pub fn string_test() {
  encode.string("Hello, world!")
  |> encode.to_bit_array
  |> bit_array.base16_encode
  |> should.equal("6D48656C6C6F2C20776F726C6421")
}

pub fn array_test() {
  encode.array([encode.int(1), encode.int(2), encode.int(3), encode.int(4)])
  |> encode.to_bit_array
  |> bit_array.base16_encode
  |> should.equal("8401020304")
}

pub fn map_test() {
  encode.map([
    #(encode.string("a"), encode.int(1)),
    #(encode.string("b"), encode.int(2)),
  ])
  |> encode.to_bit_array
  |> bit_array.base16_encode
  |> should.equal("A2616101616202")
}

pub fn stress_test_disabled() {
  let expected_complex_data =
    "A66475736572A762696419303968757365726E616D65676A6F686E646F6565656D61696C746A6F686E2E646F65406578616D706C652E636F6D6770726F66696C65A66966697273744E616D65644A6F686E686C6173744E616D6563446F65636167651820686973416374697665F566617661746172F66B707265666572656E636573A3657468656D65646461726B686C616E677561676562656E6D6E6F74696669636174696F6E73A365656D61696CF56470757368F463736D73F56961646472657373657382A7647479706564686F6D65667374726565746B313233204D61696E205374646369747967416E79746F776E657374617465624341677A6970436F646565393032313067636F756E7472796355534169697344656661756C74F5A7647479706564776F726B667374726565747034353620427573696E65737320417665646369747968576F726B746F776E657374617465624E59677A6970436F646565313030303167636F756E7472796355534169697344656661756C74F4666F726465727382A6676F726465724964674F52442D303031646461746574323032342D30312D31355431303A33303A30305A6673746174757369636F6D706C6574656465746F74616CFB4072BFD70A3D70A4656974656D7382A56970726F6475637449646850524F442D313233646E616D6573576972656C657373204865616470686F6E6573687175616E7469747901657072696365FB4068FFAE147AE148676F7074696F6E73A265636F6C6F7265626C61636B6877617272616E747966322D79656172A56970726F6475637449646850524F442D343536646E616D656B5553422D43204361626C65687175616E7469747902657072696365F95240676F7074696F6E73A2666C656E6774686333667464747970656D666173742D6368617267696E67687368697070696E67A3666D6574686F64676578707265737364636F7374F94B806E747261636B696E674E756D6265726C54524B313233343536373839A6676F726465724964674F52442D303032646461746574323032342D30322D32305431343A31353A30305A667374617475736A70726F63657373696E6765746F74616CF95598656974656D7381A56970726F6475637449646850524F442D373839646E616D656B536D617274205761746368687175616E7469747901657072696365F95598676F7074696F6E73A26473697A656434326D6D6462616E646873696C69636F6E65687368697070696E67A3666D6574686F64687374616E6461726464636F7374F900006E747261636B696E674E756D626572F6686D65746164617461A56963726561746564417474323032332D30362D30315430393A30303A30305A696C6173744C6F67696E74323032342D30332D31305431363A34353A33305A6A6C6F67696E436F756E74189C647461677383677072656D69756D6876657269666965646D6561726C792D61646F707465726673636F726573A3676C6F79616C7479F955F86A656E676167656D656E74FB4055CCCCCCCCCCCD6C736174697366616374696F6EFB40573333333333336873657474696E6773A166676C6F62616CA3656465627567F46776657273696F6E65322E312E30686665617475726573A46E616476616E636564536561726368F5686461726B4D6F6465F56D6E6F74696669636174696F6E73F569616E616C7974696373F46A656D7074794172726179806B656D7074794F626A656374A06A6D697865644172726179866C737472696E672076616C7565182AF5F6A1666E6573746564666F626A656374840102036B6D69786564207479706573717370656369616C43686172616374657273A467756E69636F646575636166C3A92072C3A973756DC3A9206E61C3AF76656671756F7465737748652073616964202248656C6C6F2C20776F726C642122676573636170657378254C696E6520310A4C696E652032095461626265640D0A43617272696167652072657475726E6773796D626F6C7375C2A920C2AE20E284A220E282AC20C2A320C2A52024"
  let complex_data =
    encode.map([
      #(
        encode.string("user"),
        encode.map([
          #(encode.string("id"), encode.int(12_345)),
          #(encode.string("username"), encode.string("johndoe")),
          #(encode.string("email"), encode.string("john.doe@example.com")),
          #(
            encode.string("profile"),
            encode.map([
              #(encode.string("firstName"), encode.string("John")),
              #(encode.string("lastName"), encode.string("Doe")),
              #(encode.string("age"), encode.int(32)),
              #(encode.string("isActive"), encode.bool(True)),
              #(encode.string("avatar"), encode.null()),
              #(
                encode.string("preferences"),
                encode.map([
                  #(encode.string("theme"), encode.string("dark")),
                  #(encode.string("language"), encode.string("en")),
                  #(
                    encode.string("notifications"),
                    encode.map([
                      #(encode.string("email"), encode.bool(True)),
                      #(encode.string("push"), encode.bool(False)),
                      #(encode.string("sms"), encode.bool(True)),
                    ]),
                  ),
                ]),
              ),
            ]),
          ),
          #(
            encode.string("addresses"),
            encode.array([
              encode.map([
                #(encode.string("type"), encode.string("home")),
                #(encode.string("street"), encode.string("123 Main St")),
                #(encode.string("city"), encode.string("Anytown")),
                #(encode.string("state"), encode.string("CA")),
                #(encode.string("zipCode"), encode.string("90210")),
                #(encode.string("country"), encode.string("USA")),
                #(encode.string("isDefault"), encode.bool(True)),
              ]),
              encode.map([
                #(encode.string("type"), encode.string("work")),
                #(encode.string("street"), encode.string("456 Business Ave")),
                #(encode.string("city"), encode.string("Worktown")),
                #(encode.string("state"), encode.string("NY")),
                #(encode.string("zipCode"), encode.string("10001")),
                #(encode.string("country"), encode.string("USA")),
                #(encode.string("isDefault"), encode.bool(False)),
              ]),
            ]),
          ),
          #(
            encode.string("orders"),
            encode.array([
              encode.map([
                #(encode.string("orderId"), encode.string("ORD-001")),
                #(encode.string("date"), encode.string("2024-01-15T10:30:00Z")),
                #(encode.string("status"), encode.string("completed")),
                #(encode.string("total"), encode.float(299.99)),
                #(
                  encode.string("items"),
                  encode.array([
                    encode.map([
                      #(encode.string("productId"), encode.string("PROD-123")),
                      #(
                        encode.string("name"),
                        encode.string("Wireless Headphones"),
                      ),
                      #(encode.string("quantity"), encode.int(1)),
                      #(encode.string("price"), encode.float(199.99)),
                      #(
                        encode.string("options"),
                        encode.map([
                          #(encode.string("color"), encode.string("black")),
                          #(encode.string("warranty"), encode.string("2-year")),
                        ]),
                      ),
                    ]),
                    encode.map([
                      #(encode.string("productId"), encode.string("PROD-456")),
                      #(encode.string("name"), encode.string("USB-C Cable")),
                      #(encode.string("quantity"), encode.int(2)),
                      #(encode.string("price"), encode.float(50.0)),
                      #(
                        encode.string("options"),
                        encode.map([
                          #(encode.string("length"), encode.string("3ft")),
                          #(
                            encode.string("type"),
                            encode.string("fast-charging"),
                          ),
                        ]),
                      ),
                    ]),
                  ]),
                ),
                #(
                  encode.string("shipping"),
                  encode.map([
                    #(encode.string("method"), encode.string("express")),
                    #(encode.string("cost"), encode.float(15.0)),
                    #(
                      encode.string("trackingNumber"),
                      encode.string("TRK123456789"),
                    ),
                  ]),
                ),
              ]),
              encode.map([
                #(encode.string("orderId"), encode.string("ORD-002")),
                #(encode.string("date"), encode.string("2024-02-20T14:15:00Z")),
                #(encode.string("status"), encode.string("processing")),
                #(encode.string("total"), encode.float(89.5)),
                #(
                  encode.string("items"),
                  encode.array([
                    encode.map([
                      #(encode.string("productId"), encode.string("PROD-789")),
                      #(encode.string("name"), encode.string("Smart Watch")),
                      #(encode.string("quantity"), encode.int(1)),
                      #(encode.string("price"), encode.float(89.5)),
                      #(
                        encode.string("options"),
                        encode.map([
                          #(encode.string("size"), encode.string("42mm")),
                          #(encode.string("band"), encode.string("silicone")),
                        ]),
                      ),
                    ]),
                  ]),
                ),
                #(
                  encode.string("shipping"),
                  encode.map([
                    #(encode.string("method"), encode.string("standard")),
                    #(encode.string("cost"), encode.float(0.0)),
                    #(encode.string("trackingNumber"), encode.null()),
                  ]),
                ),
              ]),
            ]),
          ),
          #(
            encode.string("metadata"),
            encode.map([
              #(
                encode.string("createdAt"),
                encode.string("2023-06-01T09:00:00Z"),
              ),
              #(
                encode.string("lastLogin"),
                encode.string("2024-03-10T16:45:30Z"),
              ),
              #(encode.string("loginCount"), encode.int(156)),
              #(
                encode.string("tags"),
                encode.array([
                  encode.string("premium"),
                  encode.string("verified"),
                  encode.string("early-adopter"),
                ]),
              ),
              #(
                encode.string("scores"),
                encode.map([
                  #(encode.string("loyalty"), encode.float(95.5)),
                  #(encode.string("engagement"), encode.float(87.2)),
                  #(encode.string("satisfaction"), encode.float(92.8)),
                ]),
              ),
            ]),
          ),
        ]),
      ),
      #(
        encode.string("settings"),
        encode.map([
          #(
            encode.string("global"),
            encode.map([
              #(encode.string("debug"), encode.bool(False)),
              #(encode.string("version"), encode.string("2.1.0")),
              #(
                encode.string("features"),
                encode.map([
                  #(encode.string("advancedSearch"), encode.bool(True)),
                  #(encode.string("darkMode"), encode.bool(True)),
                  #(encode.string("notifications"), encode.bool(True)),
                  #(encode.string("analytics"), encode.bool(False)),
                ]),
              ),
            ]),
          ),
        ]),
      ),
      #(encode.string("emptyArray"), encode.array([])),
      #(encode.string("emptyObject"), encode.map([])),
      #(
        encode.string("mixedArray"),
        encode.array([
          encode.string("string value"),
          encode.int(42),
          encode.bool(True),
          encode.null(),
          encode.map([#(encode.string("nested"), encode.string("object"))]),
          encode.array([
            encode.int(1),
            encode.int(2),
            encode.int(3),
            encode.string("mixed types"),
          ]),
        ]),
      ),
      #(
        encode.string("specialCharacters"),
        encode.map([
          #(encode.string("unicode"), encode.string("café résumé naïve")),
          #(encode.string("quotes"), encode.string("He said \"Hello, world!\"")),
          #(
            encode.string("escapes"),
            encode.string("Line 1\nLine 2\tTabbed\r\nCarriage return"),
          ),
          #(encode.string("symbols"), encode.string("© ® ™ € £ ¥ $")),
        ]),
      ),
    ])

  complex_data
  |> encode.to_bit_array
  |> bit_array.base16_encode
  |> string.length
  |> should.equal(string.length(expected_complex_data))
}
