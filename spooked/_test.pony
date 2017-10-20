use "ponytest"

actor Main is TestList
  new create(env: Env) =>
    PonyTest(env, this)

  new make() =>
    None

  fun tag tests(test: PonyTest) =>
    test(_TestPackStreamH)
    test(_TestPackStreamPackedNone)
    test(_TestPackStreamPackedBoolean)
    test(_TestPackStreamPackedInteger)
    test(_TestPackStreamPackedFloat)
    test(_TestPackStreamPackedString)


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
