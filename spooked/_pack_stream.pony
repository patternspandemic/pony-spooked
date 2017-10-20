use "buffered"
use "format"
use "itertools"

/* Probably don't need

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
    let data_array =
      match data
      | let data': Array[U8] val => data'
      | let data': String => data'.array()
      end
    ":".join(
      Iter[U8](data_array.values())
        .map[String](
          {(b) => Format.int[U8](b, FormatHexBare, PrefixDefault, 2)}))

  fun packed(values': Array[_PackStreamType]): Array[U8] iso^ ? =>
    """ PackStream types to bytes functionality. """
    // A buffer to collect the encoded byte pieces
    // of each value found in the values' array.
    let wb = Writer

    // Encode each value in turn
    for value in values'.values() do
      match value
      | None =>
        // None is always encoded using the single marker byte C0.
        wb.write([0xC0])

      | let v: Bool =>
        // Boolean values are encoded within a single marker byte,
        // using C3 to denote true and C2 to denote false.
        let marker: Array[U8] val =
          if v then
            [0xC3]
          else
            [0xC2]
          end
          wb.write(marker)

      | let v: I64 =>
        // Integer values occupy either 1, 2, 3, 5 or 9 bytes depending on
        // magnitude. Several markers are designated specifically as TINY_INT
        // values and can therefore be used to pass a small number in a single
        // byte. These markers can be identified by a zero high-order bit (for
        // positive values) or by a high-order nibble containing only ones (for
        // negative values). The available encodings are illustrated below and
        // each shows a valid representation for the decimal value 42:
        //
        //     2A                          -- TINY_INT
        //     C8:2A                       -- INT_8
        //     C9:00:2A                    -- INT_16
        //     CA:00:00:00:2A              -- INT_32
        //     CB:00:00:00:00:00:00:00:2A  -- INT_64
        //
        // Note that while encoding small numbers in wider formats is
        // supported, it is generally recommended to use the most compact
        // representation possible. The following table shows the optimal
        // representation for every possible integer:
        //
        //   Range Minimum             |  Range Maximum             | Repres.
        // ============================|============================|==========
        //  -9 223 372 036 854 775 808 |             -2 147 483 649 | INT_64
        //              -2 147 483 648 |                    -32 769 | INT_32
        //                     -32 768 |                       -129 | INT_16
        //                        -128 |                        -17 | INT_8
        //                         -16 |                       +127 | TINY_INT
        //                        +128 |                    +32 767 | INT_16
        //                     +32 768 |             +2 147 483 647 | INT_32
        //              +2 147 483 648 | +9 223 372 036 854 775 807 | INT_64
        if (-0x10 <= v) and (v < 0x80) then
          // TINY_INT
          wb.u8(v.u8())
        elseif (-0x80 <= v) and (v < 0x80) then
          // INT_8
          wb.write([0xC8])
          wb.u8(v.u8())
        elseif (-0x8000 <= v) and (v < 0x8000) then
          // INT_16
          wb.write([0xC9])
          wb.i16_be(v.i16())
        elseif (-0x80000000 <= v) and (v < 0x80000000) then
          // INT_32
          wb.write([0xCA])
          wb.i32_be(v.i32())
        elseif (-0x8000000000000000 <= v) and (v <= 0x7FFFFFFFFFFFFFFF) then
          // INT_64
          wb.write([0xCB])
          wb.i64_be(v)
        // else
        //   // Integer value out of packable range
        end

      | let v: F64 =>
        // These are double-precision floating-point values, generally used for
        // representing fractions and decimals. Floats are encoded as a single
        // C1 marker byte followed by 8 bytes which are formatted according to
        // the IEEE 754 floating-point "double format" bit layout.
        //
        // - Bit 63 (the bit that is selected by the mask `0x8000000000000000`)
        //   represents the sign of the number.
        // - Bits 62-52 (the bits that are selected by the mask
        //   `0x7ff0000000000000`) represent the exponent.
        // - Bits 51-0 (the bits that are selected by the mask
        //   `0x000fffffffffffff`) represent the significand (sometimes called
        //   the mantissa) of the number.
        //
        //     C1 3F F1 99 99 99 99 99 9A  -- Float(+1.1)
        //     C1 BF F1 99 99 99 99 99 9A  -- Float(-1.1)
        wb.write([0xC1])
        wb.f64_be(v)

      | let v: String =>
        // Text data is represented as UTF-8 encoded bytes. Note that the sizes
        // used in string representations are the byte counts of the UTF-8
        // encoded data, not the character count of the original text.
        //
        //   Marker | Size                                | Maximum size
        //  ========|=====================================|====================
        //   80..8F | contnd w/in low-order nibble of mrkr| 15 bytes
        //   D0     | 8-bit big-endian unsigned integer   | 255 bytes
        //   D1     | 16-bit big-endian unsigned integer  | 65 535 bytes
        //   D2     | 32-bit big-endian unsigned integer  | 4 294 967 295 bytes
        //
        // For encoded text containing fewer than 16 bytes, including empty
        // strings, the marker byte should contain the high-order nibble '8'
        // (binary 1000) followed by a low-order nibble containing the size.
        // The encoded data then immediately follows the marker.
        //
        // For encoded text containing 16 bytes or more, the marker D0, D1 or
        // D2 should be used, depending on scale. This marker is followed by
        // the size and the UTF-8 encoded data.
        let string_bytes = v.array()
        let size = string_bytes.size()
        if size < 0x10 then
          wb.u8((0x80 + size).u8())
        elseif size < 0x100 then
          wb.write([0xD0])
          wb.u8(size.u8())
        elseif size < 0x10000 then
          wb.write([0xD1])
          wb.u16_be(size.u16())
        elseif size < 0x100000000 then
          wb.write([0xD2])
          wb.u32_be(size.u32())
        else
          // String too long to pack
          error
        end
        wb.write(string_bytes)

      | let v: _PackStreamArray => None
      | let v: _PackStreamMap => None
      | let v: _PackStreamStructure => None

      end
    end

    let b = recover iso Array[U8] end
    for chunk in wb.done().values() do
      b.append(chunk)
    end
    consume b

/*
  fun unpacked(data: Array[U8], offset: USize = 0): =>
    """
    """
*/