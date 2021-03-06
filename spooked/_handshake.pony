use "buffered"
use "logger"
use "net"

use "./bolt_v1"


/* Bolt Protocol Version Helpers */

primitive _ProtocolVersionNone
  fun apply(): U32 => U32(0)

primitive _ProtocolVersionOne
  """ Helper to supply the versioned messenger/notifier for BoltV1 """
  fun apply(): U32 => U32(1)

  fun messenger(
    bolt_conn: BoltConnection tag,
    tcp_conn: TCPConnection tag,
    logger: Logger[String] val)
    : BoltV1Messenger tag^
  =>
    BoltV1Messenger(bolt_conn, tcp_conn, logger)

  fun notify(
    bolt_conn: BoltConnection tag,
    v1_messenger: BoltV1Messenger tag,
    logger: Logger[String] val)
    : BoltV1ConnectionNotify iso^
  =>
    BoltV1ConnectionNotify(bolt_conn, v1_messenger, logger)

primitive _PreferredProtocolVersions
  """ Bolt Protocol versions supported by Spooked. """
  // Update as new versions become supported.
  fun  first(): U32 => _ProtocolVersionOne()
  fun second(): U32 => _ProtocolVersionNone()
  fun  third(): U32 => _ProtocolVersionNone()
  fun  forth(): U32 => _ProtocolVersionNone()


/* Handshake */

primitive _GoGoBolt
  """Bolt Protocol Preamble"""
  fun apply(): ByteSeq => [0x60; 0x60; 0xB0; 0x17]

primitive _ProposedProtocolVersions
  """Client Proposal of Supported Protocol Versions"""
  fun apply(): ByteSeq =>
    let b = recover iso Array[U8] end
    let wb = Writer
    wb
      .> u32_be(_PreferredProtocolVersions.first())
      .> u32_be(_PreferredProtocolVersions.second())
      .> u32_be(_PreferredProtocolVersions.third())
      .> u32_be(_PreferredProtocolVersions.forth())
    for chunk in wb.done().values() do
      b.append(chunk)
    end
    consume b

class _Handshake is TCPConnectionNotify
  let _logger: Logger[String] val
  let _connection: BoltConnection tag

  new iso create(connection: BoltConnection tag, logger: Logger[String] val) =>
    _connection = connection
    _logger = logger

  fun ref connecting(conn: TCPConnection ref, count: U32) =>
    try
      if _logger(Info) then
        (let host, let service) = conn.remote_address().name()?
        _logger.log(
          "[Spooked] Info: Attempt" +"(" + count.string() + ")" +
          " to connect to " + host + ":" + service)
      end
    end

  fun ref connect_failed(conn: TCPConnection ref) =>
    _logger(Error) and _logger.log(
        "[Spooked] Error: Could not establish connection to server.")
    _connection._connect_failed()

  fun ref auth_failed(conn: TCPConnection ref) =>
    // TODO: [Handshake] Handle failed auth
    // _logger(Error) and _logger.log(
    //     "[Spooked] Error: Could not establish authorization with server.")
    // _connection._auth_failed()
    None

  fun ref connected(conn: TCPConnection ref) =>
    _logger(Info) and _logger.log(
      "[Spooked] Info: Performing handshake...")
    conn.expect(4)
    conn.write(_GoGoBolt())
    conn.write(_ProposedProtocolVersions())

  fun ref received(
    conn: TCPConnection ref,
    data: Array[U8 val] iso,
    times: USize)
    : Bool
  =>
    let rb = Reader
    rb.append(consume data)
    conn.expect(0) // Reset received to any number of bytes.

    try
      let chosen_protocol_version = rb.u32_be()?

      match chosen_protocol_version
      | _ProtocolVersionNone()
      =>
        // Server doesn't support any preferred protocol version.
        // The server should be closing the connection.
        _logger(Error) and _logger.log(
          "[Spooked] Error: No preferred protocol version supported by server.")

        _connection._version_negotiation_failed()

      | _ProtocolVersionOne()
      =>
        // Protocol versions 1 was supported by the server.
        _logger(Info) and _logger.log(
          "[Spooked] Info: Agreed upon Bolt v" +
          chosen_protocol_version.string())

        let messenger =
          _ProtocolVersionOne.messenger(_connection, conn, _logger)
        let notify =
          _ProtocolVersionOne.notify(_connection, messenger, _logger)
        _connection._handshook(messenger, consume notify)

      else
        // Odd, the server wants to use a version we didn't suggest.
        // This is a protocol error, as server should respond with
        // _ProtocolVersionNone in this case.
        _logger(Error) and _logger.log(
          "[Spooked] Error: Server requesting unsupported Bolt v" +
          chosen_protocol_version.string())

        _connection.protocol_error()
        // TODO: [Handshake] Close conn? or let _connection do it?
      end
    else
      // Server sent us something unexpected.
      _connection.protocol_error()
    end
    false

  fun ref closed(conn: TCPConnection ref) =>
    _connection.closed()
