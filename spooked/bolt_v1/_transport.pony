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
  """ Notify for active TCP connections speaking Bolt protocol v1. """
  let _logger: Logger[String] val
  let _connection: BoltConnection tag
  let _messenger: BoltV1Messenger tag
  let _wb: Writer
  let _rb: Reader
  var _receive_state: MessageReceiveState
  var _current_message: Array[U8 val] trn
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
    _current_message = recover trn Array[U8 val] end
    _chunk_size = 0

  fun ref connect_failed(conn: TCPConnection ref) =>
    """Handled by previous _Handshake notify object."""
    None

  fun ref sent(
    conn: TCPConnection ref,
    data: (String val | Array[U8 val] val))
    : (String val | Array[U8 val] val)
  =>
    """ Encode a message written to the connection. """
    _encode_message(data)

  fun ref sentv(
    conn: TCPConnection ref,
    data: ByteSeqIter val)
    : ByteSeqIter val
  =>
    """ Encode a sequence of messages written to the connection. """
    let encoded_seq = recover trn Array[ByteSeq] end
    for seq_data in data.values() do
      encoded_seq.push(_encode_message(seq_data))
    end
    consume encoded_seq

  // received - keep receiving for a complete message, then act on it.
  //    Pass back to _messenger? (seen it may have to send ACK_FAILURE in resp.)
  //    Also keeps things in this sub-package until response complete
  fun ref received(
    conn: TCPConnection ref,
    data: Array[U8 val] iso,
    times: USize val)
    : Bool val
  =>
    """
    Continue to receive data until all chunks describing a single message have
    arrived, then yeild.
    """
    // Add received data to the read buffer.
    _rb.append(consume data)
    
    try
      match _receive_state
      | AwaitingChunk =>
        if _rb.size() >= 2 then
          // Whole chunk header available
          _handle_header(_rb.u16_be())
        else
          // Only one byte available, waiting
          // on second byte of header.
          _receive_state = InHeader
          true // Keep receiving
        end

      | InHeader =>
// TODO: Combine with above..?
        _handle_header(_rb.u16_be())

      | InChunk =>
        _handle_chunk()

      // else
      //   false // Stop receiving
      end
    else
      // TODO: Protocol error?
      false
    end

  // expect ?

  fun ref closed(conn: TCPConnection ref) =>
    _connection.closed()

  // throttled ?
  // unthrottled ?

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

  fun ref _handle_header(header: U16 val): Bool =>
    // TODO: [BoltV1ConnectionNotify] _handle_header
    if header == 0 then
      // Message boundary,
      // Complete message handling, send back to messenger...
      // Set state back to AwaitingChunk
      
      false // Stop receiving
    else
      _chunk_size = header.usize()
      _receive_state = InChunk
      true // Keep receiving
    end

  fun ref _handle_chunk(): Bool =>
    // TODO: [BoltV1ConnectionNotify] _handle_chunk
    if _chunk_size <= _rb.size() then
      // Read buffer contains at least current chunk.
      // Move the chunk's data into _current_message.
      let chunk_data = recover val _rb.block(_chunk_size)? end
      _current_message.append(chunk_data)
      // Await the next chunk / msg boundary
      _receive_state = AwaitingChunk
    end // Otherwise, waiting on the rest of the chunk.