use "ponytest"

actor Main is TestList
  new create(env: Env) =>
    PonyTest(env, this)

  new make() =>
    None

  fun tag tests(test: PonyTest) =>
    test(_TestPackStreamH)


class iso _TestPackStreamH is UnitTest
  fun name(): String => "_PackStreamH"

  fun apply(h: TestHelper) =>
    h.assert_eq[String]("03:41:7E", _PackStream.h("\x03A~"))
