type t

val init : string -> t

val mintAMM : t * t -> t

val mintLP : t -> t

val isMintedLP : t -> bool

(* Underlying token of an LP-minted token *)
val uLP : t -> t option

val to_string : t -> string

val compare : t -> t -> int
