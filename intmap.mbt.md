# 在MoonBit中实现IntMap

IntMap是一种为整数特化的不可变键值对容器，

事实上，IntMap是一种经典数据结构Patrica树的特例

## 二叉字典树

二叉字典树是一种使用每个键的二进制表示决定其位置的二叉树，键的二进制表示是一长串有限的0和1，那么假如当前位是0，就向左子树递归，当前位为1则向右子树递归.

```mbt
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

fn[T] PatriciaTree::lookup(self : PatriciaTree[T], key : Int) -> T? {
    match self {
        Empty => None
        Leaf(key=k, value~) => {
            if k == key {
                Some(value)
            } else {
                None
            }
        }
        Branch(prefix~, mask~, left~, right~) => {
            if !(match_prefix(key~, prefix~, mask~)) {
                None
            } else {
                if zero_bit(key~, mask~) {
                    left.lookup(key)
                } else {
                    right.lookup(key)
                }
            }
        }
    }
}

fn match_prefix(key~ : Int, prefix~ : UInt, mask~ : UInt) -> Bool {
    (key.reinterpret_as_uint() & (mask - 1U)) == prefix
}

fn zero_bit(key~ : Int, mask~ : UInt) -> Bool {
    (key.reinterpret_as_uint() & mask) == 0
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
fn branching_bit(p0 : UInt, p1 : UInt) -> UInt {
  fn lowest_bit(x : UInt) -> UInt {
    x & x.lnot()
  }
  lowest_bit(p0.lxor(p1))
}
```

## 大端压缩前缀树