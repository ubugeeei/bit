///|
let cmd_bit_wbtest_env_lock : @async.Semaphore = @async.Semaphore::new(
  1,
  initial_value=1,
)

///|
fn init {
  ignore(cmd_bit_wbtest_env_lock)
}
