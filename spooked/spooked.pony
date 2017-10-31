use "logger"
use "net"

primitive Neo4j
  fun driver(
    address: String,
    // auth_token: AuthToken,
    connection_settings: ConnectionSettings,
    net_auth: NetAuth,
    logger: Logger[String])
    : Driver
  =>
    """
    """

primitive Spooked
  fun version_string(): String => "2017.10"
  fun agent_string(): String() => "pony-spooked"
