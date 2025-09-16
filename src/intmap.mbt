// LAST UPDATE: 2025/6/2
// create by: myfreess@github.com
// Big-endian Patricia Tree

///|
typealias Int as Key

///|
typealias Int as Prefix

///|
typealias UInt as Mask // Mask must be 2 ^ n

///|
enum IntMap[T] {
  Empty
  Leaf(key~ : Key, value~ : T)
  Branch(prefix~ : Prefix, mask~ : Mask, left~ : IntMap[T], right~ : IntMap[T])
} derive(Show)

///|
fn to_hex_string_(n : UInt) -> String {
  let mut n = n
  let table = [
    '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B', 'C', 'D', 'E', 'F',
  ]
  let buf = @buffer.new(size_hint=8)
  for i = 0; i < 8; i = i + 1 {
    let r = n & 0x0000000F
    buf.write_char(table[r.reinterpret_as_int()])
    n = n >> 4
  } else {
    buf.contents().to_unchecked_string().rev()
  }
}

///|
fn to_hex_string(n : Int) -> String {
  to_hex_string_(n.reinterpret_as_uint())
}

///|
test "int to hex string" {
  inspect(to_hex_string(0), content="00000000")
  inspect(to_hex_string(1), content="00000001")
  inspect(to_hex_string(16), content="00000010")
  inspect(to_hex_string(@int.max_value), content="7FFFFFFF")
  inspect(to_hex_string(@int.min_value), content="80000000")
  inspect(to_hex_string(-2), content="FFFFFFFE")
  inspect(to_hex_string(-1), content="FFFFFFFF")
  inspect(to_hex_string(1 << 16), content="00010000")
  inspect(to_hex_string(2147483647), content="7FFFFFFF")
}

///|
test "unsigned int to hex string" {
  inspect(to_hex_string_(1U), content="00000001")
}

///|
fn zero(k : Key, m : Mask) -> Bool {
  let k = k.reinterpret_as_uint()
  (k & m) == 0
}

///|
fn get_prefix_(k : UInt, m : UInt) -> Prefix {
  k.lor(m - 1).land(m.lnot()).reinterpret_as_int()
}

///|
fn get_prefix(k : Key, m : Mask) -> Prefix {
  get_prefix_(k.reinterpret_as_uint(), m)
}

///|
fn match_prefix(key~ : Key, prefix~ : Prefix, mask~ : Mask) -> Bool {
  get_prefix(key, mask) == prefix
}

///|
fn gen_mask_(p1 : UInt, p2 : UInt) -> Mask {
  let unsigned_int_width = 32
  1U << (unsigned_int_width - 1 - p1.lxor(p2).clz())
}

///|
fn gen_mask(p1 : Prefix, p2 : Prefix) -> Mask {
  let p1 = p1.reinterpret_as_uint()
  let p2 = p2.reinterpret_as_uint()
  gen_mask_(p1, p2)
}

///|
fn[T] join(
  p1 : Prefix,
  t1 : IntMap[T],
  p2 : Prefix,
  t2 : IntMap[T],
) -> IntMap[T] {
  let mask = gen_mask(p1, p2)
  if zero(p1, mask) {
    Branch(prefix=get_prefix(p1, mask), mask~, left=t1, right=t2)
  } else {
    Branch(prefix=get_prefix(p1, mask), mask~, left=t2, right=t1)
  }
}

