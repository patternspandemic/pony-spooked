use "logger"
use "net"


interface CypherStatement
  """"""
  fun template(): String val


interface SessionNotify
  """ Notifications for Neo4j Bolt Sessions """

  // TODO: [SessionNotify]
  //    - Add Server Version notify? Or make a field of the session?
  //    - Add Bolt Version notify? Or make a field of the session?

  fun ref apply(session: Session ref): None
    """
    Called as soon as the session aquires an initialized connection to the
    server. Tell the session to run or transaction any number of pipelined
    CypherStatements and their parameters through this method. Receive the
    results of such statements in subsequent notifications.
    """

  fun ref success(
    session: Session ref,
    statement: CypherStatement val,
    meta: CypherMap val)
  =>
    """
    Called when a CypherStatement was successfully run by the server. Parameters
    include the successfully run CypherStatement for determining which of
    possibly many pipelined statements succeeded, and the metadata generated by
    the run statement.
    """
    None

  fun ref result(
    session: Session ref,
    statement: CypherStatement val,
    fields: CypherList val,
    data: CypherList val)
  =>
    """
    Called when receiving a streamed result record from a successfully run
    CypherStatement. Parameters include the successfully run CypherStatement
    for determining which of possibly many pipelined statements the record data
    originated from, a list of fields which both name and order the record's
    data, and finally the record data itself.

    Note that when results are streamed, consumption of a result set may be
    incomplete due to failure that may occur durring streaming. If processing
    of individual records is dependent on receipt of the whole, choose to
    receive a query results as a Buffered whole instead, if resources permit it.
    A notification of failure should still be received in such a case.
    """
    None

  fun ref results(
    session: Session ref,
    statement: CypherStatement val,
    fields: CypherList val,
    data: Array[CypherList val] val)
  =>
    """
    Called when receiving a buffered set of result records from a successfully
    run CypherStatement. Parameters include the successfully run CypherStatement
    for determining which of possibly many pipelined statements the record data
    originated from, a list of fields which both name and order each record's
    data, and finally the collected record data itself.

    Note that when results are buffered, if the entire result set has not been
    consumed and a failure occurs, any buffered results are discarded, and
    notification will include only report of failure without any results.
    """
    None

  fun ref summary(
    session: Session ref,
    statement: CypherStatement val,
    meta: CypherMap val) =>
    """
    
    """
    None

  fun ref failure(
    session: Session ref,
    statement: CypherStatement val,
    meta: CypherMap val) =>
    """"""
    None

  fun ref ignored(
    session: Session ref,
    statement: CypherStatement val,
    meta: CypherMap val) =>
    """"""
    None

  fun ref reset(session: Session ref) =>
    """"""
    None

  fun ref closed() =>
    """"""
    None

  // service_unavailable

  // Internally used for testing, to be removed.
  fun ref _handshook(session: Session ref) => None
  fun ref _initialized(session: Session ref) => None


primitive Streamed
primitive Buffered
primitive Discarded

type ReturnedResults is
  ( Streamed
  | Buffered
  | Discarded
  )


// TODO: [Session] Logging
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
      _go_ahead()
    end

  be _handshook() =>
    _notify._handshook(this)

  be _initialized() =>
    _notify._initialized(this)

  be _go_ahead() =>
    """ Proceed with the work this session should perform. """
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

  be _successfully_reset(connection: BoltConnection tag) =>
    if _release_on_reset then
      _notify.closed() // Session was disposed of.
      _connection_pool.release(connection)
      // _connection = None
    else
      _notify.reset(this)
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
