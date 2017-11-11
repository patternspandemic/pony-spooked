// use "buffered"
use "logger"
use "net"

use ".."

primitive INIT
  fun apply(): U8 => 0x01
  fun string(): String => "INIT"

primitive InitMessage
  fun apply(
    client_name: String,
    auth_token: PackStreamMap val)
    : PackStreamStructure val
  =>
    PackStreamStructure(INIT(), [client_name; auth_token])


primitive RUN
  fun apply(): U8 => 0x10
  fun string(): String => "RUN"

primitive RunMessage
  fun apply(
    statement: String,
    parameters: PackStreamMap val)
    : PackStreamStructure val
  =>
    PackStreamStructure(RUN(), [statement; parameters])


primitive DISCARDALL
  fun apply(): U8 => 0x2F
  fun string(): String => "DISCARD_ALL"

primitive DiscardAllMessage
  fun apply(): PackStreamStructure val =>
    PackStreamStructure(DISCARDALL())


primitive PULLALL
  fun apply(): U8 => 0x3F
  fun string(): String => "PULL_ALL"

primitive PullAllMessage
  fun apply(): PackStreamStructure val =>
    PackStreamStructure(PULLALL())


primitive ACKFAILURE
  fun apply(): U8 => 0x0E
  fun string(): String => "ACKFAILURE"

primitive AckFailureMessage
  fun apply(): PackStreamStructure val =>
    PackStreamStructure(ACKFAILURE())


primitive RESET
  fun apply(): U8 => 0x0F
  fun string(): String => "RESET"

primitive ResetMessage
  fun apply(): PackStreamStructure val =>
    PackStreamStructure(RESET())


primitive RECORD
  fun apply(): U8 => 0x71
  fun string(): String => "RECORD"

// primitive RecordMessage


primitive SUCCESS
  fun apply(): U8 => 0x70
  fun string(): String => "SUCCESS"

// primitive SuccessMessage


primitive FAILURE
  fun apply(): U8 => 0x7F
  fun string(): String => "FAILURE"

// primitive FailureMessage


primitive IGNORED
  fun apply(): U8 => 0x7E
  fun string(): String => "IGNORED"

// primitive IgnoredMessage


actor BoltV1Messenger is BoltMessenger
  """
  Creates Bolt v1 protocol messages and sends them to the underlying
  TCP connection. They are however first encoded via the related
  BoltV1ConnectionNotify object which handles message transport.
  """
  let _logger: Logger[String] val
  let _tcp_conn: TCPConnection tag
  let _bolt_conn: BoltConnection tag

  new create(
    bolt_conn: BoltConnection tag,
    tcp_conn: TCPConnection tag,
    logger: Logger[String] val)
  =>
    _logger = logger
    _tcp_conn = tcp_conn
    _bolt_conn = bolt_conn

  be reset() =>
    // TODO: [BoltV1Messenger] reset
    _logger(Info) and _logger.log(
      "[Spooked] Info: Sending RESET to server...")
    _bolt_conn.successfully_reset() // Would notify send this back?
