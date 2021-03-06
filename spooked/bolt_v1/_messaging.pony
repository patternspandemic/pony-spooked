use "format"
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
  | UNEXPECTED
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

primitive UNEXPECTED
  fun string(): String => "UNEXPECTED"

// TODO: [ResponseHandler]
//    Logging of applied messages, S:, C: style
class ResponseHandler
  let _logger: Logger[String] val
  let _bolt_conn: BoltConnection tag
  let _messenger: BoltV1Messenger tag
  let _request: ClientRequest
  var statement: (CypherStatement val | None) = None
  var complete: Bool = false

  new create(
    request: ClientRequest,
    bolt_conn: BoltConnection tag,
    messenger: BoltV1Messenger tag,
    logger: Logger[String] val)
  =>
    _logger = logger
    _messenger = messenger
    _bolt_conn = bolt_conn
    _request = request

  fun ref apply(
    message: ServerResponse,
    metadata: (CypherMap val | CypherList val | None))
  =>
    """ Process the unpacked server response message. """
    try
      match message
      | SUCCESS => on_success(metadata as CypherMap val)
      | FAILURE => on_failure(metadata as CypherMap val)
      | IGNORED => on_ignored(metadata as CypherMap val)
      | RECORD  =>  on_record(metadata as CypherList val)
      | UNEXPECTED => error
      end
    else
      // TODO: [ResponseHandler] apply, error with metadata `as`, UNEXPECTED
      //  Other cleanup?
      complete = true
      _bolt_conn.protocol_error()
    end

  fun ref on_success(metadata: CypherMap val) =>
    """ Request was successful. """
    complete = true
    match _request
    | INIT => _bolt_conn.successfully_init(metadata)
    // | ACKFAILURE => None // Failure acknowledgement received. Nothing to do.
    | RESET => _bolt_conn.successfully_reset(metadata)
    | RUN =>
      try
        _bolt_conn.successfully_run(
          statement as CypherStatement val,
          metadata)
      end
    // | DISCARDALL => None // Stream discarded as intended. Nothing to do.
    | PULLALL =>
      try
        _bolt_conn.successfully_streamed(
          statement as CypherStatement val,
          metadata)
      end
    end

  fun ref on_failure(metadata: CypherMap val) =>
    """ Request failed. """
    complete = true
    match _request
    | INIT => _bolt_conn.failed_init(metadata)
    // | ACKFAILURE => None // Failure acknowledgement wasn't needed.
    | RESET => _bolt_conn.failed_reset(metadata)
    | RUN =>
      try
        _bolt_conn.failed_run(
          statement as CypherStatement val,
          metadata)
      end
    // | DISCARDALL => None // There was no result stream to discard.
    | PULLALL =>
      try
        // Retrieval failed or no result stream was available.
        _bolt_conn.failed_streamed(
          statement as CypherStatement val,
          metadata)
      end
    end

    // Acknowledge this failure.
    _messenger._acknowledge_failure()

  fun ref on_ignored(metadata: CypherMap val) =>
    """ Request was ignored due to previous failure. """
    complete = true
    match _request
    | RUN =>
      try
        _bolt_conn.ignored_run(
          statement as CypherStatement val,
          metadata)
      end
    // | PULLALL => None
      // Client will have received FAILURE or IGNORED for previous RUN and
      // should know not to expect its data.
    // | DISCARDALL => None // Nothing was expected. Nothing to do.
    end

  fun ref on_record(data: CypherList val) =>
    """ A record as part of a PULL_ALL request was received. """
    try
      _bolt_conn.receive_result(
        statement as CypherStatement val,
        data)
    end

