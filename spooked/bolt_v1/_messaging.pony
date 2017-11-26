// use "buffered"
use "logger"
use "net"

use ".."

/* Client Messaging */

type ClientRequest is
  ( INIT
  | RUN
  | DISCARDALL
  | PULLALL
  | ACKFAILURE
  | RESET
  )


primitive INIT
  fun apply(): U8 => 0x01
  fun string(): String => "INIT"

primitive InitMessage
  fun apply(
    client_name: String,
    auth_token: CypherMap val)
    : ByteSeq ?
  =>
    _PackStream.packed([
      CypherStructure(INIT(), [client_name; auth_token])
    ])?


primitive RUN
  fun apply(): U8 => 0x10
  fun string(): String => "RUN"

primitive RunMessage
  fun apply(
    statement: String,
    parameters: CypherMap val = CypherMap.empty())
    : ByteSeq ?
  =>
    _PackStream.packed([
      CypherStructure(RUN(), [statement; parameters])
    ])?


primitive DISCARDALL
  fun apply(): U8 => 0x2F
  fun string(): String => "DISCARD_ALL"

primitive DiscardAllMessage
  fun apply(): ByteSeq => [0xB0; 0x2F]


primitive PULLALL
  fun apply(): U8 => 0x3F
  fun string(): String => "PULL_ALL"

primitive PullAllMessage
  fun apply(): ByteSeq => [0xB0; 0x3F]


primitive ACKFAILURE
  fun apply(): U8 => 0x0E
  fun string(): String => "ACK_FAILURE"

primitive AckFailureMessage
  fun apply(): ByteSeq => [0xB0; 0x0E]


primitive RESET
  fun apply(): U8 => 0x0F
  fun string(): String => "RESET"

primitive ResetMessage
  fun apply(): ByteSeq => [0xB0; 0x0F]


/* Server Messaging */

type ServerResponse is
  ( SUCCESS
  | FAILURE
  | IGNORED
  | RECORD
  )

primitive SUCCESS
  fun apply(): U8 => 0x70
  fun string(): String => "SUCCESS"

primitive FAILURE
  fun apply(): U8 => 0x7F
  fun string(): String => "FAILURE"

primitive IGNORED
  fun apply(): U8 => 0x7E
  fun string(): String => "IGNORED"

primitive RECORD
  fun apply(): U8 => 0x71
  fun string(): String => "RECORD"

// TODO: [ResponseHandler] Special handling for resets
class ResponseHandler
  let _logger: Logger[String] val
  let _bolt_conn: BoltConnection tag

  let _request: ClientRequest
  var _metadata: (CypherMap val | None) = None
  var _ignored: (Bool | None) = None
  // Stream each record as it comes, don't store.
  // var records: (Array[CypherList val] trn | None) = None

  new create(
    request: ClientRequest,
    bolt_conn: BoltConnection tag,
    logger: Logger[String] val)
  =>
    _logger = logger
    _bolt_conn = bolt_conn
    _request = request

  fun ref apply(message: ServerResponse, data: (CypherMap | CypherList)) =>
    """ Process the unpacked server response message. """
    // TODO: [ResponseHandler] apply

  // on_success
  // on_failure
  // on_ignored
  // on_record
  // complete


actor BoltV1Messenger is BoltMessenger
  """ Creates and processes Bolt v1 protocol messages. """
  let _logger: Logger[String] val
  let _tcp_conn: TCPConnection tag
  let _bolt_conn: BoltConnection tag

  // Pipelined client messages, packed ready for transport
  let _requests: Array[ByteSeq]
  // Ordered response handlers for incoming server messages
  let _responses: Array[ResponseHandler]

  new create(
    bolt_conn: BoltConnection tag,
    tcp_conn: TCPConnection tag,
    logger: Logger[String] val)
  =>
    _logger = logger
    _tcp_conn = tcp_conn
    _bolt_conn = bolt_conn
    _requests = Array[ByteSeq]
    _responses = Array[ResponseHandler]

  be init(config: Configuration val) =>
    """Initialize the Bolt connection."""
    try
      // Send an INIT message immediately
      _tcp_conn.write(InitMessage(config.user_agent, config.auth)?)
      _responses.push(ResponseHandler(INIT, _bolt_conn, _logger))
    else
      // Unable to initialize connection
      _bolt_conn.protocol_error()
    end

  be add_statement(statement: String val, parameters: CypherMap val) =>
    """Add a Cypher statement to be run by the server."""
    // TODO: [BoltV1Messenger] add_statement
    // Pipeline RUN statements and later writev them in flush()
    None

  be flush() =>
    """Send all pipelined messages through the connection."""
    // TODO: [BoltV1Messenger] flush
    // _tcp_conn.writev all pipelined statements..
    None

  be reset() =>
    // TODO: [BoltV1Messenger] reset
    _logger(Info) and _logger.log(
      "[Spooked] Info: Sending RESET to server...")
    _bolt_conn.successfully_reset() // TMP. Would notify send this back?

  be _handle_response_message(message: CypherStructure val) =>
    """ Handle a message response from the server. """
    // TODO: [BoltV1Messenger] _handle_response_message