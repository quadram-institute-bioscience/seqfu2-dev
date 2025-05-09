const NimblePkgVersion {.strdefine.} = "<SEQFU_DEV>"

proc version*(): string =
  if len(NimblePkgVersion) == 0:
    return "0.0.0"
  else:
    return NimblePkgVersion