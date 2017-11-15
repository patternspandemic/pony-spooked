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


class CypherMap
  var data: MapIs[CypherType val, CypherType val] val
  new val create(data': MapIs[CypherType val, CypherType val] val) =>
    data = data'


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


class CypherNode

class CypherRelationship

class CypherUnboundRelationship

class CypherPath
