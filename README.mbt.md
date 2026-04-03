# IntMap

A fast mergeable int keyed immutable map implementation for MoonBit.

The implementation is based on big-endian patricia trees. This data structure performs especially well on union/intersection operations.

## Quick Start

```mbt
let base = @intmap.IntMap::empty()
  .insert(1, "one")
  .insert(-1, "minus one")

assert_eq(base.get(1), Some("one"))
assert_eq(base.get(99), None)

let extra = @intmap.IntMap::empty()
  .insert(1, "shadowed by left bias")
  .insert(2, "two")

let merged = base.union(extra)
assert_eq(merged[1], "one")
assert_eq(merged[2], "two")
assert_eq(merged.size(), 3)

let shared = base.intersection(extra)
assert_eq(shared.iter().collect(), [(1, "one")])
```

## Notes

+ `union` and `intersection` are left-biased: when the same key exists in both inputs, the value from the left map wins.
+ `iter`, `iter2`, `keys`, and `values` follow the tree's natural order, which is based on the unsigned representation of keys. In practice that means negative keys are visited after non-negative ones.
+ All update operations are immutable and preserve structure aggressively, so unchanged subtrees can be shared between results.

+ Chris Okasaki and Andy Gill, "Fast Mergeable Integer Maps", Workshop on ML, September 1998, pages 77-86
+ Jan Midtgaard, "QuickChecking Patricia Trees"
