-- Flutter Color values are 32-bit unsigned integers (ARGB). Fully opaque colors
-- have alpha = 0xFF, making them > 2 147 483 647 which overflows PostgreSQL
-- integer (int4). Change to bigint (int8) to store the full unsigned 32-bit range.
alter table public.collections
  alter column color type bigint using color::bigint;
