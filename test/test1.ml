open State

let a = Address.addr "A"
let b = Address.addr "B"
let t0 = Token.init "t0"
let t1 = Token.init "t1"

module S = State(
  struct
    let coll_min = 1.5
    let r_liq = 1.1
    let intr _ = 0.14
  end)

let s = S.(
  empty
  |> px t0 1.
  |> px t1 1.
  |> id_print
  |> add_wallet a [(t0,100)]
  |> id_print
  |> add_wallet b [(t1,50)]
  |> id_print
  |> dep a 50 t0
  |> id_print
  |> dep b 50 t1
  |> id_print
  |> bor b 30 t0
  |> id_print
  |> accrue_int
  |> id_print
  |> rep b 5 t0
  |> id_print
  |> px t0 1.3
  |> id_print
  |> liq a b 12 t0 t1
  |> id_print
  |> rdm a 10 t0
  |> id_print
  |> id_info
 )
;;


(*
print_string "A's value of collateralized tokens: ";
print_float (State.val_collateralized a s);;
print_newline ();;
print_string "B's value of collateralized tokens: ";
print_float (State.val_collateralized b s);;
print_newline ();;
*)
