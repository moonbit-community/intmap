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
pub fn[T] IntMap::from_iter(iter : Iter[(Int, T)]) -> IntMap[T] {
  let mut intmap = IntMap::empty()
  for pair in iter {
    intmap = intmap.insert(pair.0, pair.1)
  } else {
    return intmap
  }
}

///|
pub fn[T] IntMap::from_iter2(iter2 : Iter2[Int, T]) -> IntMap[T] {
  let mut intmap = IntMap::empty()
  for k, v in iter2 {
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
pub fn[T] IntMap::keys(self : IntMap[T]) -> Iter[Int] {
  Iter::new(fn(yield_) {
    fn go(node : IntMap[T]) {
      match node {
        IntMap::Empty => IterContinue
        IntMap::Leaf(key~, ..) =>
          if yield_(key) is IterEnd {
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
pub fn[T] IntMap::values(self : IntMap[T]) -> Iter[T] {
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
pub fn[T] IntMap::iter(self : IntMap[T]) -> Iter[(Int, T)] {
  Iter::new(fn(yield_) {
    fn go(node : IntMap[T]) {
      match node {
        IntMap::Empty => IterContinue
        IntMap::Leaf(key~, value~) =>
          if yield_((key, value)) is IterEnd {
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

///|
pub fn[T] IntMap::each(
  self : IntMap[T],
  f : (Int, T) -> Unit raise?,
) -> Unit raise? {
  for k, v in self.iter2() {
    f(k, v)
  }
}

///|
pub fn[X, Y] IntMap::map(
  self : IntMap[X],
  f : (X) -> Y raise?,
) -> IntMap[Y] raise? {
  match self {
    Empty => Empty
    Leaf(key~, value~) => Leaf(key~, value=f(value))
    Branch(prefix~, mask~, left~, right~) =>
      Branch(prefix~, mask~, left=left.map(f), right=right.map(f))
  }
}

///|
pub fn[T] IntMap::filter(self : IntMap[T], p : (T) -> Bool) -> IntMap[T] {
  let mut res = IntMap::empty()
  for k, v in self.iter2() {
    if p(v) {
      res = res.insert(k, v)
    }
  } else {
    return res
  }
}

///|
/// The (left-biased) union of two maps
/// It prefers the first map when duplicate keys are encountered
pub fn[T] IntMap::union(self : IntMap[T], other : IntMap[T]) -> IntMap[T] {
  IntMap::union_with(combine=(left, _) => left, self, other)
}

///|
pub impl[T] Add for IntMap[T] with add(self, other) {
  self.union(other)
}
