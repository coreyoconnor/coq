(************************************************************************)
(*  v      *   The Coq Proof Assistant  /  The Coq Development Team     *)
(* <O___,, *   INRIA - CNRS - LIX - LRI - PPS - Copyright 1999-2012     *)
(*   \VV/  **************************************************************)
(*    //   *      This file is distributed under the terms of the       *)
(*         *       GNU Lesser General Public License Version 2.1        *)
(************************************************************************)

(*i camlp4deps: "tools/compat5b.cmo" i*)

open Pp
open Util
open Q_util
open Argextend
open Tacextend
open Pcoq
open Egramml
open Compat

let rec make_let e = function
  | [] -> e
  | GramNonTerminal(loc,t,_,Some p)::l ->
      let loc = of_coqloc loc in
      let p = Names.Id.to_string p in
      let loc = CompatLoc.merge loc (MLast.loc_of_expr e) in
      let e = make_let e l in
      <:expr< let $lid:p$ = Genarg.out_gen $make_rawwit loc t$ $lid:p$ in $e$ >>
  | _::l -> make_let e l

let check_unicity s l =
  let l' = List.map (fun (_,l,_) -> extract_signature l) l in
  if not (Util.List.distinct l') then
    Pp.msg_warning
      (strbrk ("Two distinct rules of entry "^s^" have the same "^
      "non-terminals in the same order: put them in distinct vernac entries"))

let make_clause (_,pt,e) =
  (make_patt pt,
   vala (Some (make_when (MLast.loc_of_expr e) pt)),
   make_let e pt)

let make_fun_clauses loc s l =
  check_unicity s l;
  Compat.make_fun loc (List.map make_clause l)

let mlexpr_of_clause =
  mlexpr_of_list
    (fun (a,b,c) -> mlexpr_of_list make_prod_item
       (Option.List.cons (Option.map (fun a -> GramTerminal a) a) b))

let declare_command loc s nt cl =
  let se = mlexpr_of_string s in
  let gl = mlexpr_of_clause cl in
  let funcl = make_fun_clauses loc s cl in
  declare_str_items loc
    [ <:str_item< do {
	try Vernacinterp.vinterp_add $se$ $funcl$
	with e ->
	  Pp.msg_warning
	    (Pp.app
	       (Pp.str ("Exception in vernac extend " ^ $se$ ^": "))
	       (Errors.print e));
	Egramml.extend_vernac_command_grammar $se$ $nt$ $gl$
      } >> ]

open Pcaml
open PcamlSig

EXTEND
  GLOBAL: str_item;
  str_item:
    [ [ "VERNAC"; "COMMAND"; "EXTEND"; s = UIDENT;
        OPT "|"; l = LIST1 rule SEP "|";
        "END" ->
         declare_command loc s <:expr<None>> l
      | "VERNAC"; nt = LIDENT ; "EXTEND"; s = UIDENT;
        OPT "|"; l = LIST1 rule SEP "|";
        "END" ->
          declare_command loc s <:expr<Some $lid:nt$>> l ] ]
  ;
  (* spiwack: comment-by-guessing: it seems that the isolated string (which
      otherwise could have been another argument) is not passed to the
      VernacExtend interpreter function to discriminate between the clauses. *)
  rule:
    [ [ "["; s = STRING; l = LIST0 args; "]"; "->"; "["; e = Pcaml.expr; "]"
        ->
      if String.is_empty s then Errors.user_err_loc (!@loc,"",Pp.str"Command name is empty.");
      (Some s,l,<:expr< fun () -> $e$ >>)
      | "[" ; "-" ; l = LIST1 args ; "]" ; "->" ; "[" ; e = Pcaml.expr ; "]" ->
	  (None,l,<:expr< fun () -> $e$ >>)
    ] ]
  ;
  args:
    [ [ e = LIDENT; "("; s = LIDENT; ")" ->
        let t, g = interp_entry_name false None e "" in
        GramNonTerminal (!@loc, t, g, Some (Names.Id.of_string s))
      | e = LIDENT; "("; s = LIDENT; ","; sep = STRING; ")" ->
        let t, g = interp_entry_name false None e sep in
        GramNonTerminal (!@loc, t, g, Some (Names.Id.of_string s))
      | s = STRING ->
        GramTerminal s
    ] ]
  ;
  END
;;
