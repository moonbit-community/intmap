// Big-endian Patricia Tree

///|
type Key = Int

///|
fn Key::as_prefix(self : Key) -> Prefix {
  self.reinterpret_as_uint()
}

///|
type Prefix = UInt

///|
type Mask = UInt // Mask must be 2 ^ n

///|
/// A canonical big-endian Patricia tree:
/// - `prefix` stores the common high bits shared by every key below a branch.
/// - `mask` marks the highest bit where the two child subtrees differ.
/// - branch nodes never keep `Empty` children; use `IntMap::branch` to rebuild them.
enum IntMap[T] {
  Empty
  Leaf(key~ : Key, value~ : T)
  Branch(prefix~ : Prefix, mask~ : Mask, left~ : IntMap[T], right~ : IntMap[T])
} derive(Show, Debug)

///|
pub fn[T] IntMap::empty() -> IntMap[T] {
  IntMap::Empty
}

///|
/// Smart constructor used internally to preserve the canonical representation.
/// Recursive operations can temporarily drop one side to `Empty`; when that
/// happens we collapse the branch instead of storing redundant structure.
fn[T] IntMap::branch(
  prefix~ : Prefix,
  mask~ : Mask,
  left~ : IntMap[T],
  right~ : IntMap[T],
) -> IntMap[T] {
  match (left, right) {
    // One subtree disappeared, so the surviving child already is the result.
    (Empty, t) => t
    // Symmetric case of the above.
    (t, Empty) => t
    // Only keep an explicit branch when both children are non-empty.
    (_, _) => IntMap::Branch(prefix~, mask~, left~, right~)
  }
}

///|
pub fn[T] IntMap::is_empty(self : IntMap[T]) -> Bool {
  match self {
    Empty => true
    _ => false
  }
}

///|
pub fn[T] IntMap::size(self : IntMap[T]) -> Int {
  match self {
    Empty => 0
    Leaf(..) => 1
    Branch(..) as br_node => br_node.left.size() + br_node.right.size()
  }
}

///|
fn UInt::to_hex_str(self : UInt) -> String {
  let mut n = self
  let table = [
    '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B', 'C', 'D', 'E', 'F',
  ]
  let buf = @buffer.new(size_hint=8)
  for i = 0; i < 8; i = i + 1 {
    let r = n & 0x0000000F
    buf.write_char(table[r.reinterpret_as_int()])
    n = n >> 4
  } nobreak {
    buf.contents().to_unchecked_string().rev()
  }
}

///|
fn Int::to_hex_str(self : Int) -> String {
  self.reinterpret_as_uint().to_hex_str()
}

///|
test "int to hex string" {
  inspect((0).to_hex_str(), content="00000000")
  inspect((1).to_hex_str(), content="00000001")
  inspect((16).to_hex_str(), content="00000010")
  inspect(@int.MAX_VALUE.to_hex_str(), content="7FFFFFFF")
  inspect(@int.MIN_VALUE.to_hex_str(), content="80000000")
  inspect((-2).to_hex_str(), content="FFFFFFFE")
  inspect((-1).to_hex_str(), content="FFFFFFFF")
  inspect((1 << 16).to_hex_str(), content="00010000")
  inspect((2147483647).to_hex_str(), content="7FFFFFFF")
}

///|
test "unsigned int to hex string" {
  inspect(1U.to_hex_str(), content="00000001")
}

///|
fn zero(key : UInt, mask~ : Mask) -> Bool {
  (key & mask) == 0
}

///|
/// In a big-endian Patricia tree the branching bit is the highest differing bit.
/// Clearing that bit and every lower bit leaves the shared prefix for the subtree.
fn get_prefix(key : UInt, mask~ : UInt) -> Prefix {
  (key | (mask - 1)) & mask.lnot()
}

///|
fn match_prefix(key~ : UInt, prefix~ : Prefix, mask~ : Mask) -> Bool {
  get_prefix(key, mask~) == prefix
}

///|
/// Returns the highest differing bit between two prefixes.
fn gen_mask(p1 : Prefix, p2 : Prefix) -> Mask {
  let unsigned_int_width = 32
  1U << (unsigned_int_width - 1 - p1.lxor(p2).clz())
}

