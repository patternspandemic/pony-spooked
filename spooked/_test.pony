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

    test(_TestConnectionHandshakeSuccess)
    test(_TestConnectionINITSuccess)


class iso _TestConnectionHandshakeSuccess is UnitTest
  fun name(): String =>
    "spooked/connection/handshake/success"

  fun apply(h: TestHelper) =>
    try
      let driver = Neo4j.driver(
        "bolt://localhost/",
        ConnectionSettings("spooked", "spooked"),
        NetAuth(h.env.root as AmbientAuth),
        StringLogger(Info, TestHelperLogStream(h)))?

      h.long_test(2_000_000_000)
      h.dispose_when_done(driver)

      driver.session(
        object iso is SessionNotify
          let _h: TestHelper = h
          fun ref apply(session: Session ref) => None
          fun ref _handshook(session: Session ref) =>
            _h.complete(true)
        end)
    else
      h.fail()
    end

class iso _TestConnectionINITSuccess is UnitTest
  fun name(): String =>
    "spooked/connection/init/success"

  fun apply(h: TestHelper) =>
    try
      let driver = Neo4j.driver(
        "bolt://localhost/",
        ConnectionSettings("spooked", "spooked"),
        NetAuth(h.env.root as AmbientAuth),
        StringLogger(Info, TestHelperLogStream(h)))?

      h.long_test(2_000_000_000)
      h.dispose_when_done(driver)

      driver.session(
        object iso is SessionNotify
          let _h: TestHelper = h
          fun ref apply(session: Session ref) =>
            _h.complete(true)
        end)
    else
      h.fail()
    end


actor TestHelperLogStream is OutStream
  """Helper actor for passing library's logging onto TestHelper's logging."""
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
