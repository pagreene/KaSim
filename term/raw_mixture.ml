(******************************************************************************)
(*  _  __ * The Kappa Language                                                *)
(* | |/ / * Copyright 2010-2017 CNRS - Harvard Medical School - INRIA - IRIF  *)
(* | ' /  *********************************************************************)
(* | . \  * This file is distributed under the terms of the                   *)
(* |_|\_\ * GNU Lesser General Public License Version 3                       *)
(******************************************************************************)

type internal = int option

type link = FREE | VAL of int

type agent =
  {
    a_type: int;
    a_ports: link array;
    a_ints: internal array;
  }

type t = agent list

type incr_t = {
    father : int Mods.DynArray.t;
    rank : (int * (bool * bool)) Mods.DynArray.t;
   }

let create n =
  { father = Mods.DynArray.init n (fun i -> i);
    rank = Mods.DynArray.make n (1,(true,false));
  }

let rec find_aux a i =
  let ai =
    if (Mods.DynArray.length a) <= i then i else
      Mods.DynArray.get a i in
  if ai == i then i
  else
    let root = find_aux a ai in
    let () = Mods.DynArray.set a i root in
    root

let find h x =
  find_aux h.father x

let combine_ranks (ix,(bx,_)) (iy,(by,_)) = (ix+iy,(bx&&by,true))

let union h x y =
  let root_x = find h x in
  let root_y = find h y in
  if root_x == root_y then ()
  else
    let rank_x = Mods.DynArray.get h.rank root_x in
    let rank_y = Mods.DynArray.get h.rank root_y in
    if (fst rank_x) > (fst rank_y) then
      let () = Mods.DynArray.set h.rank root_x (combine_ranks rank_x rank_y) in
      Mods.DynArray.set h.father root_y root_x
    else if (fst rank_x) < (fst rank_y) then
      let () = Mods.DynArray.set h.rank root_y (combine_ranks rank_x rank_y) in
      Mods.DynArray.set h.father root_x root_y
    else
      let () = Mods.DynArray.set h.rank root_x (combine_ranks rank_x rank_y) in
      Mods.DynArray.set h.father root_y root_x

let incr_agent sigs =
  let id = Signature.num_of_agent ("__incr",Locality.dummy) sigs in
  let incr = Signature.get sigs id in
  let after = Signature.num_of_site ("a",Locality.dummy) incr in
  let before = Signature.num_of_site ("b",Locality.dummy) incr in
  (before,after)

let union_find_counters sigs mix =
  let t = create 1 in
  let () =
    match sigs with
    | None -> ()
    | Some rsigs ->
      let (before,after) = incr_agent rsigs in
      List.iter
        (fun ag ->
           if Signature.is_counter ag.a_type sigs then
             let a = ag.a_ports.(after) in
             let b = ag.a_ports.(before) in
             match b with
             | FREE -> ()
             | VAL lnk_b ->
               match a with
               | FREE ->
                 (* in this case the endpoint of the chain of increments is raw:
                    the agent is created with a counter value*)
                 let root = find t lnk_b in
                 let (s,_) = Mods.DynArray.get t.rank root in
                 Mods.DynArray.set t.rank root (s-1,(true,true))
               | VAL lnk_a -> union t lnk_b lnk_a) mix in
  t

let print_link incr_agents f = function
  | FREE -> Format.pp_print_string f "[.]"
  | VAL i ->
     try
       let root = find incr_agents i in
       let (counter,(_,is_counter)) = Mods.DynArray.get incr_agents.rank root in
       if (is_counter)&&not(!Parameter.debugModeOn) then
         Format.fprintf f "{=%d}" counter
       else Format.fprintf f "[%i]" i
     with Invalid_argument _ -> Format.fprintf f "[%i]" i

let aux_pp_si sigs a s f i =
  match sigs with
  | Some sigs -> Signature.print_site_internal_state sigs a s f i
  | None ->
    match i with
    | Some i -> Format.fprintf f "%i{%i}" s i
    | None -> Format.pp_print_int f s

let print_intf with_link ?sigs incr_agents ag_ty f (ports,ints) =
  let rec aux empty i =
    if i < Array.length ports then
      let () = Format.fprintf
          f "%t%a%a"
          (if empty then Pp.empty else Pp.space)
          (aux_pp_si sigs ag_ty i) ints.(i)
          (if with_link then print_link incr_agents else (fun _ _ -> ()))
          ports.(i) in
      aux false (succ i) in
  aux true 0

let aux_pp_ag sigs f a =
  match sigs with
  | Some sigs -> Signature.print_agent sigs f a
  | None -> Format.pp_print_int f a

let print_agent created link ?sigs incr_agents f ag =
  Format.fprintf f "%a(@[<h>%a@])%t"
      (aux_pp_ag sigs) ag.a_type
      (print_intf link ?sigs incr_agents ag.a_type) (ag.a_ports, ag.a_ints)
      (fun f -> if created then Format.pp_print_string f "+")

let print ~created ?sigs f mix =
  let mix_without_counters = if (!Parameter.debugModeOn) then mix else
    List.filter
      (fun ag -> not(Signature.is_counter ag.a_type sigs)) mix in
  let incr_agents = union_find_counters sigs mix in
  Pp.list
    Pp.comma
    (print_agent created true ?sigs incr_agents)
    f mix_without_counters

let agent_to_json a =
  `Assoc
    [("type",`Int a.a_type);
     ("sites", `List
        (Array.fold_right (fun x acc ->
             (match x with FREE -> `Null|VAL i -> `Int i)::acc) a.a_ports []));
     ("internals", `List
        (Array.fold_right (fun x acc ->
             (match x with None -> `Null|Some i -> `Int i)::acc) a.a_ints []))]
let agent_of_json = function
  | (`Assoc [("type",`Int t);("sites",`List s);("internals",`List i)] |
     `Assoc [("type",`Int t);("internals",`List i);("sites",`List s)] |
     `Assoc [("internals",`List i);("type",`Int t);("sites",`List s)] |
     `Assoc [("internals",`List i);("sites",`List s);("type",`Int t)] |
     `Assoc [("sites",`List s);("internals",`List i);("type",`Int t)] |
     `Assoc [("sites",`List s);("type",`Int t);("internals",`List i)]) ->
    { a_type = t;
      a_ports =
        Tools.array_map_of_list (function
            | `Null -> FREE
            | `Int p -> VAL p
            | x ->
              raise (Yojson.Basic.Util.Type_error ("Invalid site link",x)))
          s;
      a_ints =
        Tools.array_map_of_list (function
            | `Null -> None
            | `Int p -> Some p
            | x ->
              raise (Yojson.Basic.Util.Type_error ("Invalid internal state",x)))
          i}
  | x -> raise (Yojson.Basic.Util.Type_error ("Invalid raw_agent",x))

let to_json m = `List (List.map agent_to_json m)
let of_json = function
  | `List l -> List.map agent_of_json l
  | x -> raise (Yojson.Basic.Util.Type_error ("Invalid raw_mixture",x))
