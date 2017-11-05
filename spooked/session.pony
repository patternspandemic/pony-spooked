use "logger"
use "net"

// TODO: [Session] Logging

interface SessionNotify
  """Notifications for Neo4j Bolt Sessions"""
  // TODO: [SessionNotify]


actor Session
  let _notify: SessionNotify
  let _connection_pool: ConnectionPool
  let _connection: Connection
  let _logger: Logger[String] val

  new create(
    notify: SessionNotify iso,
    connection_pool: ConnectionPool,
    logger: Logger[String] val)
  =>
    """
    """
    _notify = consume notify
    _connection_pool = connection_pool
    _logger = logger

    _connection = _connection_pool.acquire()

  // TODO: [Session]