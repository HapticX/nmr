import
  std/asyncdispatch,
  std/httpclient,
  std/terminal,
  std/os,

  taskpools


proc waitAndProgress*[T](action: string, fut: Future[T], color: ForegroundColor = fgCyan) {.async.} =
  var
    i = 0
    progresses = @["/", "-", "\\", "|"]
  while not fut.finished and not fut.failed:
    styledEcho color, "[", action, "] ", fgWhite, progresses[i]
    if i == progresses.len-1:
      i = 0
    else:
      inc i
    await sleepAsync(50)
    stdout.flushFile()
    stdout.cursorUp()
  styledEcho fgCyan, "[", action, "]", fgGreen, " Completed"


proc waitAndProgress*[T](action: string, flow: FlowVar[T], color: ForegroundColor = fgCyan) =
  var
    i = 0
    progresses = @["/", "-", "\\", "|"]
  while not flow.isReady:
    styledEcho color, "[", action, "] ", fgWhite, progresses[i]
    if i == progresses.len-1:
      i = 0
    else:
      inc i
    sleep(20)
    stdout.flushFile()
    stdout.cursorUp()
  styledEcho fgCyan, "[", action, "]", fgGreen, " Completed"


proc gather*[T](futs: openarray[Future[T]]): auto =
  when T is void:
    var
      retFuture = newFuture[void]("asyncdispatch.gather")
      completedFutures = 0

    let totalFutures = len(futs)

    for fut in futs:
      fut.addCallback proc (f: Future[T]) =
        inc(completedFutures)
        if not retFuture.finished:
          if f.failed:
            retFuture.fail(f.error)
          else:
            if completedFutures == totalFutures:
              retFuture.complete()

    if totalFutures == 0:
      retFuture.complete()

    return retFuture

  else:
    var
      retFuture = newFuture[seq[T]]("asyncdispatch.gather")
      retValues = newSeq[T](len(futs))
      completedFutures = 0

    for i, fut in futs:
      proc setCallback(i: int) =
        fut.addCallback proc (f: Future[T]) =
          inc(completedFutures)
          if not retFuture.finished:
            if f.failed:
              retFuture.fail(f.error)
            else:
              retValues[i] = f.read()

              if completedFutures == len(retValues):
                retFuture.complete(retValues)

      setCallback(i)

    if retValues.len == 0:
      retFuture.complete(retValues)

    return retFuture