///|
/// Create the smallest branch that can contain two trees with disjoint prefixes.
fn[T] join(
  p1 : Prefix,
  t1 : IntMap[T],
  p2 : Prefix,
  t2 : IntMap[T],
) -> IntMap[T] {
  let mask = gen_mask(p1, p2)
  if zero(p1, mask~) {
    // `p1` falls on the zero side of the branching bit, so it becomes the left child.
    Branch(prefix=get_prefix(p1, mask~), mask~, left=t1, right=t2)
  } else {
    // `p1` falls on the one side, so the children must be swapped.
    Branch(prefix=get_prefix(p1, mask~), mask~, left=t2, right=t1)
  }
}

///|
/// Insert a key/value pair, combining with the existing value on collisions.
/// `combine(new_value, old_value)` receives the inserted value first.
pub fn[T] IntMap::insert_with(
  self : IntMap[T],
  combine~ : (T, T) -> T,
  key : Key,
  value : T,
) -> IntMap[T] {
  match self {
    // Inserting into an empty tree creates a singleton leaf.
    Empty => Leaf(key~, value~)
    Leaf(..) as leaf =>
      if leaf.key == key {
        // Duplicate key: stay at the leaf and combine the two values.
        Leaf(key~, value=combine(value, leaf.value))
      } else {
        // Different key: split this leaf into a new branch containing both leaves.
        join(key.as_prefix(), Leaf(key~, value~), leaf.key.as_prefix(), leaf)
      }
    Branch(..) as br_node =>
      if match_prefix(
          key=key.reinterpret_as_uint(),
          prefix=br_node.prefix,
          mask=br_node.mask,
        ) {
        if zero(key.as_prefix(), mask=br_node.mask) {
          // The key belongs to the left subtree; recurse only there.
          Branch(
            prefix=br_node.prefix,
            mask=br_node.mask,
            left=br_node.left.insert_with(combine~, key, value),
            right=br_node.right,
          )
        } else {
          // The key belongs to the right subtree; recurse only there.
          Branch(
            prefix=br_node.prefix,
            mask=br_node.mask,
            left=br_node.left,
            right=br_node.right.insert_with(combine~, key, value),
          )
        }
      } else {
        // The key does not belong under this branch prefix; join from above.
        join(key.as_prefix(), Leaf(key~, value~), br_node.prefix, br_node)
      }
  }
}

///|
/// Insert a key/value pair or replace the previous value for the same key.
pub fn[T] IntMap::insert(self : IntMap[T], key : Key, value : T) -> IntMap[T] {
  self.insert_with(combine=(left, _) => left, key, value)
}

///|
/// Remove a key from the map and return the updated tree.
/// When the key cannot exist below the current branch, we stop immediately and
/// reuse the original subtree to preserve structural sharing.
pub fn[T] IntMap::remove(self : IntMap[T], key : Key) -> IntMap[T] {
  fn go(tree : IntMap[T]) -> (Bool, IntMap[T]) {
    match tree {
      // Nothing to remove.
      Empty => (false, tree)
      Leaf(..) as leaf =>
        if leaf.key == key {
          // Exact hit: remove the leaf entirely.
          (true, Empty)
        } else {
          // Different key: keep the original leaf for maximal sharing.
          (false, tree)
        }
      Branch(prefix~, mask~, left~, right~) =>
        // A branch prefix is only a compressed summary, not a concrete key.
        // We must reject prefix mismatches before deciding which side to descend.
        if !match_prefix(key=key.as_prefix(), prefix~, mask~) {
          // The key cannot appear anywhere below this branch.
          (false, tree)
        } else if zero(key.as_prefix(), mask~) {
          // select left subtree
          let (changed, left) = go(left)
          if changed {
            // The left subtree changed, so rebuild and canonicalize this branch.
            let tree = IntMap::branch(prefix~, mask~, left~, right~)
            (true, tree)
          } else {
            // No change below; reuse the original node.
            (false, tree)
          }
        } else {
          // select right subtree
          let (changed, right) = go(right)
          if changed {
            // The right subtree changed, so rebuild and canonicalize this branch.
            let tree = IntMap::branch(prefix~, mask~, left~, right~)
            (true, tree)
          } else {
            // No change below; reuse the original node.
            (false, tree)
          }
        }
    }
  }

  go(self).1
}

