use "logger"
use "net"

// TODO: [Session] Logging

interface SessionNotify
  """Notifications for Neo4j Bolt Sessions"""
  // TODO: [SessionNotify]
  //    Make session param ref?

  fun ref apply(session: Session ref /*tag*/): None
  fun ref closed(session: Session ref /*tag*/) => None
  // service_unavailable

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

  be _go_ahead() =>
    """ Proceed with the work this session should perform. """
    _notify(this)
    _flush()

  fun _flush() =>
    """ Ask the connection to send all pipelined requests. """
    match _connection
    | let c: BoltConnection tag =>
      c.flush()
    end

  // be run(
  fun run(
    statement: String val,
    parameters: CypherMap val = CypherMap.empty())
  =>
    """ Pass a Cypher statement for execution on the server. """
    match _connection
    | let c: BoltConnection tag =>
      c._run(statement, parameters)
    end

  // fun/be begin_transaction()
  // fun/be read_transaction()
  // fun/be write_transaction()

  // TODO: [Session] _error
  be _error(err: _BoltConnectionError) =>
    """"""
    // Probably reset/dispose dep on error.
    // match err
    // | ...
    // end

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
      _connection_pool.release(connection)
      _connection = None
      // _connection_pool = None
    end

  be _closed() =>
    """ The connection used by the session has closed. Close the session. """
    _notify.closed(this)
    _connection = None
    // _connection_pool = None
    _driver._end_session(this)
    // _driver = None

  be dispose() =>
    """
    Dispose of this session. Attempt to return the connection back to the
    pool if successfully reset.
    """
    match _connection
    | let c: BoltConnection tag =>
      c.reset()
      _release_on_reset = true
    end
    _driver._end_session(this)
    // _driver = None
