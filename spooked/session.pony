use "logger"
use "net"

primitive Streamed
primitive Buffered
primitive Discarded

type ReturnedResults is
  ( Streamed
  | Buffered
  | Discarded
  )


interface SessionNotify
  """ Notifications for Neo4j Bolt Sessions """
  // TODO: [SessionNotify]
  fun ref apply(session: Session ref): None
    """"""

  fun ref result(
    session: Session ref,
    fields: CypherList val,
    data: CypherList val)
  =>
    """"""
    None

  fun ref results(
    session: Session ref,
    fields: CypherList val,
    data: Array[CypherList val] val)
  =>
    """"""
    None

  fun ref summary(session: Session ref, meta: CypherMap val) =>
    """"""
    None

  fun ref failure(session: Session ref, meta: CypherMap val) =>
    """"""
    None

  fun ref reset(session: Session ref) =>
    """"""
    None

  fun ref closed() =>
    """"""
    None

  // service_unavailable

  // Internally Used
  fun ref _handshook(session: Session ref) => None
  fun ref _initialized(session: Session ref) => None


// TODO: [Session] Logging
actor Session
  let _driver: Driver tag
  let _notify: SessionNotify
  let _connection_pool: _BoltConnectionPool tag
  var _connection: (BoltConnection tag | None) = None
  var _release_on_reset: Bool = false
  let _logger: Logger[String] val

  new _create(
    driver: Driver tag,
    notify: SessionNotify iso,
    connection_pool: _BoltConnectionPool tag,
    logger: Logger[String] val)
  =>
    """"""
    _driver = driver
    _notify = consume notify
    _connection_pool = connection_pool
    _logger = logger

    // TODO: [Session] Set timeout waiting for a connection. If time out then
    //    call _notify.service_unavailable?
    _connection_pool.acquire(this)

  be _retry_acquire() =>
    """ The connection acquired from the pool was closed. Retry.  """
    _connection_pool.acquire(this)

  be _receive_connection(
    connection: BoltConnection tag,
    go_ahead: Bool)
  =>
    """ Receive a connection to the server & whether session can proceed. """
    _connection = connection
    if go_ahead then
      _go_ahead()
    end

  be _handshook() =>
    _notify._handshook(this)

  be _initialized() =>
    _notify._initialized(this)

  be _go_ahead() =>
    """ Proceed with the work this session should perform. """
    _notify(this)
    _flush()

  fun _flush() =>
    """ Ask the connection to send all pipelined requests. """
    match _connection
    | let c: BoltConnection tag =>
      c._flush()
    end

  fun run(
    statement: String val,
    parameters: CypherMap val = CypherMap.empty(),
    results_as: ReturnedResults = Streamed)
  =>
    """
    Pass a templated Cypher statement and its parameters along for execution on
    the server. Specify whether results are `Streamed` one by one (default),
    `Buffered` and returned as a whole, or `Discarded`.
    """
    match _connection
    | let c: BoltConnection tag =>
      c._run(statement, parameters, results_as)
    end

  be _receive_streamed_result(
    fields: CypherList val,
    result: CypherList val)
  =>
    _notify.result(this, fields, result)

  be _receive_buffered_results(
    fields: CypherList val,
    results: Array[CypherList val] val)
  =>
    _notify.results(this, fields, results)

  be _success(metadata: CypherMap val) =>
    _notify.summary(this, metadata)

  // fun begin_transaction()
  // fun read_transaction()
  // fun write_transaction()

  // TODO: [Session] reset: Maybe NOT expose publicly on session?
  //    Though, may be useful for retries, action after errors..
  // be reset() =>
  fun reset() =>
    """ Reset the session. """
    match _connection
    | let c: BoltConnection tag =>
      c.reset()
    end

  be _successfully_reset(connection: BoltConnection tag) =>
    if _release_on_reset then
      _notify.closed() // Session was disposed of.
      _connection_pool.release(connection)
      // _connection = None
    else
      _notify.reset(this)
    end

  be _failed_reset(connection: BoltConnection tag, meta: CypherMap val) =>
    """"""
    // TODO: [Session] _failed_reset
    //    ProtocolError?, close session? Does server close?

  // TODO: [Session] _error
  be _error(err: _BoltConnectionError, data: (CypherMap val | None) = None) =>
    """"""
    // Probably reset/dispose dep on error.
    // Especially dispose on ProtocolError
    match err
    | InitializationError => None
    end

  be _closed() =>
    """ The connection used by the session has closed. Close the session. """
    _notify.closed()
    _connection = None
    _driver._end_session(this)

  be dispose(release_connection: Bool = true) =>
    """
    Dispose of this session. Attempt to return the connection back to the
    pool if successfully reset.
    """
      match _connection
      | let c: BoltConnection tag =>
        if release_connection then
          c.reset()
          _release_on_reset = true
        else
          c.dispose()
        end
      end
    _connection = None
    _driver._end_session(this)
