///|
fn exhaustive_keys() -> Array[Int] {
  [0, 1, 2, -2, -1]
}

///|
fn test_value(prefix : String, key : Int) -> String {
  "\{prefix}\{key}"
}

///|
fn intmap_from_mask(mask : Int, prefix : String) -> @intmap.IntMap[String] {
  let keys = exhaustive_keys()
  let mut map = @intmap.IntMap::empty()
  for i = 0; i < keys.length(); i = i + 1 {
    if (mask & (1 << i)) != 0 {
      let key = keys[i]
      map = map.insert(key, test_value(prefix, key))
    }
  } nobreak {
    map
  }
}

///|
fn pairs_from_mask(mask : Int, prefix : String) -> Array[(Int, String)] {
  let keys = exhaustive_keys()
  let pairs : Array[(Int, String)] = []
  for i = 0; i < keys.length(); i = i + 1 {
    if (mask & (1 << i)) != 0 {
      let key = keys[i]
      pairs.push((key, test_value(prefix, key)))
    }
  } nobreak {
    pairs
  }
}

///|
fn union_pairs(lhs_mask : Int, rhs_mask : Int) -> Array[(Int, String)] {
  let keys = exhaustive_keys()
  let pairs : Array[(Int, String)] = []
  for i = 0; i < keys.length(); i = i + 1 {
    let key = keys[i]
    if (lhs_mask & (1 << i)) != 0 {
      pairs.push((key, test_value("lhs:", key)))
    } else if (rhs_mask & (1 << i)) != 0 {
      pairs.push((key, test_value("rhs:", key)))
    }
  } nobreak {
    pairs
  }
}

///|
fn intersection_pairs(lhs_mask : Int, rhs_mask : Int) -> Array[(Int, String)] {
  let keys = exhaustive_keys()
  let pairs : Array[(Int, String)] = []
  for i = 0; i < keys.length(); i = i + 1 {
    if (lhs_mask & (1 << i)) != 0 && (rhs_mask & (1 << i)) != 0 {
      let key = keys[i]
      pairs.push((key, test_value("lhs:", key)))
    }
  } nobreak {
    pairs
  }
}

///|
fn popcount(mask : Int) -> Int {
  let mut count = 0
  let mut n = mask
  while n != 0 {
    count += n & 1
    n = n >> 1
  } nobreak {
    count
  }
}

///|
test "IntMap::iter() && IntMap::iter2()" {
  let m = @intmap.IntMap::empty()
    .insert(1, "one")
    .insert(2, "two")
    .insert(3, "three")
    .insert(0, "zero")
    .insert(-1, "negative one")
    .insert(@int.MAX_VALUE, "@int.MAX_VALUE")
    .insert(-1, "negative one")
    .insert(0, "zero")
    .insert(-2, "negative two")
    .insert(-4, "negative four")
    .insert(@int.MIN_VALUE, "@int.MIN_VALUE")
  json_inspect(m.iter().collect(), content=[
    [0, "zero"],
    [1, "one"],
    [2, "two"],
    [3, "three"],
    [2147483647, "@int.MAX_VALUE"],
    [-2147483648, "@int.MIN_VALUE"],
    [-4, "negative four"],
    [-2, "negative two"],
    [-1, "negative one"],
  ])
  json_inspect(m.iter2().to_array(), content=[
    [0, "zero"],
    [1, "one"],
    [2, "two"],
    [3, "three"],
    [2147483647, "@int.MAX_VALUE"],
    [-2147483648, "@int.MIN_VALUE"],
    [-4, "negative four"],
    [-2, "negative two"],
    [-1, "negative one"],
  ])
}

