
class Request
  let description: String
  let data: (Array[U8] val | None)

  new create(
    desc: String,
    message_structure: PackStreamStructure)
  =>
    description = desc
    data =
      try _PackStream.packed([message_structure])?
      else None end