actor BoltV1Messenger is BoltMessenger
  """ Creates and processes Bolt v1 protocol messages. """
  let _logger: Logger[String] val
  let _tcp_conn: TCPConnection tag
  let _bolt_conn: BoltConnection tag

  // Pipelined client messages, packed ready for transport
  var _requests: Array[ByteSeq] trn
  // Ordered response handlers for incoming server messages
  let _response_handlers: Array[ResponseHandler]
  // A cached empty map for returning a message's non-existent metadata
  let _empty_map: CypherMap val

  new create(
    bolt_conn: BoltConnection tag,
    tcp_conn: TCPConnection tag,
    logger: Logger[String] val)
  =>
    _logger = logger
    _tcp_conn = tcp_conn
    _bolt_conn = bolt_conn
    _requests = recover trn Array[ByteSeq] end
    _response_handlers = Array[ResponseHandler]
    _empty_map = CypherMap.empty()

  be init(config: Configuration val) =>
    """ Initialize the Bolt connection. """
    try
      _logger(Info) and _logger.log(
        "[Spooked] Info: (bolt_v1) Initializing connection...")

      // Send an INIT message immediately
      _tcp_conn.write(InitMessage(config.user_agent, config.auth)?)
      _response_handlers.push(ResponseHandler(INIT, _bolt_conn, this, _logger))
    else
      // Unable to initialize connection
      _bolt_conn.protocol_error()
    end

  be add_statement(
    statement: CypherStatement val,
    parameters: CypherMap val,
    results_as: ReturnedResults)
  =>
    """ Pipeline a Cypher statement to be run by the server. """
    try
      _requests.push(RunMessage(statement.template(), parameters)?)
      let run_handler = ResponseHandler(RUN, _bolt_conn, this, _logger)
      run_handler.statement = statement
      _response_handlers.push(run_handler)
      match results_as
      | Discarded =>
        _requests.push(DiscardAllMessage())
        _response_handlers.push(
          ResponseHandler(DISCARDALL, _bolt_conn, this, _logger))
      else
        _requests.push(PullAllMessage())
        let pull_handler = ResponseHandler(PULLALL, _bolt_conn, this, _logger)
        pull_handler.statement = statement
        _response_handlers.push(pull_handler)
      end
      _logger(Info) and _logger.log(
        "[Spooked] Info: (bolt_v1) Pipelined statement.")
    else
      // Could not pack Run message.
      _logger(Error) and _logger.log(
        "[Spooked] Error: (bolt_v1) Could not pack RUN message.")
      _bolt_conn.protocol_error() // TODO: Different error?
    end

  be flush() =>
    """ Send any pipelined messages through the connection. """
    if _requests.size() > 0 then
      _logger(Info) and _logger.log(
          "[Spooked] Info: (bolt_v1) Flushing pipeline...")

      let requests = _requests = recover trn Array[ByteSeq] end
      _tcp_conn.writev(consume requests)
    end

  be reset() =>
    """ Reset the Bolt connection. """
    _logger(Info) and _logger.log(
      "[Spooked] Info: (bolt_v1) Reseting connection...")

    // Send a RESET message immediately
    _tcp_conn.write(ResetMessage())
    _response_handlers.push(ResponseHandler(RESET, _bolt_conn, this, _logger))

  be _acknowledge_failure() =>
    """ Acknowledge a failure message. """
    _logger(Info) and _logger.log(
      "[Spooked] Info: (bolt_v1) Acknowledging failure...")

    // Send an ACK_FAILURE message immediately
    _tcp_conn.write(AckFailureMessage())
    _response_handlers.push(
      ResponseHandler(ACKFAILURE, _bolt_conn, this, _logger))

  be _handle_response_message(message: CypherStructure val) =>
    """ Handle a message response from the server. """
    // Determine the type of server message
    let server_response =
      match message.signature
      | SUCCESS() => SUCCESS
      | FAILURE() => FAILURE
      | IGNORED() => IGNORED
      | RECORD()  => RECORD
      else
        _logger(Error) and _logger.log(
          "[Spooked] Error: (bolt_v1) Received server message with unexpected signature: " +
          Format.int[U8](message.signature, FormatHex, PrefixDefault, 2))
        UNEXPECTED
      end

    // Extract the data as expected from message type
    try
      let data =
        match message.fields
        | let flds: Array[CypherType val] val =>
          if server_response is RECORD then
            // Record data is a list
            flds(0)? as CypherList val
          else
            // Success, Failure, and Ignored data is a map
            try
              flds(0)? as CypherMap val
            else
              // Fields list was empty, substitute an empty map.
              _empty_map // CypherMap.empty()
            end
          end
        | None =>
          // message.fields is unexpectedly None.
          // This probably should not occur.
          _logger(Warn) and _logger.log(
            "[Spooked] Warning: (bolt_v1) Fields of '" +
            server_response.string() + "' response is None.")
          None
        // else
        //   // message.fields is unexpectedly None.
        //   None
        end

      // Reference the current response handler, and apply to it
      // the response type and data of the received message.
      let current_handler = _response_handlers(0)?
      current_handler(server_response, data)

      // If the handler has completed its work, remove it from the handlers.
      if current_handler.complete then
        _response_handlers.shift()?
      end

    else
      // TODO: [BoltV1Messenger] _handle_response_message
      //    Unexpected problem with extracted structure field
      //    or no response handler available.
      _logger(Error) and _logger.log(
        "[Spooked] Error: (bolt_v1) Failed to extract field of '" +
        server_response.string() + "' response, or no handler was available.")
      // TODO: _bolt_conn.protocol_error(), cleanup
      None
    end
