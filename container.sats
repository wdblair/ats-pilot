(*
  A really dumb lookup table.
  
  ATS2 has some trouble compiling it.
*)

#define ATS_STALOAD_FLAG 0

abst@ype container (a:t@ype)

fun {a:t@ype}
container_lookup {c: nat | c < 256} (
  storage: &container(a), id: char c
): a

overload [] with container_lookup
