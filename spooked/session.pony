use "logger"
use "net"

// TODO: [Session] Logging

interface SessionNotify
  """Notifications for Neo4j Bolt Sessions"""
  // TODO: [SessionNotify]


actor Session
  let _notify: SessionNotify
  let _connection_pool: _ConnectionPool tag
  let _connection: (_Connection iso | None) = None
  let _logger: Logger[String] val

  new _create(
    notify: SessionNotify iso,
    connection_pool: _ConnectionPool tag,
    logger: Logger[String] val)
  =>
    """
    """
    _notify = consume notify
    _connection_pool = connection_pool
    _logger = logger

    _connection_pool.acquire(this)

  // TODO: [Session]

  be _receive_connection(connection: _Connection iso) =>
    _connection = consume connection
    _notify(this)

  // fun ref run()

  // fun ref begin_transaction()
  // fun ref read_transaction()
  // fun ref write_transaction()

  // be reset()
  // be close()
