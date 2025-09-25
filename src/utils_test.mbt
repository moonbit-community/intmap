///|
test "IntMap::iter() && IntMap::iter2()" {
  let m = @intmap.IntMap::empty()
    .insert(1, "one")
    .insert(2, "two")
    .insert(3, "three")
    .insert(0, "zero")
    .insert(-1, "negative one")
    .insert(@int.max_value, "@int.max_value")
    .insert(-1, "negative one")
    .insert(0, "zero")
    .insert(-2, "negative two")
    .insert(-4, "negative four")
    .insert(@int.min_value, "@int.min_value")
  @json.inspect(m.iter().collect(), content=[
    [0, "zero"],
    [1, "one"],
    [2, "two"],
    [3, "three"],
    [2147483647, "@int.max_value"],
    [-2147483648, "@int.min_value"],
    [-4, "negative four"],
    [-2, "negative two"],
    [-1, "negative one"],
  ])
  @json.inspect(m.iter2().to_array(), content=[
    [0, "zero"],
    [1, "one"],
    [2, "two"],
    [3, "three"],
    [2147483647, "@int.max_value"],
    [-2147483648, "@int.min_value"],
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
  @json.inspect(lhs.union(rhs).iter().collect(), content=[
    [1, "one"],
    [2, "two"],
    [3, "three at left hand side"],
    [4, "four"],
    [5, "five"],
  ])
  @json.inspect(lhs.intersection(rhs).iter().collect(), content=[
    [3, "three at left hand side"],
  ])
  let lhs = @intmap.IntMap::empty()
    .insert(0, "zero")
    .insert(@int.min_value, "@int.min_value")
  let rhs = @intmap.IntMap::empty()
    .insert(1, "negative one")
    .insert(@int.min_value, "@int.min_value")
  @json.inspect(lhs.union(rhs).iter().collect(), content=[
    [0, "zero"],
    [1, "negative one"],
    [-2147483648, "@int.min_value"],
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
    .insert(@int.min_value, "@int.min_value")
    .insert(@int.max_value, "@int.max_value at left hand side")
  let rhs = @intmap.IntMap::empty()
    .insert(3, "three at right hand side")
    .insert(4, "four")
    .insert(5, "five")
    .insert(0, "zero at right hand side")
    .insert(42, "forty two")
    .insert(-42, "negative forty two at right hand side")
    .insert(@int.max_value, "@int.max_value at right hand side")
  @json.inspect(lhs.union(rhs).iter().collect(), content=[
    [0, "zero at left hand side"],
    [1, "one"],
    [2, "two"],
    [3, "three at left hand side"],
    [4, "four"],
    [5, "five"],
    [42, "forty two"],
    [2147483647, "@int.max_value at left hand side"],
    [-2147483648, "@int.min_value"],
    [-42, "negative forty two at left hand side"],
    [-4, "negative four"],
    [-2, "negative two"],
    [-1, "negative one"],
  ])
}
