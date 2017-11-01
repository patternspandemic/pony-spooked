use "buffered"
use "files"
use "time"

// primitive ServiceUnavailable
// primitive SessionExpired
// primitive ProtocolError

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


type BasicAuthToken is
  ( String // scheme
  , String // principal
  , String // credentials
  , (String | None) // realm or None
  )


primitive TrustAllCertificates
primitive TrustOnFirstUse
primitive TrustSignedCertificates
primitive TrustCustomCASignedCertificates
primitive TrustSystemCASignedCertificates

type TrustStrategy is
  ( TrustAllCertificates
  | TrustOnFirstUse
  | TrustSignedCertificates
  | TrustCustomCASignedCertificates
  | TrustSystemCASignedCertificates
  )


primitive LeastConnected
primitive RoundRobin

type LoadBalanceStrategy is (LeastConnected | RoundRobin)

class ConnectionSettings
  /* Authentication */
  let auth': PackStreamMap //BasicAuthToken
  let user_agent': String

  /* Encryption */
  let encrypted': Bool
  let trust': TrustStrategy
  let trusted_certificates': (FilePath | None)

  /* Connection Pool Management */
  let max_connection_lifetime_nanos': U64 // ?
  let max_connection_pool_size': USize
  let connection_acquisition_timeout_nanos': U64 // ?

  /* Connection Establishment */
  let connection_timeout_nanos': U64 // ?

  /* Routing */
  // let load_balancing_strategy': ?

  /* Retry Behavior */
  let max_retry_time_nanos': U64 // ?

  let init_request': Request

  new create(
    user: String,
    password: String,
    realm: (String | None) = None,
    user_agent: String = Spooked.agent_string + "/" + Spooked.version_string,
    encrypted: Bool = true,
    trust: TrustStrategy = TrustAllCertificates,
    trusted_certificates: (FilePath | None) = None,
    max_connection_lifetime_ms: U64 = 3_600_000, // 1 hour
    max_connection_pool_size: USize = 0, // no limit
    connection_acquisition_timeout_ms: U64 = 60_000, // 1 minute
    connection_timeout_ms: U64 = 0, // no timeout
    load_balancing_strategy: LoadBalanceStrategy = LeastConnected,
    max_retry_time_ms: U64 = 15_000 // 15 seconds, 0 -> no retry
    )
  =>
    auth' = PackStreamMap
    auth'.data("scheme") = "basic"
    auth'.data("principal") = user
    auth'.data("credentials") = password
    match realm
    | let value: String => auth'data("realm") = value
    end
    user_agent' = user_agent
    encrypted' = encrypted
    trust' = trust
    trusted_certificates' = trusted_certificates
    max_connection_lifetime_nanos' =
      Nanos.from_millis(max_connection_lifetime_ms)
    max_connection_pool_size' = max_connection_pool_size
    connection_acquisition_timeout_nanos' =
      Nanos.from_millis(connection_acquisition_timeout_ms)
    connection_timeout_nanos' =
      Nanos.from_millis(connection_timeout_ms)
    load_balancing_strategy' = load_balancing_strategy
    max_retry_time_nanos' =
      Nanos.from_millis(max_retry_time_ms)

    init_request = Request(INIT, [user_agent', auth'])
