///|
test {
  let m = @intmap.IntMap::empty()
    .insert(1, "one")
    .insert(2, "two")
    .insert(3, "three")
    .insert(0, "zero")
    .insert(-1, "negative one")
    .insert(@int.max_value, "@int.max_value")
  @json.inspect(m.iter().collect(), content=[
    "zero", "one", "two", "three", "@int.max_value", "negative one",
  ])
  @json.inspect(m.iter2().to_array(), content=[
    [0, "zero"],
    [1, "one"],
    [2, "two"],
    [3, "three"],
    [2147483647, "@int.max_value"],
    [-1, "negative one"],
  ])
}

///|
test {
  let m = @intmap.IntMap::empty()
    .insert(-1, "negative one")
    .insert(0, "zero")
    .insert(-2, "negative two")
    .insert(-4, "negative four")
    .insert(@int.min_value, "@int.min_value")
  @json.inspect(m.iter().collect(), content=[
    "zero", "@int.min_value", "negative four", "negative two", "negative one",
  ])
  @json.inspect(m.iter2().to_array(), content=[
    [0, "zero"],
    [-2147483648, "@int.min_value"],
    [-4, "negative four"],
    [-2, "negative two"],
    [-1, "negative one"],
  ])
}
