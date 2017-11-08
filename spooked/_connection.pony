use "collections"
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
  let _connections: Array[_Connection iso]

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
    _connections = Array[_Connection].create()

  be acquire(session: Session tag) =>
    """Send a _Connection to session."""
    try
      let connection: _Connection iso = _connections.shift()?
      connection._set_session(session)
      session._receive_connection(consume connection, true)
    else
      let connection: _Connection iso =
        _Connection(session, _host, _port, _config, _net_auth, _logger)
      session._receive_connection(consume connection, false)
    end


class _Connection
  let _logger: Logger[String] val
  let _net_auth: NetAuth val
  let _config: _Configuration val
  let _host: String val
  let _port: String val
  // var _ssl_context: (SSLContext | None) = None
  var _conn: (TCPConnection | None) = None
  var _session: (Session tag | None) = None

  new iso create(
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

  fun _connect_failed() =>
    match _session
    | let s: Session => s._error(ServiceUnavailable)
    end

  // fun _auth_failed() =>
  //   match _session
  //   | let s: Session => s._auth_failed()
  //   end

  fun _protocol_error() =>
    match _session
    | let s: Session => s._error(ProtocolError)
    end

  fun _version_negotiation_failed() =>
    // TODO: [_Connection] Cleanup? Server closes connection,
    //    Likely will get callbakc to _closed
    match _session
    | let s: Session => s._error(UnsupportedProtocolVersion)
    end

  fun _unsupported_version(unsupported_version: U32) =>
    // TODO: [_Connection] Likely shouldn't happen, but need to close down
    //    as server won't close connection in this case. Call manually.
    match _session
    | let s: Session => s._error(ProtocolError)
    end

  fun _handshook(version: U32) =>
    // TODO: [_Connection] Change TCP notify based on version
    //    Setup _conn details from config?
    match _session
    | let s: Session => s._go_ahead()
    end

  fun _closed() =>
    _conn = None
    match _session
    | let s: Session => s._closed()
    end

  fun ref _set_session(session: Session) =>
    if _session is None then
      _session = session
    end

  fun ref _clear_session() =>
    _session = None
