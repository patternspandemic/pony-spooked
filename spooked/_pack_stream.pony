use "buffered"
use "collections"
use "format"
use "itertools"

type PackStreamType is
  ( PackStreamNull // absence of value
  | PackStreamBoolean // true or false
  | PackStreamInteger // signed 64-bit integer
  | PackStreamFloat // 64-bit floating point number
  | PackStreamString // UTF-8 encoded text data
  | PackStreamList // ordered collection of values
  | PackStreamMap // keyed collection of values
  | PackStreamStructure // composite set of values with a type signature
  )

// PackStream to Pony type mapping
type PackStreamNull      is None
type PackStreamBoolean   is Bool
type PackStreamInteger   is I64
type PackStreamFloat     is F64
type PackStreamString    is String
type PackStreamList      is _PackStreamList
type PackStreamMap       is _PackStreamMap
type PackStreamStructure is _PackStreamStructure


class _PackStreamList
  var data: Array[PackStreamType]

  new create(length: USize = 0) =>
    data = Array[PackStreamType](length)

  new from_array(data': Array[PackStreamType]) =>
    data = data'

  fun ref _hashed_packed(): U64 ? =>
    HashByteSeq.hash(_PackStream.packed([this])?)


class _PackStreamMap
  var data: MapIs[PackStreamType, PackStreamType]

  new create(prealloc: USize = 6) =>
    data = MapIs[PackStreamType, PackStreamType](prealloc)

  new from_map(data': MapIs[PackStreamType, PackStreamType]) =>
    data = data'

  fun ref _hashed_packed(): U64 ? =>
    HashByteSeq.hash(_PackStream.packed([this])?)


class _PackStreamStructure
  var signature: U8
  var fields: (Array[PackStreamType] | None)

  new create(signature': U8, fields': (Array[PackStreamType] | None) = None) =>
    signature = signature'
    fields = fields'

  fun ref field_count(): USize =>
    match fields
    | None => 0
    | let field_array: Array[PackStreamType] => field_array.size()
    end

  fun ref _hashed_packed(): U64 ? =>
    HashByteSeq.hash(_PackStream.packed([this])?)


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

  fun packed(values': Array[PackStreamType]): Array[U8] val^ ? =>
    """ PackStream types to bytes functionality. """
    // A buffer to collect the encoded byte pieces
    // of each value found in the values' array.
    let wb = Writer

    // Encode each value in turn
    for value in values'.values() do
      match value
      | PackStreamNull =>
        // None is always encoded using the single marker byte C0.
        wb.write([0xC0])

      | let v: PackStreamBoolean =>
        // Boolean values are encoded within a single marker byte,
        // using C3 to denote true and C2 to denote false.
        let marker: Array[U8] val =
          if v then
            [0xC3]
          else
            [0xC2]
          end
          wb.write(marker)

      | let v: PackStreamInteger =>
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

      | let v: PackStreamFloat =>
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

      | let v: PackStreamString =>
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

      | let v: PackStreamList =>
        // Lists are heterogeneous sequences of values and therefore permit a
        // mixture of types within the same list. The size of a list denotes
        // the number of items within that list, rather than the total packed
        // byte size. The markers used to denote a list are described in the
        // table below:
        //
        //   Marker | Size                                | Maximum size
        //  ========|=====================================|====================
        //   90..9F | stored in low-order nibble of mrkr  | 15 bytes
        //   D4     | 8-bit big-endian unsigned integer   | 255 items
        //   D5     | 16-bit big-endian unsigned integer  | 65 535 items
        //   D6     | 32-bit big-endian unsigned integer  | 4 294 967 295 items
        //
        // For lists containing fewer than 16 items, including empty lists, the
        // marker byte should contain the high-order nibble '9' (binary 1001)
        // followed by a low-order nibble containing the size. The items within
        // the list are then serialised in order immediately after the marker.
        //
        // For lists containing 16 items or more, the marker D4, D5 or D6
        // should be used, depending on scale. This marker is followed by the
        // size and list items, serialized in order.
        let size = v.data.size()
        if size < 0x10 then
          wb.u8((0x90 + size).u8())
        elseif size < 0x100 then
          wb.write([0xD4])
          wb.u8(size.u8())
        elseif size < 0x10000 then
          wb.write([0xD5])
          wb.u16_be(size.u16())
        elseif size < 0x100000000 then
          wb.write([0xD5])
          wb.u32_be(size.u32())
        else
          // List too long to pack
          error
        end
        let list_bytes: Array[U8] val = packed(v.data)?
        wb.write(list_bytes)

      | let v: PackStreamMap =>
        // Maps are sets of key-value pairs that permit a mixture of types
        // within the same map. The size of a map denotes the number of pairs
        // within that map, not the total packed byte size. The markers used to
        // denote a map are described in the table below:
        //
        //   Marker | Size                               | Maximum size
        //  ========|====================================|=====================
        //   A0..AF | stored in low-order nibble of mrkr | 15 entries
        //   D8     | 8-bit big-endian unsigned integer  | 255 entries
        //   D9     | 16-bit big-endian unsigned integer | 65 535 entries
        //   DA     | 32-bit big-endian unsigned integer | 4 294 967 295 ntries
        //
        // For maps containing fewer than 16 key-value pairs, including empty
        // maps, the marker byte should contain the high-order nibble 'A'
        // (binary 1010) followed by a low-order nibble containing the size.
        // The entries within the map are then serialised in [key, value, key,
        // value] order immediately after the marker. Keys are generally text
        // values.
        //
        // For maps containing 16 pairs or more, the marker D8, D9 or DA should
        // be used, depending on scale. This marker is followed by the size and
        // map entries. The order in which map entries are encoded is not
        // important; maps are, by definition, unordered.
        let size = v.data.size()
        if size < 0x10 then
          wb.u8((0xA0 + size).u8())
        elseif size < 0x100 then
          wb.write([0xD8])
          wb.u8(size.u8())
        elseif size < 0x10000 then
          wb.write([0xD9])
          wb.u16_be(size.u16())
        elseif size < 0x100000000 then
          wb.write([0xDA])
          wb.u32_be(size.u32())
        else
          // Map too long to pack
          error
        end
        let map_pairs_array = Array[PackStreamType]
        for (k', v') in v.data.pairs() do
          map_pairs_array .> push(k') .> push(v')
        end
        let map_bytes: Array[U8] val = packed(map_pairs_array)?
        wb.write(map_bytes)

      | let v: PackStreamStructure =>
        // Structures represent composite values and consist, beyond the marker
        // of a single byte signature followed by a sequence of fields, each an
        // individual value. The size of a structure is measured as the number
        // of fields and not the total byte size. This count does not include
        // the signature. The markers used to denote a  structure are described
        // in the table below:
        //
        //   Marker | Size                               | Maximum size
        //  ========|====================================|=====================
        //   B0..BF | stored in low-order nibble of mrkr | 15 fields
        //   DC     | 8-bit big-endian unsigned integer  | 255 fields
        //   DD     | 16-bit big-endian unsigned integer | 65 535 fields
        //
        // The signature byte is used to identify the type or class of the
        // structure. Signature bytes may hold any value between 0 and +127.
        // Bytes with the high bit set are reserved for future expansion. For
        // structures containing fewer than 16 fields, the marker byte should
        // contain the high-order nibble 'B' (binary 1011) followed by a low-
        // order nibble containing the size. The marker is immediately
        // followed by the signature byte and the field values.
        //
        // For structures containing 16 fields or more, the marker DC or DD
        // should be used, depending on scale. This marker is followed by the
        // size, the signature byte and the fields, serialised in order.
        let size: USize =
          match v.fields
          | None => 0
          | let field_array: Array[PackStreamType] => field_array.size()
          end

        if size < 0x10 then
          wb.u8((0xB0 + size).u8())
        elseif size < 0x100 then
          wb.write([0xDC])
          wb.u8(size.u8())
        elseif size < 0x10000 then
          wb.write([0xDD])
          wb.u16_be(size.u16())
        else
          // Structure too big to pack
          error
        end

        wb.u8(v.signature)
        if size > 0 then
          let fields_bytes: Array[U8] val =
            packed(v.fields as Array[PackStreamType])?
          wb.write(fields_bytes)
        end

      else
        // Don't know how to encode unmatched value
        error
      end
    end

    let b = recover trn Array[U8] end
    for chunk in wb.done().values() do
      b.append(chunk)
    end
    consume b

  fun unpacked(data: ByteSeq, offset: USize = 0): PackStreamType ? =>
    """ Bytes to PackStream type functionality. """
    _Packed(data, offset)?.next()


class _Packed is Iterator[PackStreamType]
  """
  The Packed class provides a framework for "unpacking" packed data. Given a
  string of byte data and an initial offset, values can be extracted via the
  unpack method.
  """

  let _rb: Reader
  let _data: ByteSeq
  var _has_next: Bool = false
  var _next: PackStreamType = None

  new create(data: ByteSeq, offset: USize = 0) ? =>
    _rb = Reader
    _data = data
    _rb.append(_data)
    _rb.skip(offset)?
    try
      _next = _unpack()? as PackStreamType
      _has_next = true
    else
      // No PackStreamTypes available
      error
    end

  fun ref has_next(): Bool val =>
    _has_next

  fun ref next(): PackStreamType =>
    let r = _next
    try
      _next = _unpack()? as PackStreamType
    else
      _has_next = false
    end
    r

  fun ref rewind(offset: USize = 0) ? =>
    _rb.clear()
    _rb.append(_data)
    _rb.skip(offset)?

  fun ref _unpack_string(length: USize): String val ? =>
    String.from_array(_rb.block(length)?)

  fun ref _unpack_map(
    pair_count: USize)
    : MapIs[PackStreamType, PackStreamType] ?
  =>
    let pair_data = _unpack(pair_count * 2)? as Array[PackStreamType]

    let key_iter =
      Iter[PackStreamType](pair_data.values())
        .enum().filter( {(pair) => (pair._1 % 2) == 0 } )
        .map[PackStreamType]( {(pair) => pair._2 })

    let val_iter =
      Iter[PackStreamType](pair_data.values())
        .enum().filter( {(pair) => (pair._1 % 2) != 0 } )
        .map[PackStreamType]( {(pair) => pair._2 })

    let kv_pairs = key_iter.zip[PackStreamType](val_iter)

    let m: MapIs[PackStreamType, PackStreamType] = m.create(pair_count)
    m.concat(kv_pairs)
    m

  fun ref _unpack_structure(
    field_count: USize)
    : (U8, Array[PackStreamType]) ?
  =>
    let signature = _rb.u8()?
    let fields = _unpack(field_count)? as Array[PackStreamType]
    (signature, fields)

  fun ref _unpack(
    count: USize = 1)
    : (PackStreamType | Array[PackStreamType]) ?
  =>
    let unpacked = Array[PackStreamType].create(count)

    for _ in Range(0, count) do
      let marker_byte = _rb.u8()?
      match marker_byte
      // Null
      | 0xC0 => unpacked.push(None)
      // Boolean
      | 0xC2 => unpacked.push(false)
      | 0xC3 => unpacked.push(true)
      // Integer
      | let mb: U8 if mb < 0x80 => unpacked.push(mb.i64())
      | let mb: U8 if mb >= 0xF0 => unpacked.push((mb.i64() - 0x100))
      | 0xC8 => unpacked.push(_rb.i8()?.i64())
      | 0xC9 => unpacked.push(_rb.i16_be()?.i64())
      | 0xCA => unpacked.push(_rb.i32_be()?.i64())
      | 0xCB => unpacked.push(_rb.i64_be()?.i64())
      // Float
      | 0xC1 => unpacked.push(_rb.f64_be()?)
      // String
      | let mb: U8 if (0x80 <= mb) and (mb < 0x90) =>
        unpacked.push(_unpack_string((mb and 0x0F).usize())?)
      | 0xD0 => unpacked.push(_unpack_string(_rb.u8()?.usize())?)
      | 0xD1 => unpacked.push(_unpack_string(_rb.u16_be()?.usize())?)
      | 0xD2 => unpacked.push(_unpack_string(_rb.u32_be()?.usize())?)
      // PackStreamList
      | let mb: U8 if (0x90 <= mb) and (mb < 0xA0) =>
       unpacked.push(PackStreamList.from_array(
         _unpack((mb and 0x0F).usize())? as Array[PackStreamType]))
      | 0xD4 => unpacked.push(PackStreamList.from_array(
          _unpack(_rb.u8()?.usize())? as Array[PackStreamType]))
      | 0xD5 => unpacked.push(PackStreamList.from_array(
          _unpack(_rb.u16_be()?.usize())? as Array[PackStreamType]))
      | 0xD6 => unpacked.push(PackStreamList.from_array(
          _unpack(_rb.u32_be()?.usize())? as Array[PackStreamType]))
      // PackStreamMap
      | let mb: U8 if (0xA0 <= mb) and (mb < 0xB0) =>
        unpacked.push(PackStreamMap.from_map(
          _unpack_map((mb and 0x0F).usize())?))
      | 0xD8 => unpacked.push(PackStreamMap.from_map(
          _unpack_map(_rb.u8()?.usize())?))
      | 0xD9 => unpacked.push(PackStreamMap.from_map(
          _unpack_map(_rb.u16_be()?.usize())?))
      | 0xDA => unpacked.push(PackStreamMap.from_map(
          _unpack_map(_rb.u32_be()?.usize())?))
      // PackStreamStructure
      | let mb: U8 if (0xB0 <= mb) and (mb < 0xC0) =>
        (let signature, let fields) = _unpack_structure((mb and 0x0F).usize())?
        unpacked.push(PackStreamStructure(signature, fields))
      | 0xDC =>
        (let signature, let fields) = _unpack_structure(_rb.u8()?.usize())?
        unpacked.push(PackStreamStructure(signature, fields))
      | 0xDD =>
        (let signature, let fields) = _unpack_structure(_rb.u16_be()?.usize())?
        unpacked.push(PackStreamStructure(signature, fields))
      else
        // Unknown marker byte
        error
      end
    end

    if count == 1 then
      unpacked(0)?
    else
      unpacked
    end
