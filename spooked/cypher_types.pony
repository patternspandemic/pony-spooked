use "collections"

type CypherType is
  ( CypherNull                // absence of value
  /* Property Types */
  | CypherBoolean             // true or false
  | CypherInteger             // signed 64-bit integer
  | CypherFloat               // 64-bit floating point number
  | CypherString              // UTF-8 encoded text data
  /* Composite Types */
  | CypherList                // ordered collection of values
  | CypherMap                 // keyed collection of values
  /* Structural Types */
  | CypherNode                // property graph node
  | CypherRelationship        // property graph relationship
  | CypherUnboundRelationship // property graph relationsip unbounded
  | CypherPath                // walk of property graph nodes/relationships
  /* Internal Types */
  | CypherStructure           // named composit type for graph types & messages
  )

// Cypher to Pony type mapping
type CypherNull    is None
type CypherBoolean is Bool
type CypherInteger is I64
type CypherFloat   is F64
type CypherString  is String


class CypherList
  var data: Array[CypherType val] val
  new val create(data': Array[CypherType val] val) =>
    data = data'
  fun string(): String iso^ =>
    let s = "TODO: CypherList string()"
    s.clone()


class CypherMap
  // var data: MapIs[CypherType val, CypherType val] val
  var data: Map[String val, CypherType val] val
  // new val create(data': MapIs[CypherType val, CypherType val] val) =>
  new val create(data': Map[String val, CypherType val] val) =>
    data = data'
  new val empty() =>
    // data = recover val MapIs[CypherType val, CypherType val] end
    data = recover val Map[String val, CypherType val] end
  fun string(): String iso^ =>
    let s = "TODO: CypherMap string()"
    s.clone()


class CypherStructure
  var signature: U8
  var fields: (Array[CypherType val] val | None)

  new val create(
    signature': U8,
    fields': (Array[CypherType val] val | None) = None)
  =>
    signature = signature'
    fields = fields'

  fun field_count(): USize =>
    match fields
    | None => 0
    | let field_array: Array[CypherType val] val => field_array.size()
    end

  fun string(): String iso^ =>
    let s = "TODO: CypherStructure string()"
    s.clone()

class CypherNode
  fun string(): String iso^ =>
    let s = "TODO: CypherNode string()"
    s.clone()

class CypherRelationship
  fun string(): String iso^ =>
    let s = "TODO: CypherRelationship string()"
    s.clone()

class CypherUnboundRelationship
  fun string(): String iso^ =>
    let s = "TODO: CypherUnboundRelationship string()"
    s.clone()

class CypherPath
  fun string(): String iso^ =>
    let s = "TODO: CypherPath string()"
    s.clone()
