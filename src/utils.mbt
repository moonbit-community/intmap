///|
pub fn[T] IntMap::from_map(map : Map[Int, T]) -> IntMap[T] {
  let mut intmap = IntMap::empty()
  for k, v in map {
    intmap = intmap.insert(k, v)
  } else {
    return intmap
  }
}

///|
pub fn[T] IntMap::from_hashmap(hmap : @hashmap.HashMap[Int, T]) -> IntMap[T] {
  let mut intmap = IntMap::empty()
  for k, v in hmap {
    intmap = intmap.insert(k, v)
  } else {
    return intmap
  }
}

///|
pub fn[T] IntMap::to_map(self : IntMap[T]) -> Map[Int, T] {
  let map = {}
  for k, v in self.iter2() {
    map[k] = v
  } else {
    return map
  }
}

///|
pub fn[T] IntMap::to_hashmap(self : IntMap[T]) -> @hashmap.HashMap[Int, T] {
  let hmap = @hashmap.new()
  for k, v in self.iter2() {
    hmap[k] = v
  } else {
    return hmap
  }
}

///|
pub fn[T] IntMap::iter(self : IntMap[T]) -> Iter[T] {
  Iter::new(fn(yield_) {
    fn go(node : IntMap[T]) {
      match node {
        IntMap::Empty => IterContinue
        IntMap::Leaf(value~, ..) =>
          if yield_(value) is IterEnd {
            IterEnd
          } else {
            IterContinue
          }
        IntMap::Branch(left~, right~, ..) =>
          if go(left) is IterEnd {
            IterEnd
          } else {
            go(right)
          }
      }
    }

    go(self)
  })
}

///|
pub fn[T] IntMap::iter2(self : IntMap[T]) -> Iter2[Int, T] {
  Iter2::new(fn(yield_) {
    fn go(node : IntMap[T]) {
      match node {
        IntMap::Empty => IterContinue
        IntMap::Leaf(key~, value~) =>
          if yield_(key, value) is IterEnd {
            IterEnd
          } else {
            IterContinue
          }
        IntMap::Branch(left~, right~, ..) =>
          if go(left) is IterEnd {
            IterEnd
          } else {
            go(right)
          }
      }
    }

    go(self)
  })
}
