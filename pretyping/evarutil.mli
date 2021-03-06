(************************************************************************)
(*  v      *   The Coq Proof Assistant  /  The Coq Development Team     *)
(* <O___,, *   INRIA - CNRS - LIX - LRI - PPS - Copyright 1999-2012     *)
(*   \VV/  **************************************************************)
(*    //   *      This file is distributed under the terms of the       *)
(*         *       GNU Lesser General Public License Version 2.1        *)
(************************************************************************)

open Pp
open Util
open Names
open Glob_term
open Term
open Sign
open Evd
open Environ
open Reductionops

(** {5 This modules provides useful functions for unification modulo evars } *)

(** {6 Metas} *)

(** [new_meta] is a generator of unique meta variables *)
val new_meta : unit -> metavariable
val mk_new_meta : unit -> constr

(** [new_untyped_evar] is a generator of unique evar keys *)
val new_untyped_evar : unit -> existential_key

(** {6 Creating a fresh evar given their type and context} *)
val new_evar :
  evar_map -> env -> ?src:Loc.t * Evar_kinds.t -> ?filter:bool list ->
  ?candidates:constr list -> types -> evar_map * constr

(** the same with side-effects *)
val e_new_evar :
  evar_map ref -> env -> ?src:Loc.t * Evar_kinds.t -> ?filter:bool list ->
  ?candidates:constr list -> types -> constr

(** Create a new Type existential variable, as we keep track of 
    them during type-checking and unification. *)
val new_type_evar :
  ?src:Loc.t * Evar_kinds.t -> ?filter:bool list -> evar_map -> env -> evar_map * constr

(** Create a fresh evar in a context different from its definition context:
   [new_evar_instance sign evd ty inst] creates a new evar of context
   [sign] and type [ty], [inst] is a mapping of the evar context to
   the context where the evar should occur. This means that the terms
   of [inst] are typed in the occurrence context and their type (seen
   as a telescope) is [sign] *)
val new_evar_instance :
 named_context_val -> evar_map -> types -> ?src:Loc.t * Evar_kinds.t -> ?filter:bool list -> ?candidates:constr list -> constr list -> evar_map * constr

val make_pure_subst : evar_info -> constr array -> (Id.t * constr) list

(** {6 Instantiate evars} *)

type conv_fun =
  env ->  evar_map -> conv_pb -> constr -> constr -> evar_map * bool

(** [evar_define choose env ev c] try to instantiate [ev] with [c] (typed in [env]),
   possibly solving related unification problems, possibly leaving open
   some problems that cannot be solved in a unique way (except if choose is
   true); fails if the instance is not valid for the given [ev] *)
val evar_define : conv_fun -> ?choose:bool -> env -> evar_map -> 
  existential -> constr -> evar_map

(** {6 Evars/Metas switching...} *)

(** [evars_to_metas] generates new metavariables for each non dependent
   existential and performs the replacement in the given constr; it also
   returns the evar_map extended with dependent evars *)
val evars_to_metas : evar_map -> open_constr -> (evar_map * constr)

val non_instantiated : evar_map -> (evar * evar_info) list

(** {6 Unification utils} *)

(** [head_evar c] returns the head evar of [c] if any *)
exception NoHeadEvar
val head_evar : constr -> existential_key (** may raise NoHeadEvar *)

(* Expand head evar if any *)
val whd_head_evar :  evar_map -> constr -> constr

val is_ground_term :  evar_map -> constr -> bool
val is_ground_env  :  evar_map -> env -> bool
val solve_refl : ?can_drop:bool -> conv_fun -> env ->  evar_map ->
  existential_key -> constr array -> constr array -> evar_map
val solve_evar_evar : ?force:bool ->
  (env -> evar_map -> existential -> constr -> evar_map) -> conv_fun ->
  env ->  evar_map -> existential -> existential -> evar_map

val solve_simple_eqn : conv_fun -> ?choose:bool -> env ->  evar_map ->
  bool option * existential * constr -> evar_map * bool
val reconsider_conv_pbs : conv_fun -> evar_map -> evar_map * bool

(** [check_evars env initial_sigma extended_sigma c] fails if some
   new unresolved evar remains in [c] *)
val check_evars : env -> evar_map -> evar_map -> constr -> unit

val define_evar_as_product : evar_map -> existential -> evar_map * types
val define_evar_as_lambda : env -> evar_map -> existential -> evar_map * types
val define_evar_as_sort : evar_map -> existential -> evar_map * sorts

val is_unification_pattern_evar : env -> evar_map -> existential -> constr list ->
  constr -> constr list option

val is_unification_pattern : env * int -> evar_map -> constr -> constr list ->
  constr -> constr list option

val evar_absorb_arguments : env -> evar_map -> existential -> constr list ->
  evar_map * existential

val solve_pattern_eqn : env -> constr list -> constr -> constr

(** The following functions return the set of evars immediately
    contained in the object, including defined evars *)


val evars_of_term : constr -> Int.Set.t

val evars_of_named_context : named_context -> Int.Set.t
val evars_of_evar_info : evar_info -> Int.Set.t

(** [gather_dependent_evars evm seeds] classifies the evars in [evm]
    as dependent_evars and goals (these may overlap). A goal is an
    evar in [seeds] or an evar appearing in the (partial) definition
    of a goal. A dependent evar is an evar appearing in the type
    (hypotheses and conclusion) of a goal, or in the type or (partial)
    definition of a dependent evar.  The value return is a map
    associating to each dependent evar [None] if it has no (partial)
    definition or [Some s] if [s] is the list of evars appearing in
    its (partial) definition. *)
val gather_dependent_evars : evar_map -> evar list -> (Int.Set.t option) Int.Map.t

(** The following functions return the set of undefined evars
    contained in the object, the defined evars being traversed.
    This is roughly a combination of the previous functions and
    [nf_evar]. *)

val undefined_evars_of_term : evar_map -> constr -> Int.Set.t
val undefined_evars_of_named_context : evar_map -> named_context -> Int.Set.t
val undefined_evars_of_evar_info : evar_map -> evar_info -> Int.Set.t

(** {6 Value/Type constraints} *)

val judge_of_new_Type : evar_map -> evar_map * unsafe_judgment

type type_constraint = types option
type val_constraint = constr option

val empty_tycon : type_constraint
val mk_tycon : constr -> type_constraint
val empty_valcon : val_constraint
val mk_valcon : constr -> val_constraint

val split_tycon :
  Loc.t -> env ->  evar_map -> type_constraint ->
    evar_map * (Name.t * type_constraint * type_constraint)

val valcon_of_tycon : type_constraint -> val_constraint
val lift_tycon : int -> type_constraint -> type_constraint

(***********************************************************)

(** [flush_and_check_evars] raise [Uninstantiated_evar] if an evar remains
    uninstantiated; [nf_evar] leaves uninstantiated evars as is *)

val nf_evar :  evar_map -> constr -> constr
val j_nf_evar :  evar_map -> unsafe_judgment -> unsafe_judgment
val jl_nf_evar :
   evar_map -> unsafe_judgment list -> unsafe_judgment list
val jv_nf_evar :
   evar_map -> unsafe_judgment array -> unsafe_judgment array
val tj_nf_evar :
   evar_map -> unsafe_type_judgment -> unsafe_type_judgment

val nf_named_context_evar : evar_map -> named_context -> named_context
val nf_rel_context_evar : evar_map -> rel_context -> rel_context
val nf_env_evar : evar_map -> env -> env

val nf_evar_info : evar_map -> evar_info -> evar_info
val nf_evar_map : evar_map -> evar_map
val nf_evar_map_undefined : evar_map -> evar_map

(** Replacing all evars, possibly raising [Uninstantiated_evar] *)
exception Uninstantiated_evar of existential_key
val flush_and_check_evars :  evar_map -> constr -> constr

(** Replace the vars and rels that are aliases to other vars and rels by 
   their representative that is most ancient in the context *)
val expand_vars_in_term : env -> constr -> constr

(** {6 debug pretty-printer:} *)

val pr_tycon : env -> type_constraint -> Pp.std_ppcmds


(** {6 Removing hyps in evars'context}
raise OccurHypInSimpleClause if the removal breaks dependencies *)

type clear_dependency_error =
| OccurHypInSimpleClause of Id.t option
| EvarTypingBreak of existential

exception ClearDependencyError of Id.t * clear_dependency_error

(* spiwack: marks an evar that has been "defined" by clear.
    used by [Goal] and (indirectly) [Proofview] to handle the clear tactic gracefully*)
val cleared : bool Store.Field.t

val clear_hyps_in_evi : evar_map ref -> named_context_val -> types ->
  Id.t list -> named_context_val * types

val push_rel_context_to_named_context : Environ.env -> types ->
  named_context_val * types * constr list * constr list

val generalize_evar_over_rels : evar_map -> existential -> types * constr list

val check_evar_instance : evar_map -> existential_key -> constr -> conv_fun ->
  evar_map

