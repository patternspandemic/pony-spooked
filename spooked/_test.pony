use "ponytest"
use bolt_v1 = "bolt_v1"

actor Main is TestList
  new create(env: Env) =>
    PonyTest(env, this)

  new make() =>
    None

  fun tag tests(test: PonyTest) =>
    bolt_v1.Main.make().tests(test)
