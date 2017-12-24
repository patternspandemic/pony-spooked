use "logger"
use "net"


interface CypherStatement
  """
  A `CypherStatement` is an object (often a primitive) which provides a query
  string template through the `template` method. Sending such a object to be
  run by a session will result in a number of notifications being received on
  the corresponding `SessionNotify`. Many of these calls will include a
  reference to this object, indicating which statement the notification
  originated from. This is particularly helpful for determining which of
  possibly many pipelined statements a notification is in response to.
  """
  fun template(): String val


interface SessionNotify
  """ Notifications for Neo4j Bolt Sessions """
  // TODO: General SessionNotify documentation.

  // TODO: [SessionNotify]
  //    - Add Server Version notify? Or make a field of the session?
  //    - Add Bolt Version notify? Or make a field of the session?

  fun ref apply(session: Session ref): None
    """
    Called as soon as the session aquires an initialized connection to the
    server. Tell the `session` to run or transaction any number of pipelined
    `CypherStatements` with their parameters within this method. Receive the
    results of running such statements in subsequent notifications.
    """

  fun ref success(
    session: Session ref,
    statement: CypherStatement val,
    meta: CypherMap val)
  =>
    """
    Called when a `CypherStatement` was successfully run by the server.
    Parameters include the `session`, the successfully run `statement` for
    determining which of possibly many pipelined statements succeeded, and the
    `meta` data generated by running the statement.
    """
    None

  fun ref result(
    session: Session ref,
    statement: CypherStatement val,
    fields: CypherList val,
    data: CypherList val)
  =>
    """
    Called when receiving a `Streamed` result record in response to a
    successfully run `CypherStatement`. Parameters include the `session`,
    the successfully run `statement` for determining which of possibly many
    pipelined statements the record data originated from, a list of `fields`
    which both name and order the record's data, and finally the record `data`
    itself.

    Note that the entire result set might NOT be consumed through this method
    when a failure occurs during streaming. A notification of failure should
    be received in such a case. Due to this possibility, additional precautions
    such as tracking which records need / have been processed, use of ORDER BY
    and SKIP clauses in `CypherStatement` queries, and additional statements run
    in response to a failure, are required for robust handling of streamed
    results.
    """
    None

  fun ref results(
    session: Session ref,
    statement: CypherStatement val,
    fields: CypherList val,
    data: Array[CypherList val] val)
  =>
    """
    Called when receiving a `Buffered` set of result records in response to a
    successfully run `CypherStatement`. Parameters include the the `session`,
    the successfully run `statement` for determining which of possibly many
    pipelined statements the record data originated from, a list of `fields`
    which both name and order each record's data, and finally the collected
    `data` records.

    Note that this method will only be called when the entire result set has
    been buffered. If a failure occurs when results are being collected from
    the server, and the entire result set has not yet been consumed to the
    buffer, the buffer is discarded and only a notification of failure will be
    received.
    """
    None

  fun ref summary(
    session: Session ref,
    statement: CypherStatement val,
    meta: CypherMap val) =>
    """
    Called when an entire result set was consumed from the server.
    Parameters include the `session`, the `statement` from which the result set
    originated, and the `meta` data generated by running the statement and
    consumeing the result stream.
    """
    None

  fun ref failure(
    session: Session ref,
    statement: CypherStatement val,
    meta: CypherMap val) =>
    """
    Called when a failure occurs with the attempted run of a `CypherStatement`
    or during the consumption of result records produced by a successfully run
    statement. Parameters include the `session`, the `statement` from which the
    failure stems, and the `meta` data detailing the failure. Relevant keys in
    the metadata are 'code' and 'message'.
    """
    None

  fun ref ignored(
    session: Session ref,
    statement: CypherStatement val,
    meta: CypherMap val) =>
    """
    Called when a pipelined `CypherStatement` has been ignored by the server.
    This occurs when a previous statement or consumption of results encounters
    failure. Parameters include the `session`, the `statement` that has been
    ignored, and any `meta` data detailing the ignore.
    """
    None

  fun ref reset(
    session: Session ref,
    meta: CypherMap val)
  =>
    """ Called when the session has been successfully reset. """
    None

  fun ref closed() =>
    """ Called when the session has been closed. """
    None

  // service_unavailable

  // Internally used for testing, to be removed.
  fun ref _handshook(session: Session ref) => None
  fun ref _initialized(session: Session ref) => None


primitive Streamed
  """
  The type of `ReturnedResults` where each result record is streamed one by one
  to the SessionNotify as they are consumed from the server. The notification of
  the entire result set is not guaranteed due to the possibility of failure
  during streaming. As such additional precautions and logic are required for
  robust handling of streamed results.
  """

primitive Buffered
  """
  The type of `ReturnedResults` where all result records are buffered until the
  entire set has been consumed from the server, after which they are sent to the
  SessionNotify as a collection. Notification of the results collection only
  occurs with consumption of the entire result set.
  """

