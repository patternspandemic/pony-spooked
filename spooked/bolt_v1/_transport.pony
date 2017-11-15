use "buffered"
use "logger"
use "net"

use ".."

primitive BoltTransport
  fun max_chunk_size(): U16 => 0xFFFF
  fun message_boundary(): U16 => 0

class BoltV1ConnectionNotify is TCPConnectionNotify
  """
  Notifications for active TCP connections speeking version 1 of the Bolt
  protocol.
  """
  let _logger: Logger[String] val
  let _connection: BoltConnection tag
  let _messenger: BoltV1Messenger tag

  new iso create(
    connection: BoltConnection tag,
    messenger: BoltV1Messenger tag,
    logger: Logger[String] val) =>
    _connection = connection
    _messenger = messenger
    _logger = logger

  fun ref connect_failed(conn: TCPConnection ref) =>
    """Handled by previous _Handshake notify object."""
    None

  fun ref sent(
    conn: TCPConnection ref,
    data: (String val | Array[U8 val] val))
    : (String val | Array[U8 val] val)
  =>
    // TODO: [BoltV1ConnectionNotify] sent
    data

  // sentv ?

  // received - keep receiving for a complete message, then act on it.
  //    Pass back to _messenger? (seen it may have to send ACK_FAILURE in resp.)
  //    Also keeps things in this sub-package until response complete

  // expect ?

  fun ref closed(conn: TCPConnection ref) =>
    _connection.closed()

  // throttled ?
  // unthrottled ?