///|
test "IntMap::remove() keeps physical equality when no change" {
  let mut foo = IntMap::Empty
  foo = foo.insert(1, "one")
  foo = foo.insert(2, "two")
  foo = foo.insert(3, "three")
  assert_true(physical_equal(foo.remove(-1), foo))
}

///|
/// Look up a key. Branch selection is valid only after the compressed prefix
/// has been checked with `match_prefix`.
pub fn[T] IntMap::get(self : IntMap[T], k : Key) -> T? {
  match self {
    // Empty subtree means the key is absent.
    Empty => None
    Leaf(..) as leaf =>
      if leaf.key == k {
        // Leaves store one concrete key/value pair.
        Some(leaf.value)
      } else {
        None
      }
    Branch(..) as br_node =>
      if !match_prefix(
          key=k.as_prefix(),
          prefix=br_node.prefix,
          mask=br_node.mask,
        ) {
        // The key falls outside this compressed prefix.
        None
      } else if zero(k.as_prefix(), mask=br_node.mask) {
        // Matching prefix, zero branch bit: continue on the left.
        br_node.left.get(k)
      } else {
        // Matching prefix, one branch bit: continue on the right.
        br_node.right.get(k)
      }
  }
}

///|
/// Indexing variant of `get`; aborts when the key is absent.
pub fn[T] IntMap::op_get(self : IntMap[T], key : Key) -> T {
  match self.get(key) {
    None => abort("IntMap::op_get: invalid key \{key}")
    Some(value) => value
  }
}

///|
test "intmap insert and lookup" {
  let mut foo = IntMap::Empty
  fn prop_insert_lookup_identity(i : Int) -> Bool {
    foo = foo.insert(i, i)
    foo[i] == i
  }

  @qcheck.quick_check(@qcheck.Arrow(prop_insert_lookup_identity))
}

///|
test "edge case" {
  let mut foo = IntMap::Empty
  foo = foo.insert(@int.MIN_VALUE, "min")
  foo = foo.insert(@int.MAX_VALUE, "max")
  foo = foo.insert(0, "zero")
  foo = foo.insert(-1, "neg1")
  foo = foo.insert(1, "pos1")
  inspect(foo[@int.MIN_VALUE], content="min")
  inspect(foo[@int.MAX_VALUE], content="max")
  inspect(foo[0], content="zero")
  inspect(foo[-1], content="neg1")
  inspect(foo[1], content="pos1")
}

///|
test "IntMap::get() and IntMap::remove() reject prefix mismatch" {
  let bogus : IntMap[String] = Branch(
    prefix=0U,
    mask=2U,
    left=Leaf(key=0, value="zero"),
    right=Leaf(key=1, value="one"),
  )
  assert_eq(bogus.get(0), None)
  assert_eq(bogus.get(1), None)
  assert_true(physical_equal(bogus.remove(0), bogus))
  assert_true(physical_equal(bogus.remove(1), bogus))
}

///|
test "IntMap::intersection() canonicalizes empty result" {
  let lhs = IntMap::Empty.insert(-2, "lhs:-2").insert(0, "lhs:0")
  let rhs = IntMap::Empty.insert(-1, "rhs:-1").insert(1, "rhs:1")
  let inter = lhs.intersection(rhs)
  assert_true(inter.is_empty())
  assert_eq(inter.size(), 0)
  match inter {
    Empty => ()
    _ => abort("expected canonical empty intersection")
  }
}

///|
test "IntMap::intersection() canonicalizes singleton result" {
  let lhs = IntMap::Empty.insert(-2, "lhs:-2").insert(0, "lhs:0")
  let rhs = IntMap::Empty.insert(-1, "rhs:-1").insert(0, "rhs:0")
  let inter = lhs.intersection(rhs)
  assert_false(inter.is_empty())
  assert_eq(inter.size(), 1)
  assert_eq(inter.get(0), Some("lhs:0"))
  match inter {
    Leaf(key~, value~) => {
      assert_eq(key, 0)
      assert_eq(value, "lhs:0")
    }
    _ => abort("expected canonical singleton intersection")
  }
}

