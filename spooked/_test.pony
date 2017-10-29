use "collections"
use "itertools"
use "ponytest"

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

    // Test handshake
    test(_TestHandshakePreamble)
    test(_TestHandshakeClientBoltVersions)


class iso _TestPackStreamH is UnitTest
  fun name(): String => "PackStreamH"

  fun apply(h: TestHelper) =>
    h.assert_eq[String]("03:41:7E", _PackStream.h("\x03A~"))

class iso _TestPackStreamPackedNone is UnitTest
  fun name(): String => "PackStreamPackedNone"

  fun apply(h: TestHelper) ? =>
    h.assert_eq[String](
      "C0", // None
      _PackStream.h(
        _PackStream.packed([None])?))

class iso _TestPackStreamUnpackedNone is UnitTest
  fun name(): String => "PackStreamUnpackedNone"

  fun apply(h: TestHelper) ? =>
    var value = PackStreamNull
    var pkd = _PackStream.packed([value])?
    var unpkd = _PackStream.unpacked(pkd)? as PackStreamNull
    h.assert_eq[PackStreamNull](value, unpkd)

class iso _TestPackStreamPackedBoolean is UnitTest
  fun name(): String => "PackStreamPackedBoolean"

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
  fun name(): String => "PackStreamUnpackedBoolean"

  fun apply(h: TestHelper) ? =>
    for value in [
      false
      true
    ].values() do
      let pkd = _PackStream.packed([value])?
      let unpkd = _PackStream.unpacked(pkd)? as PackStreamBoolean
      h.assert_eq[PackStreamBoolean](value, unpkd)
    end

class iso _TestPackStreamPackedInteger is UnitTest
  fun name(): String => "PackStreamPackedInteger"

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
  fun name(): String => "PackStreamUnpackedInteger"

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
      let unpkd = _PackStream.unpacked(pkd)? as PackStreamInteger
      h.assert_eq[PackStreamInteger](value, unpkd)
    end

class iso _TestPackStreamPackedFloat is UnitTest
  fun name(): String => "PackStreamPackedFloat"

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
  fun name(): String => "PackStreamUnpackedFloat"

  fun apply(h: TestHelper) ? =>
    for value in [
      F64(1.1)
      F64(-1.1)
    ].values() do
      let pkd = _PackStream.packed([value])?
      let unpkd = _PackStream.unpacked(pkd)? as PackStreamFloat
      h.assert_eq[PackStreamFloat](value, unpkd)
    end

class iso _TestPackStreamPackedString is UnitTest
  fun name(): String => "PackStreamPackedString"

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
  fun name(): String => "PackStreamUnpackedString"

  fun apply(h: TestHelper) ? =>
    for value in [
      ""
      "A"
      "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
      "Größenmaßstäbe"
    ].values() do
      let pkd = _PackStream.packed([value])?
      let unpkd = _PackStream.unpacked(pkd)? as PackStreamString
      h.assert_eq[PackStreamString](value, unpkd)
    end

class iso _TestPackStreamPackedList is UnitTest
  fun name(): String => "PackStreamPackedList"

  fun apply(h: TestHelper) ? =>
    var list = PackStreamList
    // Empty list
    h.assert_eq[String](
      "90",
      _PackStream.h(
        _PackStream.packed([list])?))
    // [1, 2, 3]
    list.data
      .> push(I64(1))
      .> push(I64(2))
      .> push(I64(3))
    h.assert_eq[String](
      "93:01:02:03",
      _PackStream.h(
        _PackStream.packed([list])?))
    // [1, 2.0, "three"]
    list.data(1)? = F64(2.0)
    list.data(2)? = "three"
    h.assert_eq[String](
      "93:01:C1:40:00:00:00:00:00:00:00:85:74:68:72:65:65",
      _PackStream.h(
        _PackStream.packed([list])?))
    // [1, 2, 3 ... 40]
    list.data.clear()
    for i in Range(1, 41) do
      list.data.push(i.i64())
    end
    h.assert_eq[String](
      "D4:28:01:02:03:04:05:06:07:08:09:0A:0B:0C:0D:0E:0F:10:11:12:13:14:15:16:17:18:19:1A:1B:1C:1D:1E:1F:20:21:22:23:24:25:26:27:28",
      _PackStream.h(
        _PackStream.packed([list])?))

