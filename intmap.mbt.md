# 在MoonBit中实现IntMap

IntMap是一种为整数特化的不可变键值对容器，

事实上，IntMap是一种经典数据结构Patrica树的特例

## 二叉字典树

二叉字典树是一种使用每个键的二进制表示决定其位置的二叉树，键的二进制表示是一长串有限的0和1，那么假如当前位是0，就向左子树递归，当前位为1则向右子树递归.

```mbt
///|
enum BinTrie[T] {
  Empty
  Leaf(T)
  Branch(left~ : BinTrie[T], right~ : BinTrie[T])
}
```

要在二叉字典树里查找某个键对应的值，只需要依次读取键的二进制位，根据其值选择向左或者向右移动，直到到达某个叶子节点

> 此处读取二进制位的顺序是从整数最小位到最高位

```mbt
fn[T] BinTrie::lookup(self : BinTrie[T], key : UInt) -> T? {
  match self {
    Empty => None
    Leaf(value) => Some(value)
    Branch(left~, right~) =>
      if key % 2U == 0 {
        left.lookup(key / 2)
      } else {
        right.lookup(key / 2)
      }
  }
}
```

为了避免创建过多空树，我们不直接调用值构造子，而是使用branch方法

```mbt
fn[T] BinTrie::br(left : BinTrie[T], right : BinTrie[T]) -> BinTrie[T] {
  match (left, right) {
    (Empty, Empty) => Empty
    _ => Branch(left~, right~)
  }
}
```



## 压缩前缀树

压缩前缀树在二叉字典树的基础上保存了更多信息以加速查找,在每个分叉的地方，它都保留子树中所有键的*公共前缀*(虽然此处是从最低位开始计算，但我们仍然使用前缀这种说法)，并用一个无符号整数标记当前的分支位(branching bit).这样一来，查找时需要经过的分支数量大大减少。

```mbt
///|
enum PatriciaTree[T] {
  Empty
  Leaf(key~ : Int, value~ : T)
  Branch(
    prefix~ : UInt,
    mask~ : UInt,
    left~ : PatriciaTree[T],
    right~ : PatriciaTree[T]
  )
}

///|
fn[T] PatriciaTree::lookup(self : PatriciaTree[T], key : Int) -> T? {
  match self {
    Empty => None
    Leaf(key=k, value~) => if k == key { Some(value) } else { None }
    Branch(prefix~, mask~, left~, right~) =>
      if !match_prefix(key=key.reinterpret_as_uint(), prefix~, mask~) {
        None
      } else if zero(key.reinterpret_as_uint(), mask~) {
        left.lookup(key)
      } else {
        right.lookup(key)
      }
  }
}

///|
fn get_prefix(key : UInt, mask~ : UInt) -> UInt {
  key & (mask - 1U)
}

///|
fn match_prefix(key~ : UInt, prefix~ : UInt, mask~ : UInt) -> Bool {
  get_prefix(key, mask~) == prefix
}

///|
fn zero(k : UInt, mask~ : UInt) -> Bool {
  (k & mask) == 0
}
```

现在`branch`方法可以做更多优化, 保证`Branch`节点的子树不含`Empty`.

```mbt
///|
fn[T] PatriciaTree::branch(
  prefix~ : UInt,
  mask~ : UInt,
  left~ : PatriciaTree[T],
  right~ : PatriciaTree[T],
) -> PatriciaTree[T] {
  match (left, right) {
    (Empty, right) => right
    (left, Empty) => left
    _ => Branch(prefix~, mask~, left~, right~)
  }
}
```

## 插入与合并

```mbt
///|
fn[T] join(
  p0 : UInt,
  t0 : PatriciaTree[T],
  p1 : UInt,
  t1 : PatriciaTree[T],
) -> PatriciaTree[T] {
  let mask = gen_mask(p0, p1)
  if zero(p0, mask~) {
    PatriciaTree::Branch(prefix=get_prefix(p0, mask~), mask~, left=t0, right=t1)
  } else {
    PatriciaTree::Branch(prefix=get_prefix(p0, mask~), mask~, left=t1, right=t0)
  }
}

///|
fn gen_mask(p0 : UInt, p1 : UInt) -> UInt {
  fn lowest_bit(x : UInt) -> UInt {
    x & x.lnot()
  }

  lowest_bit(p0 ^ p1)
}
```

