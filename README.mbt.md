# IntMap

A fast mergeable int keyed immutable map implementation for MoonBit.

The implementation is based on big-endian patricia trees. This data structure performs especially well on union/intersection operations.

+ Chris Okasaki and Andy Gill, "Fast Mergeable Integer Maps", Workshop on ML, September 1998, pages 77-86
+ Jan Midtgaard, "QuickChecking Patricia Trees"