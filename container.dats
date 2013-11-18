staload "container.sats"

assume container (a:t@ype) = @[a][256]

implement {a} container_lookup (storage, id) = let
  val id = g1int_of_char1<intknd> (id)
in
  storage.[id]
end