```mbt
///|
fn[T] PatriciaTree::insert_with(
  self : PatriciaTree[T],
  k : Int,
  v : T,
  combine~ : (T, T) -> T,
) -> PatriciaTree[T] {
  fn go(tree : PatriciaTree[T]) -> PatriciaTree[T] {
    match tree {
      Empty => Leaf(key=k, value=v)
      Leaf(key~, value~) as tree =>
        if key == k {
          PatriciaTree::Leaf(key~, value=combine(v, value))
        } else {
          join(
            k.reinterpret_as_uint(),
            Leaf(key=k, value=v),
            key.reinterpret_as_uint(),
            tree,
          )
        }
      Branch(prefix~, mask~, left~, right~) as tree =>
        if match_prefix(key=k.reinterpret_as_uint(), prefix~, mask~) {
          if zero(k.reinterpret_as_uint(), mask~) {
            PatriciaTree::Branch(prefix~, mask~, left=go(left), right~)
          } else {
            PatriciaTree::Branch(prefix~, mask~, left~, right=go(right))
          }
        } else {
          join(k.reinterpret_as_uint(), Leaf(key=k, value=v), prefix, tree)
        }
    }
  }

  go(self)
}
```

```mbt
///|
fn[T] PatriciaTree::merge_with(
  combine~ : (T, T) -> T,
  left : PatriciaTree[T],
  right : PatriciaTree[T],
) -> PatriciaTree[T] {
  fn go(left : PatriciaTree[T], right : PatriciaTree[T]) -> PatriciaTree[T] {
    match (left, right) {
      (Empty, t) | (t, Empty) => t
      (Leaf(key~, value~), t) => t.insert_with(key, value, combine~)
      (t, Leaf(key~, value~)) =>
        t.insert_with(key, value, combine=fn(x, y) { combine(y, x) })
      (
        Branch(prefix=p, mask=m, left=s0, right=s1) as s,
        Branch(prefix=q, mask=n, left=t0, right=t1) as t,
      ) =>
        if m == n && p == q {
          // The trees have the same prefix. Merge the subtrees
          PatriciaTree::Branch(
            prefix=p,
            mask=m,
            left=go(s0, t0),
            right=go(s1, t1),
          )
        } else if m < n && match_prefix(key=q, prefix=p, mask=m) {
          // q contains p. Merge t with a subtree of s
          if zero(q, mask=m) {
            Branch(prefix=p, mask=m, left=go(s0, t), right=s1)
          } else {
            Branch(prefix=p, mask=m, left=s0, right=go(s1, t))
          }
        } else if m > n && match_prefix(key=p, prefix=q, mask=n) {
          // p contains q. Merge s with a subtree of t.
          if zero(p, mask=n) {
            Branch(prefix=q, mask=n, left=go(s, t0), right=t1)
          } else {
            Branch(prefix=q, mask=n, left=t0, right=go(s, t1))
          }
        } else {
          join(p, s, q, t)
        }
    }
  }

  go(left, right)
}
```

## 大端压缩前缀树

大端压缩前缀树在压缩前缀树的基础上将计算分支比特位的顺序改成了从最高位到最低位，

这样做有什么好处呢？

+ 更好的局部性。在大端压缩前缀树中，大小相近的整数会被放在一起。

+ 便于高效地按顺序遍历键，只要普通地实现前序/后序遍历即可。

+ 常见情况下合并速度更快。在实践中，一个intmap

## OCaml库ptmap中的一处错误

虽然IntMap的实现相当简洁明了，但在有些情况下还是可能犯一些非常隐蔽的错误，甚至原论文作者在编写IntMap的SML实现时也未能幸免，后来又被OCaml的ptmap库继承，直到