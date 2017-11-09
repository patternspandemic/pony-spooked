use "ponytest"
use "logger"
use "net"
use bolt_v1 = "./bolt_v1"

actor Main is TestList
  new create(env: Env) =>
    PonyTest(env, this)

  new make() =>
    None

  fun tag tests(test: PonyTest) =>
    bolt_v1.Main.make().tests(test)

    test(_Handshook)

    // TODO: Redo Test handshake, etc
    // test(_TestHandshakePreamble)
    // test(_TestHandshakeClientBoltVersions)


class iso _Handshook is UnitTest
  fun name(): String => "Handshook"
  fun label(): String => "Handshook"

  fun apply(h: TestHelper) =>
    try
      let driver = Neo4j.driver(
        "bolt://localhost:7687/",
        ConnectionSettings("spooked", "spooked"),
        NetAuth(h.env.root as AmbientAuth),
        StringLogger(Info, TestHelperLogStream(h)))?

      h.long_test(5_000_000_000)
      h.dispose_when_done(driver)
      driver.session(_BasicSessionNotify(h))
    else
      h.fail()
    end

class _BasicSessionNotify is SessionNotify
  let _h: TestHelper

  new iso create(h: TestHelper) =>
    _h = h

  fun ref apply(session: Session tag) =>
    _h.complete(true)

actor TestHelperLogStream is OutStream
  let _h: TestHelper

  new create(h: TestHelper) =>
    _h = h

  be print(data: ByteSeq) =>
    _h.log(_data_to_string(data))

  be write(data: ByteSeq) =>
    _h.log(_data_to_string(data))

  be printv(data: ByteSeqIter) =>
    for bytes in data.values() do
      _h.log(_data_to_string(bytes))
    end

  be writev(data: ByteSeqIter) =>
    for bytes in data.values() do
      _h.log(_data_to_string(bytes))
    end

  fun _data_to_string(data: ByteSeq): String val =>
    match data
    | let s: String val => s
    | let bytes: Array[U8 val] val => String.from_array(bytes)
    end

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