primitive Discarded
  """
  The type of `ReturnedResults` where all result records are declared unneeded.
  The server is told to discard any generated result stream, and no result
  records are consumed from the server.
  """

type ReturnedResults is
  ( Streamed
  | Buffered
  | Discarded
  )
  """ Options specifying how `CypherStatement` results should be handled. """


// TODO: [Session]
// - Track whether runs/txs are called after notifications, if so call flush!
// - Logging
actor Session
  let _driver: Driver tag
  let _notify: SessionNotify
  let _connection_pool: _BoltConnectionPool tag
  var _connection: (BoltConnection tag | None) = None
  var _release_on_reset: Bool = false
  let _logger: Logger[String] val

  new _create(
    driver: Driver tag,
    notify: SessionNotify iso,
    connection_pool: _BoltConnectionPool tag,
    logger: Logger[String] val)
  =>
    """"""
    _driver = driver
    _notify = consume notify
    _connection_pool = connection_pool
    _logger = logger

    // TODO: [Session] Set timeout waiting for a connection. If time out then
    //    call _notify.service_unavailable?
    _connection_pool.acquire(this)

  be _retry_acquire() =>
    """ The connection acquired from the pool was closed. Retry.  """
    _connection_pool.acquire(this)

  be _receive_connection(
    connection: BoltConnection tag,
    go_ahead: Bool)
  =>
    """ Receive a connection to the server & whether session can proceed. """
    _connection = connection
    if go_ahead then
      _go_ahead_now()
    end

  be _handshook() =>
    _notify._handshook(this)

  be _initialized() =>
    _notify._initialized(this)

  be _go_ahead() =>
    """ Proceed with the work this session should perform. """
    _go_ahead_now()

  fun ref _go_ahead_now() =>
    _notify(this)
    _flush()

  fun _flush() =>
    """ Ask the connection to send all pipelined requests. """
    match _connection
    | let c: BoltConnection tag =>
      c._flush()
    end

  fun run(
    statement: CypherStatement val,
    parameters: CypherMap val = CypherMap.empty(),
    results_as: ReturnedResults = Streamed)
  =>
    """
    Pass a CypherStatement and its parameters along for execution on
    the server. Specify whether results are `Streamed` one by one (default),
    `Buffered` and returned as a whole, or `Discarded`.
    """
    match _connection
    | let c: BoltConnection tag =>
      c._run(statement, parameters, results_as)
    end

  be _receive_streamed_result(
    statement: CypherStatement val,
    fields: CypherList val,
    result: CypherList val)
  =>
    _notify.result(this, statement, fields, result)

  be _receive_buffered_results(
    statement: CypherStatement val,
    fields: CypherList val,
    results: Array[CypherList val] val)
  =>
    _notify.results(this, statement, fields, results)

  be _success(
    statement: CypherStatement val,
    metadata: CypherMap val)
  =>
    _notify.success(this, statement, metadata)

  be _summary(
    statement: CypherStatement val,
    metadata: CypherMap val)
  =>
    _notify.summary(this, statement, metadata)

  be _failure(
    statement: CypherStatement val,
    metadata: CypherMap val)
  =>
    _notify.failure(this, statement, metadata)

  be _ignored(
    statement: CypherStatement val,
    metadata: CypherMap val)
  =>
    _notify.ignored(this, statement, metadata)

  // fun begin_transaction()
  // fun read_transaction()
  // fun write_transaction()

  // TODO: [Session] reset: Maybe NOT expose publicly on session?
  //    Though, may be useful for retries, action after errors..
  fun reset() =>
    """ Reset the session. """
    match _connection
    | let c: BoltConnection tag =>
      c._reset()
    end

  be _successfully_reset(connection: BoltConnection tag, meta: CypherMap val) =>
    if _release_on_reset then
      _notify.closed() // Session was disposed of.
      _connection_pool.release(connection)
      // _connection = None
    else
      _notify.reset(this, meta)
    end

  be _failed_reset(connection: BoltConnection tag, meta: CypherMap val) =>
    """"""
    // TODO: [Session] _failed_reset
    //    ProtocolError?, close session? Does server close?

  be _error(err: _BoltConnectionError, data: (CypherMap val | None) = None) =>
    """"""
    // TODO: [Session] _error
    //    Probably reset/dispose dep on error.
    //    Especially dispose on ProtocolError
    match err
    | InitializationError => None
    end

  be _closed() =>
    """ The connection used by the session has closed. Close the session. """
    _notify.closed()
    _connection = None
    _driver._end_session(this)

  be dispose(release_connection: Bool = true) =>
    """
    Dispose of this session. Attempt to return the connection back to the
    pool if successfully reset.
    """
    _dispose(release_connection)

  fun ref _dispose(release_connection: Bool = true) =>
      match _connection
      | let c: BoltConnection tag =>
        if release_connection then
          c._reset()
          _release_on_reset = true
        else
          c.dispose()
        end
      end
    _connection = None
    _driver._end_session(this)
