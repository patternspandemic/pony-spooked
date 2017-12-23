use "buffered"
use "collections"
use "logger"
use "net"

use ".."


primitive BoltTransport
  fun max_chunk_size(): USize => 65535 //0xFFFF
  fun message_boundary(): U16 => 0


primitive AwaitingChunk
primitive InHeader
primitive InChunk

type MessageReceiveState is
  ( AwaitingChunk
  | InHeader
  | InChunk
  )


class BoltV1ConnectionNotify is TCPConnectionNotify
  """ Notifiers for active TCP connections speaking Bolt protocol v1. """

  let _logger: Logger[String] val
  let _connection: BoltConnection tag
  let _messenger: BoltV1Messenger tag
  let _wb: Writer

  let _rb: Reader
  var _receive_state: MessageReceiveState
  var _current_message_data: Array[U8 val] trn
  var _chunk_size: USize

  new iso create(
    connection: BoltConnection tag,
    messenger: BoltV1Messenger tag,
    logger: Logger[String] val)
  =>
    _connection = connection
    _messenger = messenger
    _logger = logger
    _wb = Writer
    _rb = Reader
    _receive_state = AwaitingChunk
    _current_message_data = recover trn Array[U8 val] end
    _chunk_size = 0

  fun ref connect_failed(conn: TCPConnection ref) =>
    """
    Connection failure is purposely ignored, as this notifier is only set
    after successful connection.
    """
    None

  fun ref sent(
    conn: TCPConnection ref,
    data: (String val | Array[U8 val] val))
    : (String val | Array[U8 val] val)
  =>
    """ Encode a packed message written to the connection into chunks. """
    _encode_message(data)

  fun ref sentv(
    conn: TCPConnection ref,
    data: ByteSeqIter val)
    : ByteSeqIter val
  =>
    """ Encode packed messages written to the connection into chunks. """
    let encoded_seq = recover trn Array[ByteSeq] end
    for seq_data in data.values() do
      encoded_seq.push(_encode_message(seq_data))
    end
    consume encoded_seq

  fun ref _encode_message(
    data: ByteSeq)
    : ByteSeq
  =>
    """ Encode a packed message into chunks. """
    let msg_data =
      match data
      | let data': Array[U8] val => data'
      | let data': String => data'.array()
      end
    let encoded = recover trn Array[U8 val] end

    // Encode a packed message into chunks of max size.
    for from in Range(0, msg_data.size(), BoltTransport.max_chunk_size()) do
      let to = from + BoltTransport.max_chunk_size()
      let chunk = recover val msg_data.slice(from, to) end
      _wb.u16_be(chunk.size().u16()) // chunk header
      _wb.write(chunk) // chunk data
    end
    _wb.u16_be(BoltTransport.message_boundary()) // end message marker

    for byte_seq in _wb.done().values() do
      encoded.append(byte_seq)
    end

    consume encoded

  fun ref received(
    conn: TCPConnection ref,
    data: Array[U8 val] iso,
    times: USize val)
    : Bool val
  =>
    """
    Append data received into a read buffer, from which, process as many
    chunks and assemble as many messages as are contained in that buffer.
    """
    _rb.append(consume data)

    // A flag to mark whether there is more to process in _rb
    var process_rb = true

    while process_rb do
      process_rb =
        match _receive_state
        | AwaitingChunk =>
          // Awaiting a chunk that is either the start of a message or part of
          // a message currently being collected through receives.
          if _rb.size() >= 2 then
            // Whole chunk header available
            _handle_header()
          else
            // Only one byte available, waiting
            // on second byte of header.
            _receive_state = InHeader
            false // Done processing _rb
          end
        | InHeader =>
          // So far only half a chunk header has been confirmed. At this point,
          // at least the rest of the chunk header is available.
          _handle_header()
        | InChunk =>
          // The size of the chunk's data is known. Handle data belonging to
          // the chunk, either waiting for more data to fill the read buffer,
          // or appending all the chunk's data into the current message buffer.
          _handle_chunk()
        end
    end
    true // Keep receiving

  fun ref _handle_header(): Bool =>
    """ Act on a header read from the read buffer. """
    try
      let header = _rb.u16_be()?
      if header == BoltTransport.message_boundary() then
        // End of message detected
        _handle_message()
        _receive_state = AwaitingChunk
      else
        // A new chunk has arrived
        _chunk_size = header.usize()
        _receive_state = InChunk
      end
    end

    if _rb.size() > 0 then
      true // Keep processing received data
    else
      false // Done processing _rb
    end

  fun ref _handle_chunk(): Bool =>
    """ Act on chunk data. """
    if _chunk_size <= _rb.size() then
      // Read buffer contains at least the current chunk.
      // Move the chunk's data into _current_message_data.
      try
        let chunk_data: Array[U8] val = _rb.block(_chunk_size)?
        _current_message_data.append(chunk_data)

        // Expect the next chunk / msg boundary
        _receive_state = AwaitingChunk
      end

      if _rb.size() > 0 then
        true // Keep processing received data
      else
        false // Done processing _rb
      end
    else
       // Haven't yet received all of chunk data
      false // Done processing _rb
    end

  fun ref _handle_message() =>
    """ Act on a completely received message. """
    try
      // Unpack the message into a CypherStructure
      let packed_message = _current_message_data = recover trn Array[U8 val] end

// let packed_message': Array[U8 val] val = consume packed_message
// _logger(Info) and _logger.log(_PackStream.h(packed_message'))

      let message: CypherStructure val =
        _PackStream.unpacked(consume packed_message)? as CypherStructure val
        // _PackStream.unpacked(packed_message')? as CypherStructure val
      
      // Send it on to the messenger for response processing.
      _messenger._handle_response_message(message)
    // else
    //   // Message unpacking error, a ProtocolError?
    //   _logger(Info) and _logger.log(
    //     "[Spooked] Error: ...")
    end

  fun ref closed(conn: TCPConnection ref) =>
    _connection.closed()

  // throttled ?
  // unthrottled ?
