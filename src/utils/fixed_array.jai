/// Simple linear allocator, wrapping a static array.
/// Instead of storing total number of elements in .count, we store the current size.
Fixed_Array :: struct(T: Type, N: s64) {
    data:     [N]T;
    count:    s64;

    capacity :: N;
}

push :: (using array: *Fixed_Array($T, $N), item: T) -> *T
{
    if count >= capacity  return null;

    dst := *data[count];
    dst.* = item;

    count += 1;
    return dst;
}

push :: (using array: *Fixed_Array($T, $N), items: []T) -> *T
{
    if count + items.count > capacity  return null;

    dst := *data[count];
    memcpy(dst, items.data, items.count * size_of(T));

    count += items.count;
    return dst;
}

reset :: inline (using array: *Fixed_Array)
{
    count = 0;
}

view :: inline (using array: Fixed_Array($T, $N)) -> []T
{
    return array_view(data, 0, count);
}