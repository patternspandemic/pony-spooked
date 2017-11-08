use "logger"
use "net"

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
  let _connection_pool: _ConnectionPool tag
  let _open_sessions: Array[Session tag]

  new _create(
    scheme: String val,
    host: String val,
    port: U16 val,
    config: _Configuration val,
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
      _ConnectionPool(
        host,
        port,
        config,
        net_auth,
        logger)

    _logger(Info) and _logger.log(
      "[Spooked] Info: Neo4j " + scheme + "Driver created for " +
      host + ":" + port.string())

  be session(notify: SessionNotify iso) =>
    """
    Generate a Session, passing it the SessionNotify object which encapsulates
    the logic required to perform the client's interaction with the database.
    """
    let session_description = notify.description()
    _logger(Info) and _logger.log(
      "[Spooked] Info: Generating session - " + session_description)

    let session = Session._create(consume notify, _connection_pool, logger)
    _open_sessions.push(session)

  be close() =>
    """
    Close all open Sessions and cached active Connections.
    """
    _logger(Info) and _logger.log(
      "[Spooked] Info: Closing all open Sessions and cached Connections.")

    // Close all open Sessions, releasing each back to pool.
    for session in _open_sessions.values() do
      session.close()
    end

    // Empty pool of cached Connections.
    _connection_pool.close()
