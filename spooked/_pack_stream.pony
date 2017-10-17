use "buffered"

primitive _FormatInt8
  """Signed 8-bit integer (two's complement)"""
  fun apply(): String => ">b"

primitive _FormatInt16
  """Signed 16-bit integer (two's complement)"""
  fun apply(): String => ">h"

primitive _FormatInt32
  """Signed 32-bit integer (two's complement)"""
  fun apply(): String => ">i"

primitive _FormatInt64
  """Signed 64-bit integer (two's complement)"""
  fun apply(): String => ">q"

primitive _FormatUInt8
  """Unsigned 8-bit integer"""
  fun apply(): String => ">B"

primitive _FormatUInt16
  """Unsigned 16-bit integer"""
  fun apply(): String => ">H"

primitive _FormatUInt32
  """Unsigned 32-bit integer"""
  fun apply(): String => ">I"

primitive _FormatFloat64
  """IEEE double-precision floating-point format"""
  fun apply(): String => ">d"

/*
type PackStreamFormat is
  ( _FormatInt8
  | _FormatInt16
  | _FormatInt32
  | _FormatInt64
  | _FormatUInt8
  | _FormatUInt16
  | _FormatUInt32
  | _FormatFloat64
  )
*/

// Temp
class _PackStreamArray
class _PackStreamMap
class _PackStreamStructure

type _PackStreamType is
  ( None // absence of value
  | Bool // true or false
  | I64 // signed 64-bit integer
  | F64 // 64-bit floating point number
  | String // UTF-8 encoded text data
  | _PackStreamArray // ordered collection of values
  | _PackStreamMap // keyed collection of values
  | _PackStreamStructure // composite set of values with a type signature
  )

primitive _PackStream
  """
  PackStream is a custom data serialisation format inspired heavily by
  MessagePack, but is not compatible with it. PackStream provides a type system
  that is fully compatible with the Cypher type system used by Neo4j and also
  takes extension data types in a different direction to MessagePack.
  """

  fun h(data: ByteSeq): String =>
    """
    A small helper function to translate byte data into a human-readable
    hexadecimal representation. Each byte in the input data is converted into a
    two-character hexadecimal string and is joined to its neighbours with a
    colon character.
    """
    for b in data.values() do
      
    end

  fun packed(values: Array[_PackStreamType]): Array[U8] iso^ =>
    """
    """

  fun unpacked(data: Array[U8], offset: USize = 0): =>
    """
    """
