// Big-endian Patricia Tree

///|
typealias Int as Key

///|
fn Key::as_prefix(self : Key) -> Prefix {
  self.reinterpret_as_uint()
}

///|
typealias UInt as Prefix

///|
typealias UInt as Mask // Mask must be 2 ^ n

///|
enum IntMap[T] {
  Empty
  Leaf(key~ : Key, value~ : T)
  Branch(prefix~ : Prefix, mask~ : Mask, left~ : IntMap[T], right~ : IntMap[T])
} derive(Show)

///|
pub fn[T] IntMap::empty() -> IntMap[T] {
  IntMap::Empty
}

///|
fn[T] IntMap::branch(
  prefix~ : Prefix,
  mask~ : Mask,
  left~ : IntMap[T],
  right~ : IntMap[T],
) -> IntMap[T] {
  match (left, right) {
    (Empty, t) => t
    (t, Empty) => t
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
  } else {
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
  inspect(@int.max_value.to_hex_str(), content="7FFFFFFF")
  inspect(@int.min_value.to_hex_str(), content="80000000")
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
fn get_prefix(key : UInt, mask~ : UInt) -> Prefix {
  (key | (mask - 1)) & mask.lnot()
}

///|
fn match_prefix(key~ : UInt, prefix~ : Prefix, mask~ : Mask) -> Bool {
  get_prefix(key, mask~) == prefix
}

///|
fn gen_mask(p1 : Prefix, p2 : Prefix) -> Mask {
  let unsigned_int_width = 32
  1U << (unsigned_int_width - 1 - p1.lxor(p2).clz())
}

///|
fn[T] join(
  p1 : Prefix,
  t1 : IntMap[T],
  p2 : Prefix,
  t2 : IntMap[T],
) -> IntMap[T] {
  let mask = gen_mask(p1, p2)
  if zero(p1, mask~) {
    Branch(prefix=get_prefix(p1, mask~), mask~, left=t1, right=t2)
  } else {
    Branch(prefix=get_prefix(p1, mask~), mask~, left=t2, right=t1)
  }
}

///|
pub fn[T] IntMap::insert_with(
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
        join(key.as_prefix(), Leaf(key~, value~), leaf.key.as_prefix(), leaf)
      }
    Branch(..) as br_node =>
      if match_prefix(
          key=key.reinterpret_as_uint(),
          prefix=br_node.prefix,
          mask=br_node.mask,
        ) {
        if zero(key.as_prefix(), mask=br_node.mask) {
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
        join(key.as_prefix(), Leaf(key~, value~), br_node.prefix, br_node)
      }
  }
}

///|
/// insert a new kay-value pair or replace original value if this key existed
pub fn[T] IntMap::insert(self : IntMap[T], key : Key, value : T) -> IntMap[T] {
  self.insert_with(combine=(left, _) => left, key, value)
}

///|
pub fn[T] IntMap::remove(self : IntMap[T], key : Key) -> IntMap[T] {
  fn go(tree : IntMap[T]) -> (Bool, IntMap[T]) {
    match tree {
      Empty => (false, tree)
      Leaf(..) as leaf =>
        if leaf.key == key {
          (true, Empty)
        } else {
          (false, tree)
        }
      Branch(prefix~, mask~, left~, right~) =>
        if key.reinterpret_as_uint() <= prefix {
          // select left subtree
          let (changed, left) = go(left)
          if changed {
            let tree = IntMap::branch(prefix~, mask~, left~, right~)
            (true, tree)
          } else {
            (false, tree)
          }
        } else {
          // select right subtree
          let (changed, right) = go(right)
          if changed {
            let tree = IntMap::branch(prefix~, mask~, left~, right~)
            (true, tree)
          } else {
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
pub fn[T] IntMap::get(self : IntMap[T], k : Key) -> T? {
  match self {
    Empty => None
    Leaf(..) as leaf => if leaf.key == k { Some(leaf.value) } else { None }
    Branch(..) as br_node =>
      if k.reinterpret_as_uint() <= br_node.prefix {
        br_node.left.get(k)
      } else {
        br_node.right.get(k)
      }
  }
}

///|
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
/// 
pub fn[T] IntMap::union_with(
  combine~ : (T, T) -> T,
  left : IntMap[T],
  right : IntMap[T],
) -> IntMap[T] {
  fn go(left : IntMap[T], right : IntMap[T]) -> IntMap[T] {
    match (left, right) {
      (t, Empty) => t
      (Empty, t) => t
      (Leaf(key~, value~), t) => t.insert_with(combine~, key, value)
      (t, Leaf(key~, value~)) => {
        let combine = fn(x, y) { combine(y, x) }
        t.insert_with(combine~, key, value)
      }
      (
        Branch(prefix=p, mask=m, left=s_left, right=s_right) as s,
        Branch(prefix=q, mask=n, left=t_left, right=t_right) as t,
      ) =>
        if m == n && p == q {
          // The trees have the same prefix. Merge the subtrees
          Branch(
            prefix=p,
            mask=m,
            left=go(s_left, t_left),
            right=go(s_right, t_right),
          )
        } else if m > n && match_prefix(key=q, prefix=p, mask=m) {
          // q contains p. Merge t with a subtree of s
          if zero(q, mask=m) {
            Branch(prefix=p, mask=m, left=go(s_left, t), right=s_right)
          } else {
            Branch(prefix=p, mask=m, left=s_left, right=go(s_right, t))
          }
        } else if m < n && match_prefix(key=p, prefix=q, mask=n) {
          // p contains q. Merge s with a subtree of t
          if zero(p, mask=n) {
            Branch(prefix=q, mask=n, left=go(s, t_left), right=t_right)
          } else {
            Branch(prefix=q, mask=n, left=t_left, right=go(s, t_right))
          }
        } else {
          // The prefixes disagree
          join(p, s, q, t)
        }
    }
  }

  go(left, right)
}

///|
pub fn[T] IntMap::intersection_with(
  combine~ : (T, T) -> T,
  left : IntMap[T],
  right : IntMap[T],
) -> IntMap[T] {
  fn go(left : IntMap[T], right : IntMap[T]) -> IntMap[T] {
    match (left, right) {
      (_, Empty) => Empty
      (Empty, _) => Empty
      (Leaf(key~, value~), t) =>
        match t.get(key) {
          None => Empty
          Some(v) => Leaf(key~, value=combine(value, v))
        }
      (t, Leaf(key~, value~)) =>
        match t.get(key) {
          None => Empty
          Some(v) => Leaf(key~, value=combine(v, value))
        }
      (
        Branch(prefix=p, mask=m, left=s_left, right=s_right) as s,
        Branch(prefix=q, mask=n, left=t_left, right=t_right) as t,
      ) =>
        if m == n && p == q {
          // The trees have the same prefix. intersect the subtrees
          Branch(
            prefix=p,
            mask=m,
            left=go(s_left, t_left),
            right=go(s_right, t_right),
          )
        } else if m < n && match_prefix(key=q, prefix=p, mask=m) {
          // q contains p. Merge t with a subtree of s
          if zero(q, mask=m) {
            go(s_left, t)
          } else {
            go(s_right, t)
          }
        } else if m > n {
          // p contains q. Merge s with a subtree of t
          if zero(p, mask=n) {
            go(s, t_left)
          } else {
            go(s, t_right)
          }
        } else {
          // The prefixes disagree
          Empty
        }
    }
  }

  go(left, right)
}
