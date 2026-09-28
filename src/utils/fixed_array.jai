/// Simple linear allocator, wrapping a static array.
/// Instead of storing total number of elements in .count, we store the current size.
Fixed_Array :: struct($T: Type, N: s64) {
    data:     [N]T;
    count:    s64;

    capacity :: N;
}

push :: (array: *Fixed_Array($T, $N), item: T) -> *T
{
    if array.count >= array.capacity  return null;

    dst := *array.data[array.count];
    dst.* = item;

    array.count += 1;
    return dst;
}

push :: (array: *Fixed_Array($T, $N), items: []T) -> *T
{
    if array.count + items.count > array.capacity  return null;

    dst := *array.data[array.count];
    memcpy(dst, items.data, items.count * size_of(T));

    array.count += items.count;
    return dst;
}

reset :: inline (array: *Fixed_Array($T, $N))
{
    array.count = 0;
}

view :: inline (array: Fixed_Array($T, $N)) -> []T
{
    return array_view(array.data, 0, array.count);
}