///|
/// Merge two maps, combining values that share the same key.
/// `combine(left, right)` receives the value from the left map first.
pub fn[T] IntMap::union_with(
  combine~ : (T, T) -> T,
  left : IntMap[T],
  right : IntMap[T],
) -> IntMap[T] {
  fn go(left : IntMap[T], right : IntMap[T]) -> IntMap[T] {
    match (left, right) {
      // Nothing to merge from the right.
      (t, Empty) => t
      // Nothing to merge from the left.
      (Empty, t) => t
      // Reduce the problem to inserting one left entry into the right tree.
      (Leaf(key~, value~), t) => t.insert_with(combine~, key, value)
      (t, Leaf(key~, value~)) => {
        // Symmetric single-leaf case; flip the combiner to preserve left bias.
        let combine = fn(x, y) { combine(y, x) }
        t.insert_with(combine~, key, value)
      }
      (
        Branch(prefix=p, mask=m, left=s_left, right=s_right) as s,
        Branch(prefix=q, mask=n, left=t_left, right=t_right) as t,
      ) =>
        if m == n && p == q {
          // The trees have the same prefix. Merge the subtrees directly.
          // `Branch` is safe here because neither recursive result can be empty.
          Branch(
            prefix=p,
            mask=m,
            left=go(s_left, t_left),
            right=go(s_right, t_right),
          )
        } else if m > n && match_prefix(key=q, prefix=p, mask=m) {
          // `t` lives entirely under one child of `s`; recurse only into that side.
          if zero(q, mask=m) {
            // `t` falls into the left child of `s`.
            Branch(prefix=p, mask=m, left=go(s_left, t), right=s_right)
          } else {
            // `t` falls into the right child of `s`.
            Branch(prefix=p, mask=m, left=s_left, right=go(s_right, t))
          }
        } else if m < n && match_prefix(key=p, prefix=q, mask=n) {
          // Symmetric case: `s` lives entirely under one child of `t`.
          if zero(p, mask=n) {
            // `s` falls into the left child of `t`.
            Branch(prefix=q, mask=n, left=go(s, t_left), right=t_right)
          } else {
            // `s` falls into the right child of `t`.
            Branch(prefix=q, mask=n, left=t_left, right=go(s, t_right))
          }
        } else {
          // The trees split at this level, so create a new parent branch.
          join(p, s, q, t)
        }
    }
  }

  go(left, right)
}

///|
/// Keep only keys that appear in both maps and combine their values.
/// `combine(left, right)` receives the value from the left map first.
pub fn[T] IntMap::intersection_with(
  combine~ : (T, T) -> T,
  left : IntMap[T],
  right : IntMap[T],
) -> IntMap[T] {
  fn go(left : IntMap[T], right : IntMap[T]) -> IntMap[T] {
    match (left, right) {
      // Intersection with an empty tree is always empty.
      (_, Empty) => Empty
      // Symmetric empty case.
      (Empty, _) => Empty
      (Leaf(key~, value~), t) =>
        match t.get(key) {
          // This key is missing from the other tree.
          None => Empty
          // This key exists on both sides, so keep one leaf.
          Some(v) => Leaf(key~, value=combine(value, v))
        }
      (t, Leaf(key~, value~)) =>
        match t.get(key) {
          // This key is missing from the other tree.
          None => Empty
          // This key exists on both sides, so keep one leaf.
          Some(v) => Leaf(key~, value=combine(v, value))
        }
      (
        Branch(prefix=p, mask=m, left=s_left, right=s_right) as s,
        Branch(prefix=q, mask=n, left=t_left, right=t_right) as t,
      ) =>
        if m == n && p == q {
          // Intersections can delete an entire side, so rebuild with the smart
          // constructor to keep the result canonical.
          IntMap::branch(
            prefix=p,
            mask=m,
            left=go(s_left, t_left),
            right=go(s_right, t_right),
          )
        } else if m > n && match_prefix(key=q, prefix=p, mask=m) {
          // `t` can intersect only one child of `s`.
          if zero(q, mask=m) {
            // `t` sits under the left child of `s`.
            go(s_left, t)
          } else {
            // `t` sits under the right child of `s`.
            go(s_right, t)
          }
        } else if m < n && match_prefix(key=p, prefix=q, mask=n) {
          // Symmetric case: `s` can intersect only one child of `t`.
          if zero(p, mask=n) {
            // `s` sits under the left child of `t`.
            go(s, t_left)
          } else {
            // `s` sits under the right child of `t`.
            go(s, t_right)
          }
        } else {
          // Disjoint prefixes mean there are no shared keys below.
          Empty
        }
    }
  }

  go(left, right)
}
