use "buffered"
use "logger"
use "net"

primitive _ProtocolVersionNone
  fun apply(): U32 => U32(0)

primitive _PreferredProtocolVersions
  fun  first(): U32 => U32(1)
  fun second(): U32 => _ProtocolVersionNone()
  fun  third(): U32 => _ProtocolVersionNone()
  fun  forth(): U32 => _ProtocolVersionNone()

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

  new create(logger: Logger[String] val) =>
    _logger = logger

  fun ref connecting(conn: TCPConnection ref, count: U32) =>
    if _logger(Info) then
      (let host, let service) = conn.remote_address()
      _logger.log(
        "[Spooked] Info: Attempt" +"(" + count.string() + ")" +
        " to connect to " + host + ":" + service)
    end

  fun ref connect_failed(conn: TCPConnection ref) =>
    if _logger(Error) then
      (let host, let service) = conn.remote_address()
      _logger.log(
        "[Spooked] Error: Could not establish connection to server.")
    end
    // ... TODO: [Handshake] Handle failed connect

  fun ref auth_failed(conn: TCPConnection ref) =>
    // TODO: [Handshake] Handle failed auth
    None

  fun ref connected(conn: TCPConnection ref) =>
    _logger(Info) and _logger.log(
      "[Spooked] Info: Performing handshake...")
    conn.write(_GoGoBolt())
    conn.write(_ProposedProtocolVersions())
    conn.expect(4)

  fun ref received(
    conn: TCPConnection ref,
    data: Array[U8 val] iso,
    times: USize)
    : Bool
  =>
    let rb = Reader
    rb.append(consume data)
    try
      let chosen_protocol_version = rb.u32_be()?
      // TODO: [Handshake] Handle received version
      //    Perhaps determines which notifier to set next? !
    else
      // TODO: [Handshake] Couldn't negotiate protocol version.
      //    Close connection, notify higher up? Session?
    end
    true

  fun ref closed(conn: TCPConnection ref) =>
    // TODO: [Handshake] Handle closed
    //    Is this called when the client closes too?
    None

  // TODO: [Handshake] Consider throttled / unthrottled handlers.
  //       Likely unneccessary for the handshake.
