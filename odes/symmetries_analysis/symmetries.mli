(**
   * symmetries.ml
   * openkappa
   * Jérôme Feret & Ly Kim Quyen, projet Antique, INRIA Paris-Rocquencourt
   *
   * Creation: 2016, the 5th of December
   * Last modification: Time-stamp: <Mar 16 2017>
   *
   * Abstract domain to record relations between pair of sites in connected agents.
   *
   * Copyright 2010,2011,2012,2013,2014,2015,2016 Institut National de Recherche
   * en Informatique et en Automatique.
   * All rights reserved.  This file is distributed
   * under the terms of the GNU Library General Public License *)

(*******************************************************************)
(*TYPE*)
(*******************************************************************)

type symmetries =
  {
    rules : int Symmetries_sig.site_partition array;
    rules_and_initial_states :
      int Symmetries_sig.site_partition array option;
    rules_and_alg_expr :
      int Symmetries_sig.site_partition array option;
  }

(*******************************************************************)
(*PARTITION THE CONTACT MAP*)
(*******************************************************************)

val rate : Primitives.elementary_rule ->
  int * Rule_modes.arity * Rule_modes.direction ->
  Alg_expr.t Locality.annot option

val valid_modes :
  Primitives.elementary_rule -> int ->
  (int * Rule_modes.arity * Rule_modes.direction) list

val species_to_lkappa_rule :
  Remanent_parameters_sig.parameters -> Model.t ->
  Pattern.cc -> LKappa.rule

val build_array_for_symmetries:
  LKappa_auto.RuleCache.hashed_list list ->
  bool array * int array * 'a Rule_modes.RuleModeMap.t array * int
    array

val divide_rule_rate_by :
  LKappa_auto.cache ->
  Model.t ->
  Remanent_parameters_sig.rate_convention ->
  Primitives.elementary_rule ->
  LKappa.rule -> LKappa_auto.cache * int * int

val cannonic_form_from_syntactic_rules :
LKappa_auto.cache ->
Model.t ->
Remanent_parameters_sig.rate_convention ->
LKappa.rule list ->
Primitives.elementary_rule list ->
LKappa_auto.cache *
((int * Alg_expr.t Locality.annot Rule_modes.RuleModeMap.t * int) *
 (int * Alg_expr.t Locality.annot Rule_modes.RuleModeMap.t * int))
  list *
((LKappa_auto.RuleCache.hashed_list * LKappa.rule) *
 (LKappa_auto.RuleCache.hashed_list * LKappa.rule))
  list

val detect_symmetries:
Remanent_parameters_sig.parameters ->
Model.t ->
LKappa_auto.cache ->
((LKappa_auto.RuleCache.hashed_list * LKappa.rule) *
 (LKappa_auto.RuleCache.hashed_list * LKappa.rule))
  list ->
bool array * int array *
('a, 'b) Alg_expr.e Locality.annot Rule_modes.RuleModeMap.t array *
int array ->
bool array * int array *
('c, 'd) Alg_expr.e Locality.annot Rule_modes.RuleModeMap.t array *
int array ->
(string list * (string * string) list) Mods.StringMap.t
  Mods.StringMap.t -> LKappa_auto.cache * symmetries

val print_symmetries:
  Remanent_parameters_sig.parameters -> Model.t -> symmetries -> unit

type cache

val empty_cache: unit -> cache

val representant:
  ?parameters:Remanent_parameters_sig.parameters ->
  Signature.s -> cache -> LKappa_auto.cache -> Pattern.PreEnv.t -> symmetries -> Pattern.cc
  ->  cache * LKappa_auto.cache * Pattern.PreEnv.t * Pattern.cc