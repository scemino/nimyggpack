const DELTA = 0x9e3779b9'u32

proc mx(sum, y, z: uint32, p, e: uint, k: openArray[uint32]): uint32 =
    result = ((z shr 5 xor y shl 2) + (y shr 3 xor z shl 4)) xor ((sum xor y) + (k[(p and 3) xor e] xor z))

proc btDecrypt*(v: var openArray[uint32], key: openArray[uint32]) =
  var sum, y, z: uint32
  var p, rounds, e: uint32
  let n = v.len
  rounds = (6 + 52 div n).uint32
  sum = (rounds * DELTA).uint32
  y = v[0]
  for i in 0..<rounds:
    e = (sum shr 2) and 3
    for p in countdown((n - 1).uint, 1):
      z = v[p - 1]
      v[p] -= mx(sum, y, z, p, e, key)
      y = v[p]
    z = v[n - 1]
    v[0] -= mx(sum, y, z, p, e, key)
    y = v[0]
    sum -= DELTA

proc btEncrypt*(v: var openArray[uint32], key: openArray[uint32]) =
  var sum, y, z: uint32
  var p, rounds, e: uint32
  let n = v.len.uint32
  if n > 1:
    rounds = (6 + 52 div n).uint32
    sum = 0
    z = v[n - 1]
    for i in 0..<rounds:
      sum += DELTA
      e = (sum shr 2) and 3
      for p in 0'u..<(n - 1).uint32:
        y = v[p + 1]
        v[p] += mx(sum, y, z, p, e, key)
        z = v[p]
      p = n - 1
      y = v[0]
      v[n - 1] += mx(sum, y, z, p, e, key)
      z = v[n - 1]