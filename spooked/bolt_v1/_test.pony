use "collections"
// use "itertools"
use "ponytest"

use ".."

actor Main is TestList
  new create(env: Env) =>
    PonyTest(env, this)

  new make() =>
    None

  fun tag tests(test: PonyTest) =>
    test(_TestPackStreamH)

    // Test packing
    test(_TestPackStreamPackedNone)
    test(_TestPackStreamPackedBoolean)
    test(_TestPackStreamPackedInteger)
    test(_TestPackStreamPackedFloat)
    test(_TestPackStreamPackedString)
    test(_TestPackStreamPackedList)
    test(_TestPackStreamPackedMap)
    test(_TestPackStreamPackedStructure)

    // Test unpacking
    test(_TestPackStreamUnpackedNone)
    test(_TestPackStreamUnpackedBoolean)
    test(_TestPackStreamUnpackedInteger)
    test(_TestPackStreamUnpackedFloat)
    test(_TestPackStreamUnpackedString)
    test(_TestPackStreamUnpackedList)
    test(_TestPackStreamUnpackedMap)
    test(_TestPackStreamUnpackedStructure)

    // Test message structures
    test(_TestClientMessageInit)
    test(_TestClientMessageRun)
    test(_TestClientMessageDiscardAll)
    test(_TestClientMessagePullAll)
    test(_TestClientMessageAckFailure)
    test(_TestClientMessageReset)
    // test(_TestServerMessageRecord)
    // test(_TestServerMessageSuccess)
    // test(_TestServerMessageFailure)
    // test(_TestServerMessageIgnored)


class iso _TestPackStreamH is UnitTest
  fun name(): String =>
    "spooked/bolt/v1/serialization/_PackStream/h"

  fun apply(h: TestHelper) =>
    h.assert_eq[String]("03:41:7E", _PackStream.h("\x03A~"))

class iso _TestPackStreamPackedNone is UnitTest
  fun name(): String =>
    "spooked/bolt/v1/serialization/_PackStream/packed/None"

  fun apply(h: TestHelper) ? =>
    h.assert_eq[String](
      "C0", // None
      _PackStream.h(
        _PackStream.packed([None])?))

class iso _TestPackStreamUnpackedNone is UnitTest
  fun name(): String =>
    "spooked/bolt/v1/serialization/_PackStream/unpacked/None"

  fun apply(h: TestHelper) ? =>
    var value = CypherNull
    var pkd = _PackStream.packed([value])?
    var unpkd = _PackStream.unpacked(pkd)? as CypherNull
    h.assert_eq[CypherNull](value, unpkd)

class iso _TestPackStreamPackedBoolean is UnitTest
  fun name(): String =>
    "spooked/bolt/v1/serialization/_PackStream/packed/Boolean"

  fun apply(h: TestHelper) ? =>
    h.assert_eq[String](
      "C2", // false
      _PackStream.h(
        _PackStream.packed([false])?))
    h.assert_eq[String](
      "C3", // true
      _PackStream.h(
        _PackStream.packed([true])?))

class iso _TestPackStreamUnpackedBoolean is UnitTest
  fun name(): String =>
    "spooked/bolt/v1/serialization/_PackStream/unpacked/Boolean"

  fun apply(h: TestHelper) ? =>
    for value in [
      false
      true
    ].values() do
      let pkd = _PackStream.packed([value])?
      let unpkd = _PackStream.unpacked(pkd)? as CypherBoolean
      h.assert_eq[CypherBoolean](value, unpkd)
    end

