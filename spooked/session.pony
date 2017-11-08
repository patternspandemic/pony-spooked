use "logger"
use "net"

// TODO: [Session] Logging

interface SessionNotify
  """Notifications for Neo4j Bolt Sessions"""
  // TODO: [SessionNotify]
  //    apply
  //    service_unavailable
  //    

actor Session
  let _driver: Driver tag
  let _notify: SessionNotify
  let _connection_pool: _ConnectionPool tag
  var _connection: (_Connection iso | None) = None
  let _logger: Logger[String] val

  new _create(
    driver: Driver tag,
    notify: SessionNotify iso,
    connection_pool: _ConnectionPool tag,
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
    connection: _Connection iso,
    go_ahead: Bool)
  =>
    _connection = consume connection
    if go_ahead then
      _go_ahead()
    end

  be _go_ahead() =>
    _notify(this)

  // fun ref run()

  // fun ref begin_transaction()
  // fun ref read_transaction()
  // fun ref write_transaction()

  // be reset()

  be _error(err: _ConnectionError) =>
    // match err
    // | ...
    // end

  be _closed() =>
    _connection = None
    _driver.end_session(this)

  // be close()
