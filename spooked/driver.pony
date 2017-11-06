use "logger"
use "net"

// TODO: [Driver] Logging

actor Driver
  """
  Client applications that wish to interact with a Neo4j database will require
  an actor of type `Driver`. Drivers maintain connections to a single database
  server or cluster core server, and generate Sessions, through which Cypher
  statements and their results are communicated through the underlying 
  connection using the notifier object pattern.

  For details on obtaining a `Driver` see the `Neo4j` primitive.

  As an actor, the driver can be made available to any part of the applications
  that requires interaction with the database.
  """
  let _logger: Logger[String] val
  let _connection_pool: ConnectionPool tag
  let _open_sessions: Array[Session tag]

  new create(
    host: String val,
    port: U16 val,
    connection_settings': ConnectionSettings val,
    net_auth: NetAuth val,
    logger: Logger[String] val)
  =>
    """
    """
    _logger = logger

    if port == 0 then
      port = 7687 // default bolt port
    end

    _connection_pool =
      ConnectionPool(
        host,
        port,
        connection_settings,
        net_auth,
        logger)

  be session(notify: SessionNotify iso) =>
    """
    Generate a Session, passing it the SessionNotify object which encapsulates
    the logic required to perform the client's interaction with the database.
    """
    let session = Session(consume notify, _connection_pool, logger)
    _open_sessions.push(session)

  be close() =>
    """
    Close all open Sessions and cached active Connections.
    """
    for session in _open_sessions.values() do
      // Close the Session, release back to pool.
      session.close()
    end
    // Empty pool of cached Connections.
    _connection_pool.close()
