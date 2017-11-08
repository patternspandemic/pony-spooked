use "collections"
use "logger"
use "net"
use "net/ssl"

primitive ServiceUnavailable
primitive SessionExpired
primitive ProtocolError
primitive UnsupportedProtocolVersion

type _ConnectionError is
  ( ServiceUnavailable
  | SessionExpired
  | ProtocolError
  | UnsupportedProtocolVersion
  )


actor _ConnectionPool
  let _logger: Logger[String] val
  let _net_auth: NetAuth val
  let _config: _Configuration val
  let _host: String val
  let _port: String val
  // let _connections: Array[_Connection iso]
  let _connections: Array[_Connection tag]

  new create(
    host: String val,
    port: U16 val,
    config: _Configuration val,
    net_auth: NetAuth val,
    logger: Logger[String] val)
  =>
    _logger = logger
    _net_auth = net_auth
    _config = config
    _host = host
    _port = port.string()
    // _connections = Array[_Connection iso].create()
    _connections = Array[_Connection tag].create()

  be acquire(session: Session tag) =>
    """Send a _Connection to session."""
    try
      // let connection: _Connection iso = _connections.shift()?
      let connection: _Connection tag = _connections.shift()?
      connection._set_session(session)
      session._receive_connection(/*consume*/ connection, true)
    else
      let connection: _Connection tag = //iso =
        _Connection(session, _host, _port, _config, _net_auth, _logger)
      session._receive_connection(/*consume*/ connection, false)
    end

  be dispose() =>
    """"""
    for connection in _connections.values() do
      connection.dispose()
    end
    _connections.clear()


// class _Connection
actor _Connection
  let _logger: Logger[String] val
  let _net_auth: NetAuth val
  let _config: _Configuration val
  let _host: String val
  let _port: String val
  // var _ssl_context: (SSLContext | None) = None
  var _conn: (TCPConnection | None) = None
  var _session: (Session tag | None) = None

  // new iso create(
  new create(
    session: Session tag,
    host: String val,
    port: String val,
    config: _Configuration val,
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

  be _protocol_error() =>
    match _session
    | let s: Session tag => s._error(ProtocolError)
    end

  be _version_negotiation_failed() =>
    // TODO: [_Connection] Cleanup? Server closes connection,
    //    Likely will get callbakc to _closed
    match _session
    | let s: Session tag => s._error(UnsupportedProtocolVersion)
    end

  be _unsupported_version(unsupported_version: U32) =>
    // TODO: [_Connection] Likely shouldn't happen, but need to close down
    //    as server won't close connection in this case. Call manually.
    match _session
    | let s: Session tag => s._error(ProtocolError)
    end

  be _handshook(version: U32) =>
    // TODO: [_Connection] Change TCP notify based on version
    //    Setup _conn details from config?
    match _session
    | let s: Session tag => s._go_ahead()
    end

  be _closed() =>
    _conn = None
    match _session
    | let s: Session tag => s._closed()
    end

  be _set_session(session: Session) =>
    if _session is None then
      _session = session
    end

  be _clear_session() =>
    _session = None

  be dispose() =>
    match _conn
    | let c: TCPConnection => c.dispose()
    end