class iso _TestPackStreamPackedInteger is UnitTest
  fun name(): String =>
    "spooked/bolt/v1/serialization/_PackStream/packed/Integer"

  fun apply(h: TestHelper) ? =>

    // Negative INT_64 Range: -9,223,372,036,854,775,808 -> -2,147,483,649
    h.assert_eq[String](
      "CB:80:00:00:00:00:00:00:00", // -9,223,372,036,854,775,808
      _PackStream.h(
        _PackStream.packed([I64(-9_223_372_036_854_775_808)])?))
    h.assert_eq[String](
      "CB:FF:FF:FF:FF:7F:FF:FF:FF", // -2,147,483,649
      _PackStream.h(
        _PackStream.packed([I64(-2_147_483_649)])?))

    // Negative INT_32 Range: -2,147,483,648 -> -32,769
    h.assert_eq[String](
      "CA:80:00:00:00", // -2,147,483,648
      _PackStream.h(
        _PackStream.packed([I64(-2_147_483_648)])?))
    h.assert_eq[String](
      "CA:FF:FF:7F:FF", // -32,769
      _PackStream.h(
        _PackStream.packed([I64(-32_769)])?))

    // Negative INT_16 Range: -32,768 -> -129
    h.assert_eq[String](
      "C9:80:00", // -32,768
      _PackStream.h(
        _PackStream.packed([I64(-32_768)])?))
    h.assert_eq[String](
      "C9:FF:7F", // -129
      _PackStream.h(
        _PackStream.packed([I64(-129)])?))

    // Negative INT_8 Range: -128 -> -17
    h.assert_eq[String](
      "C8:80", // -128
      _PackStream.h(
        _PackStream.packed([I64(-128)])?))
    h.assert_eq[String](
      "C8:EF", // -17
      _PackStream.h(
        _PackStream.packed([I64(-17)])?))

    // TINY_INT Range: -16 -> 127
    h.assert_eq[String](
      "F0", // -16
      _PackStream.h(
        _PackStream.packed([I64(-16)])?))
    h.assert_eq[String](
      "7F", // 127
      _PackStream.h(
        _PackStream.packed([I64(127)])?))

    // Positive INT_16 Range: 128 -> 32,767
    h.assert_eq[String](
      "C9:00:80", // 128
      _PackStream.h(
        _PackStream.packed([I64(128)])?))
    h.assert_eq[String](
      "C9:7F:FF", // 32,767
      _PackStream.h(
        _PackStream.packed([I64(32_767)])?))

    // Positive INT_32 Range: 32,768 -> 2,147,483,647
    h.assert_eq[String](
      "CA:00:00:80:00", // 32,768
      _PackStream.h(
        _PackStream.packed([I64(32_768)])?))
    h.assert_eq[String](
      "CA:7F:FF:FF:FF", // 2,147,483,647
      _PackStream.h(
        _PackStream.packed([I64(2_147_483_647)])?))

    // Positive INT_64 Range: 2,147,483,648 -> 9,223,372,036,854,775,807
    h.assert_eq[String](
      "CB:00:00:00:00:80:00:00:00", // 2,147,483,648
      _PackStream.h(
        _PackStream.packed([I64(2_147_483_648)])?))
    h.assert_eq[String](
      "CB:7F:FF:FF:FF:FF:FF:FF:FF", // 9,223,372,036,854,775,807
      _PackStream.h(
        _PackStream.packed([I64(9_223_372_036_854_775_807)])?))

class iso _TestPackStreamUnpackedInteger is UnitTest
  fun name(): String =>
    "spooked/bolt/v1/serialization/_PackStream/unpacked/Integer"

  fun apply(h: TestHelper) ? =>
    for value in [
      I64(-9_223_372_036_854_775_808)
      I64(-2_147_483_649)
      I64(-2_147_483_648)
      I64(-32_769)
      I64(-32_768)
      I64(-129)
      I64(-128)
      I64(-17)
      I64(-16)
      I64(127)
      I64(128)
      I64(32_767)
      I64(32_768)
      I64(2_147_483_647)
      I64(2_147_483_648)
      I64(9_223_372_036_854_775_807)
    ].values() do
      let pkd = _PackStream.packed([value])?
      let unpkd = _PackStream.unpacked(pkd)? as CypherInteger
      h.assert_eq[CypherInteger](value, unpkd)
    end

class iso _TestPackStreamPackedFloat is UnitTest
  fun name(): String =>
    "spooked/bolt/v1/serialization/_PackStream/packed/Float"

  fun apply(h: TestHelper) ? =>
    h.assert_eq[String](
      "C1:3F:F1:99:99:99:99:99:9A", // +1.1
      _PackStream.h(
        _PackStream.packed([F64(1.1)])?))
    h.assert_eq[String](
      "C1:BF:F1:99:99:99:99:99:9A", // -1.1
      _PackStream.h(
        _PackStream.packed([F64(-1.1)])?))

class iso _TestPackStreamUnpackedFloat is UnitTest
  fun name(): String =>
    "spooked/bolt/v1/serialization/_PackStream/unpacked/Float"

  fun apply(h: TestHelper) ? =>
    for value in [
      F64(1.1)
      F64(-1.1)
    ].values() do
      let pkd = _PackStream.packed([value])?
      let unpkd = _PackStream.unpacked(pkd)? as CypherFloat
      h.assert_eq[CypherFloat](value, unpkd)
    end

