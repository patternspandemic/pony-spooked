
primitive INIT
  fun apply(): U8 => 0x01
  fun string(): String => "INIT"

primitive InitMessage
  fun apply(
    client_name: String,
    auth_token: PackStreamMap val)
    : PackStreamStructure val
  =>
    PackStreamStructure(INIT(), [client_name; auth_token])


primitive RUN
  fun apply(): U8 => 0x10
  fun string(): String => "RUN"

primitive RunMessage
  fun apply(
    statement: String,
    parameters: PackStreamMap val)
    : PackStreamStructure val
  =>
    PackStreamStructure(RUN(), [statement; parameters])


primitive DISCARDALL
  fun apply(): U8 => 0x2F
  fun string(): String => "DISCARD_ALL"

primitive DiscardAllMessage
  fun apply(): PackStreamStructure val =>
    PackStreamStructure(DISCARDALL())


primitive PULLALL
  fun apply(): U8 => 0x3F
  fun string(): String => "PULL_ALL"

primitive PullAllMessage
  fun apply(): PackStreamStructure val =>
    PackStreamStructure(PULLALL())


primitive ACKFAILURE
  fun apply(): U8 => 0x0E
  fun string(): String => "ACKFAILURE"

primitive AckFailureMessage
  fun apply(): PackStreamStructure val =>
    PackStreamStructure(ACKFAILURE())


primitive RESET
  fun apply(): U8 => 0x0F
  fun string(): String => "RESET"

primitive ResetMessage
  fun apply(): PackStreamStructure val =>
    PackStreamStructure(RESET())


primitive RECORD
  fun apply(): U8 => 0x71
  fun string(): String => "RECORD"

// primitive RecordMessage


primitive SUCCESS
  fun apply(): U8 => 0x70
  fun string(): String => "SUCCESS"

// primitive SuccessMessage


primitive FAILURE
  fun apply(): U8 => 0x7F
  fun string(): String => "FAILURE"

// primitive FailureMessage


primitive IGNORED
  fun apply(): U8 => 0x7E
  fun string(): String => "IGNORED"

// primitive IgnoredMessage
