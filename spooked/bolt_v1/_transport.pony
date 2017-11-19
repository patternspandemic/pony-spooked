use "buffered"
use "collections"
use "logger"
use "net"

use ".."

primitive BoltTransport
  fun max_chunk_size(): USize => 65535 //0xFFFF
  fun message_boundary(): U16 => 0

class BoltV1ConnectionNotify is TCPConnectionNotify
  """ Notify for active TCP connections speaking Bolt protocol v1. """
  let _logger: Logger[String] val
  let _connection: BoltConnection tag
  let _messenger: BoltV1Messenger tag
  let _wb: Writer

  new iso create(
    connection: BoltConnection tag,
    messenger: BoltV1Messenger tag,
    logger: Logger[String] val)
  =>
    _connection = connection
    _messenger = messenger
    _logger = logger
    _wb = Writer

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
    Receive exactly one message from the server and then yeild
    """
    // Going to be tricky, cannot use expect as thought about before.
    // Good news is the first two bytes are the chunk header..
    // Will need to keep a buffer to add message chunks to until you
    // encounter a message boundary. Will be tricky when receiving part
    // of a new message in the latter part of received data.

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
