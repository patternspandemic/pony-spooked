use "logger"
use "net"
use http = "net/http"

// TODO: [Neo4j.driver()] Documentation

primitive Neo4j
  fun driver(
    url: String val,
    connection_settings: ConnectionSettings val,
    net_auth: NetAuth val,
    logger: Logger[String] val)
    : Driver tag ?
  =>
    """
    """
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
      Driver._create(
        valid_url.scheme,
        valid_url.host,
        valid_url.port,
        connection_settings._config(),
        net_auth,
        logger)

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
