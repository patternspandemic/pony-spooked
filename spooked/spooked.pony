use "logger"
use "net"
use http = "net/http"

primitive Neo4j
  fun driver(
    url: String,
    connection_settings: ConnectionSettings,
    net_auth: NetAuth,
    logger: Logger[String])
    : Driver ?
  =>
    var maybe_url: (http.URL val | None) = None

    try
      maybe_url = http.URL.valid(url)?
    else
      logger(Error) and logger.log(
        "[Spooked] Error: Neo4j server URL not a valid URL: " + url)
      error
    end

    let valid_url = maybe_url as http.URL

    match valid_url.scheme
    | "bolt" =>
      try
        let net_address: NetAddress val =
          DNS(net_auth, valid_url.host, valid_url.port.string()).apply(0)?
        Driver(net_auth, net_address, connection_settings, logger)
      else
        logger(Error) and logger.log(
          "[Spooked] Error: A net address could not be resolved for " +
          valid_url.host)
          error
      end

    | "bolt+routing" =>
      logger(Error) and logger.log(
        "[Spooked] Error: bolt+routing not yet implemented.")
      error

    | let scheme: String =>
      logger(Error) and logger.log(
        "[Spooked] Error: Unsupported scheme: " + scheme)
      error
    end


primitive Spooked
  fun agent_string(): String => "pony-spooked"
  fun version_string(): String => "2017.10"