class iso _TestPackStreamUnpackedList is UnitTest
  fun name(): String => "PackStreamUnpackedList"

  fun apply(h: TestHelper) ? =>
    var value: PackStreamList
    var pkd: ByteSeq
    var unpkd: PackStreamList
    // Empty list
    value = PackStreamList.from_array([])
    pkd = _PackStream.packed([value])?
    unpkd = _PackStream.unpacked(pkd)? as PackStreamList
    h.assert_eq[U64](value._hashed_packed()?, unpkd._hashed_packed()?)
    // Homogeneous list
    value = PackStreamList.from_array([I64(1); I64(2); I64(3)])
    pkd = _PackStream.packed([value])?
    unpkd = _PackStream.unpacked(pkd)? as PackStreamList
    h.assert_eq[U64](value._hashed_packed()?, unpkd._hashed_packed()?)
    // Heterogeneous list
    value = PackStreamList.from_array([I64(1); F64(2.0); "three"])
    pkd = _PackStream.packed([value])?
    unpkd = _PackStream.unpacked(pkd)? as PackStreamList
    h.assert_eq[U64](value._hashed_packed()?, unpkd._hashed_packed()?)
    // Longer list
    let one_to_forty = Array[PackStreamType].create(40)
    Iter[I64](Range[I64](1, 41)).map_stateful[None]({(x) => one_to_forty.push(x)}).run()
    value = PackStreamList.from_array(one_to_forty)
    pkd = _PackStream.packed([value])?
    unpkd = _PackStream.unpacked(pkd)? as PackStreamList
    h.assert_eq[U64](value._hashed_packed()?, unpkd._hashed_packed()?)

class iso _TestPackStreamPackedMap is UnitTest
  fun name(): String => "PackStreamPackedMap"

  fun apply(h: TestHelper) ? =>
    var map = PackStreamMap
    // Empty map
    h.assert_eq[String](
      "A0",
      _PackStream.h(
        _PackStream.packed([map])?))
    // {"one": "eins"}
    map.data("one") = "eins"
    h.assert_eq[String](
      "A1:83:6F:6E:65:84:65:69:6E:73",
      _PackStream.h(
        _PackStream.packed([map])?))
    // {"A": 1, "B": 2, ... "Z": 26}
    map.data.clear()
    let alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    var pos: USize = 0
    for i in Range(0, 26) do
      pos = i + 1
      map.data(alphabet.trim(i, pos)) = pos.i64()
    end
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
  fun name(): String => "PackStreamUnpackedMap"

  fun apply(h: TestHelper) ? =>
    var map: PackStreamMap
    var pkd: ByteSeq
    var unpkd: PackStreamMap
    // Empty Map
    map = PackStreamMap
    pkd = _PackStream.packed([map])?
    unpkd = _PackStream.unpacked(pkd)? as PackStreamMap
    h.assert_eq[U64](map._hashed_packed()?, unpkd._hashed_packed()?)
    // {"one": "eins"}
    map.data("one") = "eins"
    pkd = _PackStream.packed([map])?
    unpkd = _PackStream.unpacked(pkd)? as PackStreamMap
    h.assert_eq[U64](map._hashed_packed()?, unpkd._hashed_packed()?)
    // {"A": 1, "B": 2, ... "Z": 26}
    map.data.clear()
    let alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    var pos: USize = 0
    for i in Range(0, 26) do
      pos = i + 1
      map.data(alphabet.trim(i, pos)) = pos.i64()
    end
    pkd = _PackStream.packed([map])?
    unpkd = _PackStream.unpacked(pkd)? as PackStreamMap
    // Cannot assert_eq _hashed_packed because map pairs are unordered...
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
          map'(letter)? as PackStreamInteger,
          unpkd'(letter)? as PackStreamInteger)
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
  fun name(): String => "PackStreamPackedStructure"

  fun apply(h: TestHelper) ? =>
    var structure: PackStreamStructure
    var signature: U8
    var fields = Array[PackStreamType]
    // Struct(sig=0x01, fields=[1,2,3])
    signature = 0x01
    fields
      .> push(I64(1))
      .> push(I64(2))
      .> push(I64(3))
    structure = PackStreamStructure(signature, fields)
    h.assert_eq[String](
      "B3:01:01:02:03",
      _PackStream.h(
        _PackStream.packed([structure])?))
    // Struct(sig=0x7F, fields=[1,2,3,4,5,6,7,8,9,0,1,2,3,4,5,6]
    structure.signature = 0x7F
    structure.fields
      .> push(I64(4)) .> push(I64(5)) .> push(I64(6)) .> push(I64(7))
      .> push(I64(8)) .> push(I64(9)) .> push(I64(0)) .> push(I64(1))
      .> push(I64(2)) .> push(I64(3)) .> push(I64(4)) .> push(I64(5))
      .> push(I64(6))
    h.assert_eq[String](
      "DC:10:7F:01:02:03:04:05:06:07:08:09:00:01:02:03:04:05:06",
      _PackStream.h(
        _PackStream.packed([structure])?))

