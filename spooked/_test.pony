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

    // TODO: Refactor to use SessionNotify.success for RUN
    //                       SessionNotify.summary for Results

    test(_TestSessionBasic)
    test(_TestSessionPipelined)
    test(_TestSessionReset)
    test(_TestSessionFailure)
    test(_TestSessionIgnored)

    test(_TestSessionResultsStreamed)
    // test(_TestSessionResultsBuffered)
    // test(_TestSessionResultsDiscarded)


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

primitive StatementReturn1AsNum
  fun template(): String val => "RETURN 1 AS num"

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
            session.run(StatementReturn1AsNum)

          fun ref result(
            session: Session ref,
            statement: CypherStatement val,
            fields: CypherList val,
            data: CypherList val)
          =>
            try
              _h.assert_is[CypherStatement val](
                StatementReturn1AsNum, statement)
              _h.assert_eq[String]("num", fields.data(0)? as CypherString val)
              _h.assert_eq[I64](I64(1), data.data(0)? as CypherInteger)
            end

          fun ref summary(
            session: Session ref,
            statement: CypherStatement val,
            meta: CypherMap val)
          =>
            try
              _h.assert_eq[String]("r", meta.data("type")? as CypherString val)
            end
            _h.complete(true)

        end)
    else
      h.fail()
    end

primitive StatementReturn1AsOne
  fun template(): String val => "RETURN 1 AS one"

primitive StatementReturn2AsTwo
  fun template(): String val => "RETURN 2 AS two"

class iso _TestSessionPipelined is UnitTest
  fun name(): String =>
    "spooked/session/pipelined"

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
          var _summary_count: USize = 0

          fun ref apply(session: Session ref) =>
            session.run(StatementReturn1AsOne)
            session.run(StatementReturn2AsTwo)

          fun ref result(
            session: Session ref,
            statement: CypherStatement val,
            fields: CypherList val,
            data: CypherList val)
          =>
            try
              match statement
              | StatementReturn1AsOne =>
                _h.assert_eq[String]("one", fields.data(0)? as CypherString val)
                _h.assert_eq[I64](I64(1), data.data(0)? as CypherInteger)
              | StatementReturn2AsTwo =>
                _h.assert_eq[String]("two", fields.data(0)? as CypherString val)
                _h.assert_eq[I64](I64(2), data.data(0)? as CypherInteger)
              else
                _h.fail()
              end
            end

          fun ref summary(
            session: Session ref,
            statement: CypherStatement val,
            meta: CypherMap val)
          =>
            try
              _h.assert_eq[String]("r", meta.data("type")? as CypherString val)
              _summary_count = _summary_count + 1
            end
            if _summary_count == 2 then
              _h.complete(true)
            end

        end)
    else
      h.fail()
    end

class iso _TestSessionReset is UnitTest
  fun name(): String =>
    "spooked/session/reset"

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
            session.reset()

          fun ref reset(session: Session ref) =>
            _h.complete(true)

        end)
    else
      h.fail()
    end

primitive StatementWithSyntaxError
  fun template(): String val => "This will cause a syntax error"

class iso _TestSessionFailure is UnitTest
  fun name(): String =>
    "spooked/session/failure"

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
            session.run(StatementWithSyntaxError)

          fun ref failure(
            session: Session ref,
            statement: CypherStatement val,
            meta: CypherMap val)
          =>
            try
              _h.assert_is[CypherStatement val](
                StatementWithSyntaxError, statement)
              _h.assert_eq[String](
                "Neo.ClientError.Statement.SyntaxError",
                meta.data("code")? as CypherString val)
            end
            _h.complete(true)

        end)
    else
      h.fail()
    end

class iso _TestSessionIgnored is UnitTest
  fun name(): String =>
    "spooked/session/ignored"

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
            session.run(StatementWithSyntaxError)
            session.run(StatementReturn1AsNum) // To be ignored

          fun ref failure(
            session: Session ref,
            statement: CypherStatement val,
            meta: CypherMap val)
          =>
            try
              _h.assert_is[CypherStatement val](
                StatementWithSyntaxError, statement)
              _h.assert_eq[String](
                "Neo.ClientError.Statement.SyntaxError",
                meta.data("code")? as CypherString val)
            end

          fun ref ignored(
            session: Session ref,
            statement: CypherStatement val,
            meta: CypherMap val)
          =>
            _h.assert_is[CypherStatement val](
              StatementReturn1AsNum, statement)
            _h.complete(true)

        end)
    else
      h.fail()
    end

primitive StatementReturn1Through5AsNum
  fun template(): String val => "UNWIND [1, 2, 3, 4, 5] AS num RETURN num"

class iso _TestSessionResultsStreamed is UnitTest
  fun name(): String =>
    "spooked/session/results-streamed"

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
          var _result_count: USize = 0

          fun ref apply(session: Session ref) =>
            session.run(StatementReturn1Through5AsNum)

          /*
          fun ref summary(
            session: Session ref,
            statement: CypherStatement val,
            meta: CypherMap val)
          =>
          */

          fun ref result(
            session: Session ref,
            statement: CypherStatement val,
            fields: CypherList val,
            data: CypherList val)
          =>
            _result_count = _result_count + 1
            try
              _h.assert_is[CypherStatement val](
                StatementReturn1Through5AsNum, statement)
              _h.assert_eq[String]("num", fields.data(0)? as CypherString val)
              _h.assert_eq[I64](
                // I64.from[USize](_result_count),
                _result_count.i64(),
                data.data(0)? as CypherInteger)
            end

          fun ref summary(
            session: Session ref,
            statement: CypherStatement val,
            meta: CypherMap val)
          =>
            try
              // if meta.data.contains("type") then
                // Received results summary
                _h.assert_eq[String](
                  "r", meta.data("type")? as CypherString val)
                _h.assert_eq[USize](5, _result_count)
                _h.complete(true)
              // end
            end

        end)
    else
      h.fail()
    end

// TODO
  // class iso _TestSessionResultsBuffered is UnitTest
  // class iso _TestSessionResultsDiscarded is UnitTest


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
