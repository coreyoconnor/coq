(************************************************************************)
(*  v      *   The Coq Proof Assistant  /  The Coq Development Team     *)
(* <O___,, *   INRIA - CNRS - LIX - LRI - PPS - Copyright 1999-2012     *)
(*   \VV/  **************************************************************)
(*    //   *      This file is distributed under the terms of the       *)
(*         *       GNU Lesser General Public License Version 2.1        *)
(************************************************************************)

open Names
open Term
open Declarations
open Environ
open Univ

(** {6 Cooking the constants. } *)

type work_list = Id.t array Cmap.t * Id.t array Mindmap.t

type recipe = {
  d_from : constant_body;
  d_abstract : Sign.named_context;
  d_modlist : work_list }

val cook_constant :
  env -> recipe ->
    constant_def * constant_type * constraints * Sign.section_context


(** {6 Utility functions used in module [Discharge]. } *)

val expmod_constr : work_list -> constr -> constr

val clear_cooking_sharing : unit -> unit



