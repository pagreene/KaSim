(**
   * mvbdu_core.ml
   * openkappa
   * Jérôme Feret, projet Abstraction, INRIA Paris-Rocquencourt
   * 
   * Creation: 2010, the 8th of March 
   * Last modification: 2011, the 23rd of March 
   * * 
   * This library provides primitives to deal set of finite maps from integers to integers
   *  
   * Copyright 2010 Institut National de Recherche en Informatique et   
   * en Automatique.  All rights reserved.  This file is distributed     
   * under the terms of the GNU Library General Public License *)


let sanity_check = true
let test_workbench = false 
  

let invalid_arg parameters mh message exn value = 
  Exception.warn parameters mh (Some "Mvbdu_core") message exn (fun () -> value)

let get_hash_key mvbdu = mvbdu.Mvbdu_sig.id 

let mvbdu_equal a b = a==b
  
let get_skeleton cell = 
  match cell with 
    | Mvbdu_sig.Leaf x -> Mvbdu_sig.Leaf x   
    | Mvbdu_sig.Node x -> 
      Mvbdu_sig.Node 
        {x with 
          Mvbdu_sig.branch_true  = get_hash_key x.Mvbdu_sig.branch_true ; 
          Mvbdu_sig.branch_false = get_hash_key x.Mvbdu_sig.branch_false
        }

let print_flag parameters bool = 
  if bool 
  then Printf.fprintf parameters.Remanent_parameters_sig.log "Yes" 
  else Printf.fprintf parameters.Remanent_parameters_sig.log "No"

let build_already_compressed_cell (allocate:('a,'b,'c) Sanity_test_sig.f)
    error handler skeleton cell = 
  allocate
    error
    compare
    skeleton
    cell
    (fun key -> {Mvbdu_sig.id=key;Mvbdu_sig.value=cell})
    handler  

let compress_node (allocate:('a,'b,'c) Sanity_test_sig.f) error handler cell = 
  match cell with 
    | Mvbdu_sig.Leaf a as x ->
      build_already_compressed_cell
        allocate
        error
        handler
        x
        x    
    | Mvbdu_sig.Node x -> 
      let variable = x.Mvbdu_sig.variable in 
      let bound = x.Mvbdu_sig.upper_bound in 
      let branch_true = x.Mvbdu_sig.branch_true in 
      let branch_false = x.Mvbdu_sig.branch_false in 
      if mvbdu_equal branch_true branch_false 
      then error,
        Some (get_hash_key branch_true,
              branch_true.Mvbdu_sig.value,
              branch_true,
              handler) 
      else  
        match branch_false.Mvbdu_sig.value with 
          | Mvbdu_sig.Node x when mvbdu_equal x.Mvbdu_sig.branch_true branch_true ->
            error, Some (get_hash_key branch_false,
                         branch_false.Mvbdu_sig.value,
                         branch_false,
                         handler)  
          | _ -> 
            (build_already_compressed_cell 
               allocate 
               error 
               handler
               (Mvbdu_sig.Node 
                  {
                    Mvbdu_sig.branch_true = branch_true.Mvbdu_sig.id ;
                    Mvbdu_sig.branch_false = branch_false.Mvbdu_sig.id;
                    Mvbdu_sig.variable = variable ;
                    Mvbdu_sig.upper_bound = bound
                  })  
               (Mvbdu_sig.Node 
                  {
                    Mvbdu_sig.branch_true = branch_true;
                    Mvbdu_sig.branch_false = branch_false ;
                    Mvbdu_sig.variable = variable ;
                    Mvbdu_sig.upper_bound = bound
                  }))
              
let rec print_mvbdu error print_leaf string_of_var parameters mvbdu = 
  match mvbdu.Mvbdu_sig.value with 
    | Mvbdu_sig.Leaf a -> print_leaf error parameters a 
    | Mvbdu_sig.Node x -> 
      let parameters' = Remanent_parameters.update_prefix parameters " " in
      let _ =
        Printf.fprintf parameters.Remanent_parameters_sig.log
          "%s if(%d) %s < %d then \n"
          parameters.Remanent_parameters_sig.marshalisable_parameters.prefix 
          mvbdu.Mvbdu_sig.id
          (string_of_var x.Mvbdu_sig.variable) 
          x.Mvbdu_sig.upper_bound 
      in 
      let error =
        print_mvbdu
          error
          print_leaf 
          string_of_var
          parameters'
          x.Mvbdu_sig.branch_true
      in 
      let _ =
        Printf.fprintf parameters.Remanent_parameters_sig.log
          "%s else \n" 
          parameters.Remanent_parameters_sig.marshalisable_parameters.prefix 
      in 
      let error  =
        print_mvbdu
          error 
          print_leaf
          string_of_var
          parameters' 
          x.Mvbdu_sig.branch_false 
      in
      error 
        
let id_of_mvbdu x = x.Mvbdu_sig.id

let update_dictionary handler dictionary = 
  if handler.Memo_sig.mvbdu_dictionary == dictionary 
  then 
    handler 
  else  
    {handler with Memo_sig.mvbdu_dictionary = dictionary}