///|
fn[T] insert_with(
  self : IntMap[T],
  combine~ : (T, T) -> T,
  key : Key,
  value : T,
) -> IntMap[T] {
  match self {
    Empty => Leaf(key~, value~)
    Leaf(..) as leaf =>
      if leaf.key == key {
        Leaf(key~, value=combine(value, leaf.value))
      } else {
        join(key, Leaf(key~, value~), leaf.key, leaf)
      }
    Branch(..) as br_node =>
      if match_prefix(key~, prefix=br_node.prefix, mask=br_node.mask) {
        if zero(key, br_node.mask) {
          Branch(
            prefix=br_node.prefix,
            mask=br_node.mask,
            left=br_node.left.insert_with(combine~, key, value),
            right=br_node.right,
          )
        } else {
          Branch(
            prefix=br_node.prefix,
            mask=br_node.mask,
            left=br_node.left,
            right=br_node.right.insert_with(combine~, key, value),
          )
        }
      } else {
        join(key, Leaf(key~, value~), br_node.prefix, br_node)
      }
  }
}

///|
/// insert a new kay-value pair or replace original value if this key existed
pub fn[T] insert(self : IntMap[T], key : Key, value : T) -> IntMap[T] {
  fn combine(new : T, old : T) -> T {
    ignore(old)
    new
  }

  self.insert_with(combine~, key, value)
}

///|
pub fn[T] IntMap::from_array(arr : Array[T]) -> IntMap[T] {
  let mut intmap = IntMap::Empty
  for i = 0; i < arr.length(); i = i + 1 {
    intmap = intmap.insert(i, arr[i])
  } else {
    return intmap
  }
}

///|
pub fn[T] get_opt(self : IntMap[T], k : Key) -> T? {
  match self {
    Empty => None
    Leaf(..) as leaf => if leaf.key == k { Some(leaf.value) } else { None }
    Branch(..) as br_node =>
      if k.reinterpret_as_uint() <= br_node.prefix.reinterpret_as_uint() {
        br_node.left.get_opt(k)
      } else {
        br_node.right.get_opt(k)
      }
  }
}

///|
pub fn[T] op_get(self : IntMap[T], key : Key) -> T {
  match self.get_opt(key) {
    None => abort("IntMap::op_get: key = \{key}")
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
  foo = foo.insert(@int.min_value, "min")
  foo = foo.insert(@int.max_value, "max")
  foo = foo.insert(0, "zero")
  foo = foo.insert(-1, "neg1")
  foo = foo.insert(1, "pos1")
  inspect(foo[@int.min_value], content="min")
  inspect(foo[@int.max_value], content="max")
  inspect(foo[0], content="zero")
  inspect(foo[-1], content="neg1")
  inspect(foo[1], content="pos1")
}

///|
pub fn[T] merge(
  combine~ : (T, T) -> T,
  left : IntMap[T],
  right : IntMap[T],
) -> IntMap[T] {
  fn merge(left : IntMap[T], right : IntMap[T]) -> IntMap[T] {
    match (left, right) {
      (t, Empty) => t
      (Empty, t) => t
      (Leaf(key~, value~), t) => t.insert_with(combine~, key, value)
      (t, Leaf(key~, value~)) => {
        let combine = fn(x, y) { combine(y, x) }
        t.insert_with(combine~, key, value)
      }
      (
        Branch(prefix=p, mask=m, left=s0, right=s1) as s,
        Branch(prefix=q, mask=n, left=t0, right=t1) as t,
      ) =>
        if m == n && p == q {
          // The trees have the same prefix. Merge the subtrees
          Branch(prefix=p, mask=m, left=merge(s0, t0), right=merge(s1, t1))
        } else if m < n && match_prefix(key=q, prefix=p, mask=m) {
          // q contains p. Merge t with a subtree of s
          if zero(q, m) {
            Branch(prefix=p, mask=m, left=merge(s0, t), right=s1)
          } else {
            Branch(prefix=p, mask=m, left=merge(s0, t), right=s1)
          }
        } else if m > n {
          // p contains q. Merge s with a subtree of t
          if zero(p, n) {
            Branch(prefix=q, mask=n, left=merge(s, t0), right=t1)
          } else {
            Branch(prefix=q, mask=n, left=t0, right=merge(s, t1))
          }
        } else {
          // The prefixes disagree
          join(p, s, q, t)
        }
    }
  }

  merge(left, right)
}