///|
test "IntMap::union() && IntMap::intersection()" {
  let lhs = @intmap.IntMap::empty()
    .insert(1, "one")
    .insert(2, "two")
    .insert(3, "three at left hand side")
  let rhs = @intmap.IntMap::empty()
    .insert(3, "three at right hand side")
    .insert(4, "four")
    .insert(5, "five")
  json_inspect(lhs.union(rhs).iter().collect(), content=[
    [1, "one"],
    [2, "two"],
    [3, "three at left hand side"],
    [4, "four"],
    [5, "five"],
  ])
  json_inspect(lhs.intersection(rhs).iter().collect(), content=[
    [3, "three at left hand side"],
  ])
  let lhs = @intmap.IntMap::empty()
    .insert(0, "zero")
    .insert(@int.MIN_VALUE, "@int.MIN_VALUE")
  let rhs = @intmap.IntMap::empty()
    .insert(1, "negative one")
    .insert(@int.MIN_VALUE, "@int.MIN_VALUE")
  json_inspect(lhs.union(rhs).iter().collect(), content=[
    [0, "zero"],
    [1, "negative one"],
    [-2147483648, "@int.MIN_VALUE"],
  ])
}

///|
test "more union test" {
  let lhs = @intmap.IntMap::empty()
    .insert(1, "one")
    .insert(2, "two")
    .insert(3, "three at left hand side")
    .insert(0, "zero at left hand side")
    .insert(-1, "negative one")
    .insert(-2, "negative two")
    .insert(-4, "negative four")
    .insert(-42, "negative forty two at left hand side")
    .insert(@int.MIN_VALUE, "@int.MIN_VALUE")
    .insert(@int.MAX_VALUE, "@int.MAX_VALUE at left hand side")
  let rhs = @intmap.IntMap::empty()
    .insert(3, "three at right hand side")
    .insert(4, "four")
    .insert(5, "five")
    .insert(0, "zero at right hand side")
    .insert(42, "forty two")
    .insert(-42, "negative forty two at right hand side")
    .insert(@int.MAX_VALUE, "@int.MAX_VALUE at right hand side")
  json_inspect(lhs.union(rhs).iter().collect(), content=[
    [0, "zero at left hand side"],
    [1, "one"],
    [2, "two"],
    [3, "three at left hand side"],
    [4, "four"],
    [5, "five"],
    [42, "forty two"],
    [2147483647, "@int.MAX_VALUE at left hand side"],
    [-2147483648, "@int.MIN_VALUE"],
    [-42, "negative forty two at left hand side"],
    [-4, "negative four"],
    [-2, "negative two"],
    [-1, "negative one"],
  ])
}

///|
test "IntMap public operations agree on exhaustive small key sets" {
  let keys = exhaustive_keys()
  let total_masks = 1 << keys.length()
  for lhs_mask = 0; lhs_mask < total_masks; lhs_mask = lhs_mask + 1 {
    let lhs = intmap_from_mask(lhs_mask, "lhs:")
    let lhs_pairs = pairs_from_mask(lhs_mask, "lhs:")
    assert_eq(lhs.iter().collect(), lhs_pairs)
    assert_eq(lhs.size(), popcount(lhs_mask))
    assert_eq(lhs.is_empty(), lhs_mask == 0)
    for i = 0; i < keys.length(); i = i + 1 {
      let key = keys[i]
      let bit = 1 << i
      let expected = if (lhs_mask & bit) != 0 {
        Some(test_value("lhs:", key))
      } else {
        None
      }
      assert_eq(lhs.get(key), expected)
      let removed_mask = if (lhs_mask & bit) != 0 {
        lhs_mask - bit
      } else {
        lhs_mask
      }
      let removed = lhs.remove(key)
      assert_eq(removed.iter().collect(), pairs_from_mask(removed_mask, "lhs:"))
      assert_eq(removed.size(), popcount(removed_mask))
      assert_eq(removed.is_empty(), removed_mask == 0)
    }
    for rhs_mask = 0; rhs_mask < total_masks; rhs_mask = rhs_mask + 1 {
      let rhs = intmap_from_mask(rhs_mask, "rhs:")
      let union = lhs.union(rhs)
      let inter = lhs.intersection(rhs)
      let union_mask = lhs_mask | rhs_mask
      let inter_mask = lhs_mask & rhs_mask
      assert_eq(union.iter().collect(), union_pairs(lhs_mask, rhs_mask))
      assert_eq(union.size(), popcount(union_mask))
      assert_eq(union.is_empty(), union_mask == 0)
      assert_eq(inter.iter().collect(), intersection_pairs(lhs_mask, rhs_mask))
      assert_eq(inter.size(), popcount(inter_mask))
      assert_eq(inter.is_empty(), inter_mask == 0)
    }
  }
}
