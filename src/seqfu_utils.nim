
import sugar
import os
when not defined(windows):
  import posix

var
  debug = false

proc main_helper*(main_func: var seq[string] -> int) =
  var args: seq[string] = commandLineParams()
  when defined(windows):
    try:
      let exitStatus = main_func(args)
      quit(exitStatus)
    except IOError:
      # Broken pipe
      quit(0)
    except Exception:
      stderr.writeLine( getCurrentExceptionMsg() )
      quit(2)  
  else:
    signal(SIG_PIPE, cast[typeof(SIG_IGN)](proc(signal: cint) =
      if debug:
        stderr.write("SeqFu-debug: handled sigpipe\n")
      quit(0)
    ))

    # Handle Ctrl+C interruptions and pipe breaks
    type EKeyboardInterrupt = object of CatchableError
    proc handler() {.noconv.} =
      try:
        if getEnv("SEQFU_QUIET") == "" or debug:
          stderr.writeLine("[Quitting on Ctrl-C]")
        quit(1)
      except Exception as e:
        if debug:
          stderr.writeLine("SeqFu-debug: aborted quit: ", e.msg)
        quit(1)
      
    setControlCHook(handler)

    try:
      let exitStatus = main_func(args)
      if debug:
        stderr.writeLine("SeqFu-debug: Exiting ", exitStatus)
      quit(exitStatus)
    except EKeyboardInterrupt:
      # Ctrl-C interruption
      if debug:
        stderr.writeLine("SeqFu-debug: Keyboard Ctrl-C")
      quit(1)
    except IOError:
      # Broken pipe
      if debug:
        stderr.writeLine("SeqFu-debug: IOError")
      quit(1)
    except Exception:
      stderr.writeLine(getCurrentExceptionMsg())
      quit(2)