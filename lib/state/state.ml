open Token
open Address
open Wallet
open Lp
     
module type StateType =
  sig
    type t

    type collType = Infty | Val of float	  
	  
    val empty : t
    
    val get_wallet : Address.t -> t -> Wallet.t
	
    val get_lp : Token.t -> t -> Lp.t

    val get_price : Token.t -> t -> float
	
    val add_wallet : Address.t -> (Token.t * int) list -> t -> t

    (* Supply of a token in a state *)
    val supply : Token.t -> t -> int

    (* Exchange rate ER of a non-minted token in a state *)	
    val er : Token.t -> t -> float

    (* Value of free (non-collateralized) tokens *)
    val val_free : Address.t -> t -> float

    (* Value of collateralized tokens *)
    val val_collateralized : Address.t -> t -> float

    (* Value of non-minted tokens *)
    val val_debt : Address.t -> t -> float

    (* Collateralization of a user in a state *)
    val coll : Address.t -> t -> collType
      
    val xfer : Address.t -> Address.t -> int -> Token.t -> t -> t

    val dep : Address.t -> int -> Token.t -> t -> t

    val bor : Address.t -> int -> Token.t -> t -> t
	
    val to_string : t -> string

    val id_print : t -> t

  end

      
module State : StateType =
  struct
 
    module WMap = Map.Make(Address)
    module LPMap = Map.Make(Token)

    type tw = Wallet.bt WMap.t
    type tlp = (int * Lp.dt) LPMap.t
    type t = tw * tlp
    type collType = Infty | Val of float

    let coll_min = 1.5
	
    exception SameAddress
    exception InsufficientBalance of string
    exception UnderCollateralization of string
	
    let empty = (WMap.empty,LPMap.empty)
	
    let get_wallet a s = Wallet.make a (WMap.find a (fst s))
	
    let add_wallet a bal s =
      (WMap.add a (Wallet.balance_of_list bal) (fst s), snd s)
	
    let get_lp tau s =
      let (n,d) = (LPMap.find tau (snd s)) in Lp.make tau n d

    let supply tau (wM,lpM) =
      let nw = WMap.fold
	  (fun a bal n -> n + Wallet.balance tau (Wallet.make a bal)) wM 0 in
      try 
	let (r,_) = LPMap.find tau lpM in nw + r
      with Not_found -> nw
	  
    let er tau s =
      (* TODO: check that tau is non-minted *)
      try 
	let (r,d) = LPMap.find tau (snd s) in
	let dsum = List.fold_right (fun x n -> n + snd x) (Lp.list_of_debt d) 0 in
	float_of_int (r + dsum) /. float_of_int (supply (Token.mintLP tau) s)
      with Not_found -> 1.

    let get_price tau s = 1.

    let val_free a s =
      let bl = Wallet.list_of_balance (WMap.find a (fst s))
      in List.fold_right
	(fun x n -> n +. (float_of_int (snd x) *. get_price (fst x) s))
	(List.filter (fun x -> Token.is_free (fst x)) bl)
	0.

    let val_collateralized a s = 0.
    let val_debt a s = 0.
	
    let coll a s =
      if val_debt a s > 0.
      then Val ((val_collateralized a s) /. (val_debt a s))
      else Infty
	
	  (**************************************************)
	  (*                        Xfer                    *)
	  (**************************************************)
	  
    let xfer a b v tau (w,lp) =
      if a=b then raise (SameAddress);
      let wa = get_wallet a (w,lp) in
      (* fails if a's balance of tau is < v *)
      if Wallet.balance tau wa < v
      then raise (InsufficientBalance (Address.to_string a));
      let wb = get_wallet b (w,lp) in
      let wa' = Wallet.update tau (-v) wa in
      let wb' = Wallet.update tau v wb in
      let w' = 
	(w
	   (* removes v:tau from a's balance *)
      |> WMap.add a (Wallet.get_balance wa')
          (* adds v:tau to b's balance *)
      |> WMap.add b (Wallet.get_balance wb'))
      in (w',lp)

	(**************************************************)
	(*                        Dep                     *)
	(**************************************************)
	
    let dep a v tau (w,lp) =
      let wa = get_wallet a (w,lp) in
      (* fails if a's balance of tau is < v *)
      if Wallet.balance tau wa < v
      then raise (InsufficientBalance (Address.to_string a));
      let tau' = Token.mintLP tau in
      let wa' =	(wa
      |> Wallet.update tau (-v)
      |> Wallet.update tau' v) in 
      let w' = WMap.add a (Wallet.get_balance wa') w in
      try
	let lp0 = get_lp tau (w,lp) in
	let v' = int_of_float ((float_of_int v) /. (er tau (w,lp))) in 
	let n' = v' + Lp.get_balance lp0 in
	let d = Lp.get_debt lp0 in
	(w',LPMap.add tau (n',d) lp)
      with Not_found ->	(w', LPMap.add tau (v,Lp.debt_of_list []) lp)

	(**************************************************)
	(*                        Bor                     *)
	(**************************************************)
	
    let bor a v tau s =
      let wa = get_wallet a s in
      (* fails if a's balance of tau is < v *)
      let wa' =	(wa |> Wallet.update tau v) in 
      let w' = WMap.add a (Wallet.get_balance wa') (fst s) in
      let lp = get_lp tau s in
      let r = Lp.get_balance lp in
      if r<v then raise (InsufficientBalance (Lp.to_string lp));
      let d' = Lp.update_debt a v (Lp.get_debt lp) in
      let s' = (w',LPMap.add tau (r-v,d') (snd s)) in      
      match coll a s' with
	Val c when c < coll_min -> raise (UnderCollateralization (Address.to_string a));
      | _ -> s'

	  
    let to_string (w,lp) =
      let ws = WMap.fold
	  (fun a bal s -> s ^ (if s="" then "" else " | ") ^ (Wallet.to_string (Wallet.make a bal)))
	  w "" in
      let lps = LPMap.fold
	  (fun t p s -> s ^ (if s="" then "" else " | ") ^ (Lp.to_string (Lp.make t (fst p) (snd p))))
	  lp "" in
      ws ^ (if lps = "" then "" else " | " ^ lps)

    let id_print s = print_endline (to_string s); s
	
  end

;;
   
let a = Address.addr "A";;
let b = Address.addr "B";;
let t0 = Token.init "t0";;
let t1 = Token.init "t1";;
    
let s = State.(
  empty
  |> id_print    
  |> add_wallet a [(t0,100);(t1,50)]
  |> id_print
  |> add_wallet b [(t0,200)]
  |> id_print
  |> xfer a b 10 t0
  |> id_print
  |> xfer a b 10 t1
  |> id_print
  |> dep a 50 t0      
  |> id_print      
  |> dep b 10 t0
  |> id_print      
  |> bor a 15 t0
  |> id_print      
)
;;

State.val_free a s;;

State.coll a s;;
State.supply t0 s;;
State.supply t1 s;;
State.supply (Token.mintLP t0) s;;
State.supply (Token.mintLP t1) s;;
State.er t0 s;;
State.er t1 s;;
