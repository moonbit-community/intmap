///|
pub fn[T] IntMap::from_array(arr : Array[T]) -> IntMap[T] {
  let mut intmap = IntMap::Empty
  for i = 0; i < arr.length(); i = i + 1 {
    intmap = intmap.insert(i, arr[i])
  } else {
    return intmap
  }
}
