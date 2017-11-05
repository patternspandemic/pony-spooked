use "logger"
use "net"

// TODO: [Driver] Logging

actor Driver
  let _connection_pool: ConnectionPool tag
  let _logger: Logger[String] val

  new create(
    host: String val,
    port: U16 val,
    connection_settings': ConnectionSettings val,
    net_auth: NetAuth val,
    logger: Logger[String] val)
  =>
    """
    """
    _logger = logger

    if port == 0 then
      port = 7687 // default bolt port
    end

    _connection_pool =
      ConnectionPool(
        host,
        port,
        connection_settings,
        net_auth,
        logger)

  be session(notify: SessionNotify iso) =>
    Session(consume notify, _connection_pool, logger)

  be close() =>
    _connection_pool.close()