class iso _TestPackStreamPackedString is UnitTest
  fun name(): String =>
    "spooked/bolt/v1/serialization/_PackStream/packed/String"

  fun apply(h: TestHelper) ? =>
    h.assert_eq[String](
      "80", // ""
      _PackStream.h(
        _PackStream.packed([""])?))
    h.assert_eq[String](
      "81:41", // "A"
      _PackStream.h(
        _PackStream.packed(["A"])?))
    h.assert_eq[String](
      "D0:1A:41:42:43:44:45:46:47:48:49:4A:4B:4C:4D:4E:4F:50:51:52:53:54:55:56:57:58:59:5A", // "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
      _PackStream.h(
        _PackStream.packed(["ABCDEFGHIJKLMNOPQRSTUVWXYZ"])?))
    h.assert_eq[String](
      "D0:12:47:72:C3:B6:C3:9F:65:6E:6D:61:C3:9F:73:74:C3:A4:62:65", // "Größenmaßstäbe"
      _PackStream.h(
        _PackStream.packed(["Größenmaßstäbe"])?))

class iso _TestPackStreamUnpackedString is UnitTest
  fun name(): String =>
    "spooked/bolt/v1/serialization/_PackStream/unpacked/String"

  fun apply(h: TestHelper) ? =>
    for value in [
      ""
      "A"
      "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
      "Größenmaßstäbe"
    ].values() do
      let pkd = _PackStream.packed([value])?
      let unpkd = _PackStream.unpacked(pkd)? as CypherString
      h.assert_eq[CypherString](value, unpkd)
    end

class iso _TestPackStreamPackedList is UnitTest
  fun name(): String =>
    "spooked/bolt/v1/serialization/_PackStream/packed/List"

  fun apply(h: TestHelper) ? =>
    var list = CypherList([])
    // Empty list
    h.assert_eq[String](
      "90",
      _PackStream.h(
        _PackStream.packed([list])?))
    // [1, 2, 3]
    list = CypherList([I64(1); I64(2); I64(3)])
    h.assert_eq[String](
      "93:01:02:03",
      _PackStream.h(
        _PackStream.packed([list])?))
    // [1, 2.0, "three"]
    list = CypherList([I64(1); F64(2.0); "three"])
    h.assert_eq[String](
      "93:01:C1:40:00:00:00:00:00:00:00:85:74:68:72:65:65",
      _PackStream.h(
        _PackStream.packed([list])?))
    // [1, 2, 3 ... 40]
    let data3 = recover trn Array[CypherType val] end
    for i in Range(1, 41) do
      data3.push(i.i64())
    end
    list = CypherList(consume data3)
    h.assert_eq[String](
      "D4:28:01:02:03:04:05:06:07:08:09:0A:0B:0C:0D:0E:0F:10:11:12:13:14:15:16:17:18:19:1A:1B:1C:1D:1E:1F:20:21:22:23:24:25:26:27:28",
      _PackStream.h(
        _PackStream.packed([list])?))

class iso _TestPackStreamUnpackedList is UnitTest
  fun name(): String =>
    "spooked/bolt/v1/serialization/_PackStream/unpacked/List"

  fun apply(h: TestHelper) ? =>
    var value: CypherList val
    var pkd: ByteSeq
    var unpkd: CypherList val
    // Empty list
    value = CypherList([])
    pkd = _PackStream.packed([value])?
    unpkd = _PackStream.unpacked(pkd)? as CypherList val
    h.assert_eq[U64](
      _PackStream.hashed_packed(value)?, _PackStream.hashed_packed(unpkd)?)
    // Homogeneous list
    value = CypherList([I64(1); I64(2); I64(3)])
    pkd = _PackStream.packed([value])?
    unpkd = _PackStream.unpacked(pkd)? as CypherList val
    h.assert_eq[U64](
      _PackStream.hashed_packed(value)?, _PackStream.hashed_packed(unpkd)?)
    // Heterogeneous list
    value = CypherList([I64(1); F64(2.0); "three"])
    pkd = _PackStream.packed([value])?
    unpkd = _PackStream.unpacked(pkd)? as CypherList val
    h.assert_eq[U64](
      _PackStream.hashed_packed(value)?, _PackStream.hashed_packed(unpkd)?)
    // Longer list
    let one_to_forty = recover trn Array[CypherType val] end
    for i in Range[I64](1, 41) do
      one_to_forty.push(i)
    end
    value = CypherList(consume one_to_forty)
    pkd = _PackStream.packed([value])?
    unpkd = _PackStream.unpacked(pkd)? as CypherList val
    h.assert_eq[U64](
      _PackStream.hashed_packed(value)?, _PackStream.hashed_packed(unpkd)?)

