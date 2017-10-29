use "buffered"

// user agent: pony-spooked/{version}

primitive Handshake
  fun apply(): ByteSeq => [0x60; 0x60; 0xB0; 0x17]

primitive ClientBoltVersions
  fun apply(
    first: U32 = 1,
    second: U32 = 0,
    third: U32 = 0,
    fourth: U32 = 0)
    : ByteSeq
  =>
    let b = recover iso Array[U8] end
    let wb = Writer
    wb .> u32_be(first) .> u32_be(second) .> u32_be(third) .> u32_be(fourth)

    for chunk in wb.done().values() do
      b.append(chunk)
    end

    consume b
