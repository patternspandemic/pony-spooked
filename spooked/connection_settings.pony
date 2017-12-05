use "collections"
use "files"
use "time"

class val ConnectionSettings
  """
  Public side Neo4j driver configuration.
  """
  let _config': Configuration val

  new val create(
    user: String,
    password: String,
    realm: (String | None) = None,
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
    var auth_map =
      recover trn Map[String val, CypherType val] end
    auth_map("scheme") = "basic"
    auth_map("principal") = user
    auth_map("credentials") = password
    match realm
    | let value: String => auth_map("realm") = value
    end

    let config: Configuration trn =
      config.create(consume auth_map)
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

    _config' = consume config

  fun _config(): Configuration val =>
    _config'


class Configuration
  """
  Internal Neo4j driver configuration.
  """
  /* Authentication */
  var auth: CypherMap val
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
  /* Cached INIT Request 
  var _init_request: (_Request val | None) = None */

  new trn create(auth': Map[String val, CypherType val] val) =>
    auth = CypherMap(auth')


// Trust Strategy Options
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

// Load Balance Strategy Options
primitive LeastConnected
primitive RoundRobin

type LoadBalanceStrategy is (LeastConnected | RoundRobin)