class iso _TestPackStreamPackedMap is UnitTest
  fun name(): String =>
    "spooked/bolt/v1/serialization/_PackStream/packed/Map"

  fun apply(h: TestHelper) ? =>
    var map: CypherMap val
    // Empty map
    let data1 = recover val MapIs[CypherType val, CypherType val] end
    map = CypherMap(data1)
    h.assert_eq[String](
      "A0",
      _PackStream.h(
        _PackStream.packed([map])?))
    // {"one": "eins"}
    let data2 = recover trn MapIs[CypherType val, CypherType val] end
    data2("one") = "eins"
    map = CypherMap(consume data2)
    h.assert_eq[String](
      "A1:83:6F:6E:65:84:65:69:6E:73",
      _PackStream.h(
        _PackStream.packed([map])?))
    // {"A": 1, "B": 2, ... "Z": 26}
    let data3 = recover trn MapIs[CypherType val, CypherType val] end
    let alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    var pos: USize = 0
    for i in Range(0, 26) do
      pos = i + 1
      data3(alphabet.trim(i, pos)) = pos.i64()
    end
    map = CypherMap(consume data3)
    let packed_map = _PackStream.h(_PackStream.packed([map])?)
    let sub_seq_asserts = [
      "D8:1A" // D8 marker, 26 pairs
      ":81:41:01"; ":81:42:02"; ":81:43:03"; ":81:44:04"; ":81:45:05" // ABCDE
      ":81:46:06"; ":81:47:07"; ":81:48:08"; ":81:49:09"; ":81:4A:0A" // FGHIJ
      ":81:4B:0B"; ":81:4C:0C"; ":81:4D:0D"; ":81:4E:0E"; ":81:4F:0F" // KLMNO
      ":81:50:10"; ":81:51:11"; ":81:52:12"; ":81:53:13"; ":81:54:14" // PQRST
      ":81:55:15"; ":81:56:16"; ":81:57:17"; ":81:58:18"; ":81:59:19" // UVWXY
      ":81:5A:1A" // Z
    ]
    for sub_seq in sub_seq_asserts.values() do
      h.assert_true(packed_map.contains(sub_seq))
    end

