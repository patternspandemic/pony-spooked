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


class _Configuration
  /* Authentication */
  var auth: PackStreamMap //BasicAuthToken
  var protocol_version: U32 = Spooked.default_protocol_version()
  var user_agent: String =
    Spooked.agent_string() + "/" + Spooked.version_string()
  /* Encryption */
  var encrypted: Bool = true
  var trust: TrustStrategy = TrustAllCertificates
  var trusted_certificates: (FilePath | None) = None
  /* Connection Pool Management */
  var max_connection_lifetime_nanos: U64 = 0
  var max_connection_pool_size: USize = 0
  var connection_acquisition_timeout_nanos: U64 = 0
  /* Connection Establishment */
  var connection_timeout_nanos: U64 = 0
  /* Routing */
  var load_balancing_strategy: LoadBalanceStrategy = LeastConnected
  /* Retry Behavior */
  var max_retry_time_nanos: U64 = 0
  var init_request: Request

  new create(auth': PackStreamMap, init_request': Request) =>
    auth = auth'
    init_request = init_request'


class ConnectionSettings
  let config: _Configuration

  new create(
    user: String,
    password: String,
    realm: (String | None) = None,
    protocol_version: U32 = Spooked.default_protocol_version(),
    user_agent: String =
      Spooked.agent_string() + "/" + Spooked.version_string(),
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
    let auth_map = PackStreamMap
    auth_map.data("scheme") = "basic"
    auth_map.data("principal") = user
    auth_map.data("credentials") = password
    match realm
    | let value: String => auth_map.data("realm") = value
    end

    config =
      _Configuration(auth_map, Request(INIT.string(), InitMessage(user_agent, auth_map)))
    // config.auth = auth_map
    config.user_agent = user_agent
    config.encrypted = encrypted
    config.trust = trust
    config.trusted_certificates = trusted_certificates
    config.max_connection_lifetime_nanos =
      Nanos.from_millis(max_connection_lifetime_ms)
    config.max_connection_pool_size = max_connection_pool_size
    config.connection_acquisition_timeout_nanos =
      Nanos.from_millis(connection_acquisition_timeout_ms)
    config.connection_timeout_nanos =
      Nanos.from_millis(connection_timeout_ms)
    config.load_balancing_strategy = load_balancing_strategy
    config.max_retry_time_nanos =
      Nanos.from_millis(max_retry_time_ms)

    // config.init_request = Request(InitMessage(user_agent', auth'))


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
