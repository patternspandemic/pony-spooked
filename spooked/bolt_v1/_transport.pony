use "buffered"
use "logger"
use "net"

use ".."

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

  // sent
  // sentv ?
  // received
  // expect ?

  fun ref closed(conn: TCPConnection ref) =>
    _connection.closed()

  // throttled ?
  // unthrottled ?