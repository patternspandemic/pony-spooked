use "collections"
use "logger"
use "net"
use "net/ssl"

use "./bolt_v1"

primitive ServiceUnavailable
primitive UnsupportedProtocolVersion
primitive ProtocolError
primitive InitializationError
// primitive SessionExpired

type _BoltConnectionError is
  ( ServiceUnavailable
  | UnsupportedProtocolVersion
  | ProtocolError
  | InitializationError
  // | SessionExpired
  )


actor _BoltConnectionPool
  let _logger: Logger[String] val
  let _net_auth: NetAuth val
  let _config: Configuration val
  let _host: String val
  let _port: String val
  let _connections: Array[BoltConnection tag]
  var _drained: Bool = false

  new create(
    host: String val,
    port: U16 val,
    config: Configuration val,
    net_auth: NetAuth val,
    logger: Logger[String] val)
  =>
    _logger = logger
    _net_auth = net_auth
    _config = config
    _host = host
    _port = port.string()
    _connections = Array[BoltConnection tag].create()

  be acquire(session: Session tag) =>
    """Send a BoltConnection to session."""
    try
      // Shift a connection off the pool, setting on it the acquiring session.
      // The connection will send itself to the session if it's still alive. On
      // the chance the connection was closed while in the pool, it will tell
      // the session to retry acquiring a connection.
      let connection: BoltConnection tag = _connections.shift()?
      connection._set_session(session)
    else
      // The pool is empty, send a new connection directly to the session.
      let connection: BoltConnection tag =
        BoltConnection(session, _host, _port, _config, _net_auth, _logger)
      session._receive_connection(connection, false)
    end

  be release(connection: BoltConnection tag) =>
    """Accept the released reset connection back into the pool."""
    connection._clear_session()
    if not _drained then
      if not _connections.contains(connection) then
        _connections.push(connection)
      end
    else
      connection.dispose()
    end

  be dispose() =>
    """"""
    for connection in _connections.values() do
      connection.dispose()
    end
    _connections.clear()
    _drained = true


// class BoltConnection
actor BoltConnection
  let _logger: Logger[String] val
  let _net_auth: NetAuth val
  let _config: Configuration val
  let _host: String val
  let _port: String val
  // var _ssl_context: (SSLContext | None) = None
  var _conn: (TCPConnection | None) = None
  var _bolt_messenger: (BoltMessenger tag | None) = None
  var _session: (Session tag | None) = None

  // new iso create(
  new create(
    session: Session tag,
    host: String val,
    port: String val,
    config: Configuration val,
    net_auth: NetAuth val,
    logger: Logger[String] val)
  =>
    _logger = logger
    _net_auth = net_auth
    _config = config
    _session = session
    _host = host
    _port = port
    _conn =
      TCPConnection(
        _net_auth,
        _Handshake(this, _logger),
        _host, _port)

  be _connect_failed() =>
    match _session
    | let s: Session tag => s._error(ServiceUnavailable)
    end

  // fun _auth_failed() =>
  //   match _session
  //   | let s: Session tag => s._auth_failed()
  //   end

  // Must be public for sub-package access.
  be protocol_error() =>
    match _session
    | let s: Session tag => s._error(ProtocolError)
    end

  be _version_negotiation_failed() =>
    // TODO: [BoltConnection] Cleanup? Server closes connection,
    //    Likely will get callback to _closed
    match _session
    | let s: Session tag => s._error(UnsupportedProtocolVersion)
    end
/*
  be _unsupported_version(unsupported_version: U32) =>
    // TODO: [BoltConnection] Likely shouldn't happen, but need to close down
    //    as server won't close connection in this case. Call manually.
    match _session
    | let s: Session tag => s._error(ProtocolError)
    end
*/
  be _handshook(version: U32) =>
    // TODO: [BoltConnection] Change TCP notify based on version
    //    - Use a better version to BoltConnectionNotify mapping
    //    - Setup _conn details from config?
    match _conn
    | let c: TCPConnection =>
      let bolt_messenger = BoltV1Messenger(this, c, _logger)
      c.set_notify(BoltV1ConnectionNotify(this, bolt_messenger, _logger))
      bolt_messenger.init(_config)
      _bolt_messenger = bolt_messenger
    end
    match _session
    | let s: Session tag => s._handshook()
    end

  // Must be public for sub-package access.
  be successfully_init() =>
    // TODO: Utilize success metadata?
    match _session
    | let s: Session tag => s._go_ahead()
    end

  // Must be public for sub-package access.
  be failed_init(data: CypherMap val) =>
    match _session
    | let s: Session tag => s._error(InitializationError, data)
    end

  be _run(
    statement: String val,
    parameters: CypherMap val)
  =>
    // TODO: [BoltConnection] _run()
    match _bolt_messenger
    | let messenger: BoltMessenger tag =>
      // messenger.add_statement(...)
      None // tmp
    end

  // TODO: [BoltConnection] Make flush() private?
  be flush() =>
    match _bolt_messenger
    | let m: BoltMessenger tag => m.flush()
    end

  // Must be public for sub-package access.
  be closed() =>
    match _session
    | let s: Session tag => s._closed()
    end
    _session = None
    _bolt_messenger = None
    _conn = None

  be _set_session(session: Session) =>
    if _session is None then
      if _conn is None then
        // Server closed on this pooled BoltConnection.
        session._retry_acquire()
      else
        // Accept the session and send this BoltConnection
        // to it signalling to go ahead.
        session._receive_connection(this, true)
        _session = session
      end
    end

  be _clear_session() =>
    _session = None

  // TODO: [BoltConnection] Make reset() private?
  be reset() =>
    match _bolt_messenger
    | let m: BoltMessenger tag => m.reset()
    end

  // Must be public for sub-package access.
  be successfully_reset() =>
    match _session
    | let s: Session tag => s._successfully_reset(this)
    end

  // Must be public for sub-package access.
  be failed_reset() =>
    match _session
    | let s: Session tag => s._failed_reset(this)
    end

  // TODO: [BoltConnection] Make dispose() private?
  be dispose() =>
    match _conn
    | let c: TCPConnection => c.dispose()
    end


interface BoltMessenger
  """
  """
  be init(config: Configuration val)
    """Initialize the Bolt connection."""
  be add_statement(statement: String val, parameters: CypherMap val)
    """Add a Cypher statement to be run by the server."""
  be flush()
    """Send all pipelined messages through the connection."""
  be reset()
    """Reset the Bolt connection."""