class iso _TestPackStreamUnpackedMap is UnitTest
  fun name(): String =>
    "spooked/bolt/v1/serialization/_PackStream/unpacked/Map"

  fun apply(h: TestHelper) ? =>
    var map: CypherMap val
    var pkd: ByteSeq
    var unpkd: CypherMap val
    // Empty Map
    let data1 = recover val MapIs[CypherType val, CypherType val] end
    map = CypherMap(data1)
    pkd = _PackStream.packed([map])?
    unpkd = _PackStream.unpacked(pkd)? as CypherMap val
    h.assert_eq[U64](
      _PackStream.hashed_packed(map)?, _PackStream.hashed_packed(unpkd)?)
    // {"one": "eins"}
    let data2 = recover trn MapIs[CypherType val, CypherType val] end
    data2("one") = "eins"
    map = CypherMap(consume data2)
    pkd = _PackStream.packed([map])?
    unpkd = _PackStream.unpacked(pkd)? as CypherMap val
    h.assert_eq[U64](
      _PackStream.hashed_packed(map)?, _PackStream.hashed_packed(unpkd)?)
    // {"A": 1, "B": 2, ... "Z": 26}
    let data3 = recover trn MapIs[CypherType val, CypherType val] end
    let alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    var pos: USize = 0
    for i in Range(0, 26) do
      pos = i + 1
      data3(alphabet.trim(i, pos)) = pos.i64()
    end
    map = CypherMap(consume data3)
    pkd = _PackStream.packed([map])?
    unpkd = _PackStream.unpacked(pkd)? as CypherMap val
    // Cannot assert_eq hashed_packed because map pairs are unordered...
    // Assert map sizes
    h.assert_eq[USize](map.data.size(), unpkd.data.size())
    // Cannot directly compare due to MapIs (?), so copy into Maps
    var map' = Map[String, I64].create(map.data.size())
    for (k,v) in map.data.pairs() do
      map'(k as String) = v as I64
    end
    var unpkd' = Map[String, I64].create(unpkd.data.size())
    for (k,v) in unpkd.data.pairs() do
      unpkd'(k as String) = v as I64
    end
    // Assert each has required keys with equal values.
    pos = 0
    for i in Range(0, 26) do
      pos = i + 1
      let letter: String = alphabet.trim(i, pos)
        h.assert_eq[I64](
          map'(letter)? as CypherInteger,
          unpkd'(letter)? as CypherInteger)
    end
    // Repack `unpkd`, and assert it has the packed subsequences representing
    // packed pairs.
    let repacked_unpkd = _PackStream.h(_PackStream.packed([unpkd])?)
    let sub_seq_asserts = [
      "D8:1A" // D8 marker, 26 pairs
      ":81:41:01"; ":81:42:02"; ":81:43:03"; ":81:44:04"; ":81:45:05" // ABCDE
      ":81:46:06"; ":81:47:07"; ":81:48:08"; ":81:49:09"; ":81:4A:0A" // FGHIJ
      ":81:4B:0B"; ":81:4C:0C"; ":81:4D:0D"; ":81:4E:0E"; ":81:4F:0F" // KLMNO
      ":81:50:10"; ":81:51:11"; ":81:52:12"; ":81:53:13"; ":81:54:14" // PQRST
      ":81:55:15"; ":81:56:16"; ":81:57:17"; ":81:58:18"; ":81:59:19" // UVWXY
      ":81:5A:1A" // Z
    ]
    for sub_seq in sub_seq_asserts.values() do
      h.assert_true(repacked_unpkd.contains(sub_seq))
    end

class iso _TestPackStreamPackedStructure is UnitTest
  fun name(): String =>
    "spooked/bolt/v1/serialization/_PackStream/packed/Structure"

  fun apply(h: TestHelper) ? =>
    var structure: CypherStructure val
    var signature: U8
    let fields1 = recover trn Array[CypherType val] end
    // Struct(sig=0x01, fields=[1,2,3])
    signature = 0x01
    fields1
      .> push(I64(1))
      .> push(I64(2))
      .> push(I64(3))
    structure = CypherStructure(signature, consume fields1)
    h.assert_eq[String](
      "B3:01:01:02:03",
      _PackStream.h(
        _PackStream.packed([structure])?))
    // Struct(sig=0x7F, fields=[1,2,3,4,5,6,7,8,9,0,1,2,3,4,5,6]
    signature = 0x7F
    let fields2 = recover trn Array[CypherType val] end
    fields2
      .> push(I64(1)) .> push(I64(2)) .> push(I64(3)) .> push(I64(4))
      .> push(I64(5)) .> push(I64(6)) .> push(I64(7)) .> push(I64(8))
      .> push(I64(9)) .> push(I64(0)) .> push(I64(1)) .> push(I64(2))
      .> push(I64(3)) .> push(I64(4)) .> push(I64(5)) .> push(I64(6))
    structure = CypherStructure(signature, consume fields2)
    h.assert_eq[String](
      "DC:10:7F:01:02:03:04:05:06:07:08:09:00:01:02:03:04:05:06",
      _PackStream.h(
        _PackStream.packed([structure])?))

class iso _TestPackStreamUnpackedStructure is UnitTest
  fun name(): String =>
    "spooked/bolt/v1/serialization/_PackStream/unpacked/Structure"

  fun apply(h: TestHelper) ? =>
    var value: CypherStructure val
    var pkd: ByteSeq
    var unpkd: CypherStructure val
    // Struct(sig=0x01, fields=[1,2,3])
    value = CypherStructure(0x01, [I64(1); I64(2); I64(3)])
    pkd = _PackStream.packed([value])?
    unpkd = _PackStream.unpacked(pkd)? as CypherStructure val
    h.assert_eq[U8](value.signature, unpkd.signature)
    h.assert_eq[USize](value.field_count(), unpkd.field_count())
    h.assert_eq[U64](
      _PackStream.hashed_packed(value)?, _PackStream.hashed_packed(unpkd)?)
    // Struct(sig=0x7F, fields=[1,2,3,4,5,6,7,8,9,0,1,2,3,4,5,6]
    var fields = recover trn Array[CypherType val] end
    fields
      .> push(I64(1)) .> push(I64(2)) .> push(I64(3)) .> push(I64(4))
      .> push(I64(5)) .> push(I64(6)) .> push(I64(7)) .> push(I64(8))
      .> push(I64(9)) .> push(I64(0)) .> push(I64(1)) .> push(I64(2))
      .> push(I64(3)) .> push(I64(4)) .> push(I64(5)) .> push(I64(6))
    value = CypherStructure(0x7f, consume fields)
    pkd = _PackStream.packed([value])?
    unpkd = _PackStream.unpacked(pkd)? as CypherStructure val
    h.assert_eq[U8](value.signature, unpkd.signature)
    h.assert_eq[USize](value.field_count(), unpkd.field_count())
    h.assert_eq[U64](
      _PackStream.hashed_packed(value)?, _PackStream.hashed_packed(unpkd)?)

class iso _TestClientMessageInit is UnitTest
  fun name(): String =>
    "spooked/bolt/v1/serialization/messages/client/InitMessage"

  fun apply(h: TestHelper) ? =>
    let user_agent: String = "MyClient/1.0"
    let data = recover trn MapIs[CypherType val, CypherType val] end
    data("scheme") = "basic"
    data("principal") = "neo4j"
    data("credentials") = "secret"
    let auth_map = CypherMap(consume data)
    let pkd = InitMessage(user_agent, auth_map)?
    let pkd_string = _PackStream.h(pkd)
    let sub_seq_asserts = [
      "B2:01" // B2 structure marker, signature of 0x01
      "8C:4D:79:43:6C:69:65:6E:74:2F:31:2E:30" // 8C string marker, "MyClient/1.0"
      "86:73:63:68:65:6D:65:85:62:61:73:69:63" // "scheme" : "basic"
      "89:70:72:69:6E:63:69:70:61:6C:85:6E:65:6F:34:6A" // "principal" : "neo4j"
      "8B:63:72:65:64:65:6E:74:69:61:6C:73:86:73:65:63:72:65:74" // "credentials" : "secret"
    ]
    for sub_seq in sub_seq_asserts.values() do
      h.assert_true(pkd_string.contains(sub_seq))
    end

class iso _TestClientMessageRun is UnitTest
  fun name(): String =>
    "spooked/bolt/v1/serialization/messages/client/RunMessage"

  fun apply(h: TestHelper) ? =>
    let statement: String = "RETURN 1 AS num"
    let empty_map =
      recover val MapIs[CypherType val, CypherType val] end
    let parameters = CypherMap(consume empty_map)
    let pkd = RunMessage(statement, parameters)?
    // Works only due to empty param map
    h.assert_eq[String](
      "B2:10:8F:52:45:54:55:52:4E:20:31:20:41:53:20:6E:75:6D:A0",
      _PackStream.h(pkd))

class iso _TestClientMessageDiscardAll is UnitTest
  fun name(): String =>
    "spooked/bolt/v1/serialization/messages/client/DiscardAllMessage"

  fun apply(h: TestHelper) =>
    // Returns message already encoded
    let encoded = DiscardAllMessage()
    h.assert_eq[String](
      "B0:2F",
      _PackStream.h(encoded))

class iso _TestClientMessagePullAll is UnitTest
  fun name(): String =>
    "spooked/bolt/v1/serialization/messages/client/PullAllMessage"

  fun apply(h: TestHelper) =>
    // Returns message already encoded
    let encoded = PullAllMessage()
    h.assert_eq[String](
      "B0:3F",
      _PackStream.h(encoded))

class iso _TestClientMessageAckFailure is UnitTest
  fun name(): String =>
    "spooked/bolt/v1/serialization/messages/client/AckFailureMessage"

  fun apply(h: TestHelper) =>
    // Returns message already encoded
    let encoded = AckFailureMessage()
    h.assert_eq[String](
      "B0:0E",
      _PackStream.h(encoded))

class iso _TestClientMessageReset is UnitTest
  fun name(): String =>
    "spooked/bolt/v1/serialization/messages/client/ResetMessage"

  fun apply(h: TestHelper) =>
    // Returns message already encoded
    let encoded = ResetMessage()
    h.assert_eq[String](
      "B0:0F",
      _PackStream.h(encoded))

/*
_TestServerMessageRecord
_TestServerMessageSuccess
_TestServerMessageFailure
_TestServerMessageIgnored
*/
