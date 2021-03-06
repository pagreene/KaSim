(******************************************************************************)
(*  _  __ * The Kappa Language                                                *)
(* | |/ / * Copyright 2010-2017 CNRS - Harvard Medical School - INRIA - IRIF  *)
(* | ' /  *********************************************************************)
(* | . \  * This file is distributed under the terms of the                   *)
(* |_|\_\ * GNU Lesser General Public License Version 3                       *)
(******************************************************************************)

val continue_simulation : unit -> unit
val pause_simulation : unit -> unit
val stop_simulation : unit -> unit
val start_simulation : unit -> unit
val perturb_simulation : unit -> unit
val simulation_trace : unit -> unit
val focus_range : Api_types_j.range -> unit
