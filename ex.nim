import os

when isMainModule:
  var i = 0
  for kind, path in walkDir("content"):
    inc(i)
  echo(i)