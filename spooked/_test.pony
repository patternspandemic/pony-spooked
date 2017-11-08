use "ponytest"
use bolt_v1 = "./bolt_v1"

actor Main is TestList
  new create(env: Env) =>
    PonyTest(env, this)

  new make() =>
    None

  fun tag tests(test: PonyTest) =>
    bolt_v1.Main.make().tests(test)

    // test(_BasicIntegration)

    // TODO: Redo Test handshake, etc
    // test(_TestHandshakePreamble)
    // test(_TestHandshakeClientBoltVersions)

/*
class iso _BasicIntegration is UnitTest
  fun name(): String => "BasicIntegration"

  fun apply(h: TestHelper) =>
    h.long_test(5_000_000_000)

    h.dispose_when_done the driver
    h.expect_action
      h.complete_action
      h.fail_action
*/

/*
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
*/