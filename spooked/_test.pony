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

    test(_TestSessionBasic)


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
          fun ref apply(session: Session ref) => None
          fun ref _initialized(session: Session ref) =>
            _h.complete(true)
        end)
    else
      h.fail()
    end

class iso _TestSessionBasic is UnitTest
  fun name(): String =>
    "spooked/session/basic"

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
            session.run("RETURN 1 AS num")

          fun ref result(
            session: Session ref,
            fields: CypherList val,
            data: CypherList val)
          =>
            try
              _h.assert_eq[String]("num", fields.data(0)? as CypherString val)
              _h.assert_eq[I64](I64(1), data.data(0)? as CypherInteger)
            end

          fun ref summary(session: Session ref, meta: CypherMap val) =>
            try
              _h.assert_eq[String]("r", meta.data("type")? as CypherString val)
            end
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
