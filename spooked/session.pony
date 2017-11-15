use "logger"
use "net"

// TODO: [Session] Logging

interface SessionNotify
  """Notifications for Neo4j Bolt Sessions"""
  // TODO: [SessionNotify]

  fun ref apply(session: Session tag): None

  //    apply
  //    service_unavailable
  //    

actor Session
  let _driver: Driver tag
  let _notify: SessionNotify
  let _connection_pool: _BoltConnectionPool tag
  var _connection: (BoltConnection tag /*iso*/ | None) = None
  var _release_on_reset: Bool = false
  let _logger: Logger[String] val

  new _create(
    driver: Driver tag,
    notify: SessionNotify iso,
    connection_pool: _BoltConnectionPool tag,
    logger: Logger[String] val)
  =>
    """
    """
    _driver = driver
    _notify = consume notify
    _connection_pool = connection_pool
    _logger = logger

    // TODO: [Session] Set timeout waiting for a connection. If time out then
    //    call _notify.service_unavailable?
    _connection_pool.acquire(this)

  be _receive_connection(
    // connection: BoltConnection iso,
    connection: BoltConnection tag,
    go_ahead: Bool)
  =>
    // _connection = consume connection
    _connection = connection
    if go_ahead then
      _go_ahead()
    end

  be _go_ahead() =>
    _notify(this)
    match _connection
    | let c: BoltConnection tag =>
      c.flush()
    end

  be run(
    statement: String val,
    parameters: CypherMap val = CypherMap.empty())
  =>
    """Pass a Cypher statement for execution on the server."""
    match _connection
    | let c: BoltConnection tag =>
      c._run(statement, parameters)
    end

  // fun ref begin_transaction()
  // fun ref read_transaction()
  // fun ref write_transaction()

  // TODO: [Session] _error
  be _error(err: _BoltConnectionError) =>
    """"""
    // Probably reset/dispose dep on error.
    // match err
    // | ...
    // end

  be _closed() =>
    _connection = None
    _driver._end_session(this)

  be reset() =>
    match _connection
    | let c: BoltConnection tag =>
      c.reset()
    end

  be _successfully_reset(connection: BoltConnection tag) =>
    if _release_on_reset then
      _connection_pool.release(connection)
    end

  be dispose() =>
    """"""
    // TODO: [Session] dispose
    match _connection
    | let c: BoltConnection tag =>
      c.reset()
      _release_on_reset = true
      _connection = None
    end
    _driver._end_session(this)