class iso _TestPackStreamUnpackedStructure is UnitTest
  fun name(): String => "PackStreamUnpackedStructure"

  fun apply(h: TestHelper) ? =>
    var value: PackStreamStructure
    var pkd: ByteSeq
    var unpkd: PackStreamStructure
    // Struct(sig=0x01, fields=[1,2,3])
    value = PackStreamStructure(0x01, [I64(1); I64(2); I64(3)])
    pkd = _PackStream.packed([value])?
    unpkd = _PackStream.unpacked(pkd)? as PackStreamStructure
    h.assert_eq[U8](value.signature, unpkd.signature)
    h.assert_eq[USize](value.fields.size(), unpkd.fields.size())
    h.assert_eq[U64](value._hashed_packed()?, unpkd._hashed_packed()?)
    // Struct(sig=0x7F, fields=[1,2,3,4,5,6,7,8,9,0,1,2,3,4,5,6]
    value.signature = 0x7f
    value.fields
      .> push(I64(4)) .> push(I64(5)) .> push(I64(6)) .> push(I64(7))
      .> push(I64(8)) .> push(I64(9)) .> push(I64(0)) .> push(I64(1))
      .> push(I64(2)) .> push(I64(3)) .> push(I64(4)) .> push(I64(5))
      .> push(I64(6))
    pkd = _PackStream.packed([value])?
    unpkd = _PackStream.unpacked(pkd)? as PackStreamStructure
    h.assert_eq[U8](value.signature, unpkd.signature)
    h.assert_eq[USize](value.fields.size(), unpkd.fields.size())
    h.assert_eq[U64](value._hashed_packed()?, unpkd._hashed_packed()?)

class iso _TestHandshakePreamble is UnitTest
  fun name(): String => "HandshakePreamble"

  fun apply(h: TestHelper) =>
    h.assert_eq[String](
      "60:60:B0:17",
      _PackStream.h(Handshake()))

class iso _TestHandshakeClientBoltVersions is UnitTest
  fun name(): String => "HandshakeClientBoltVersions"

  fun apply(h: TestHelper) =>
    h.assert_eq[String](
      "00:00:00:01:00:00:00:00:00:00:00:00:00:00:00:00",
      _PackStream.h(ClientBoltVersions()))
    h.assert_eq[String](
      "00:00:00:04:00:00:00:03:00:00:00:02:00:00:00:01",
      _PackStream.h(ClientBoltVersions(4, 3, 2, 1)))
