(******************************************************************************)
(*                                                                            *)
(*                                    Menhir                                  *)
(*                                                                            *)
(*   Copyright Inria. All rights reserved. This file is distributed under     *)
(*   the terms of the GNU General Public License version 2, as described in   *)
(*   the file LICENSE.                                                        *)
(*                                                                            *)
(******************************************************************************)

open Positions

(* Abstract syntax of the language used for code production. *)

type interface =
  interface_item list

and interface_item =
    (* Functor. Called [Make]. No functor if no parameters. Very ad hoc! *)
  | IIFunctor of Stretch.t list * interface
    (* Exception declarations. *)
  | IIExcDecls of excdef list
    (* Algebraic data type declarations (mutually recursive). *)
  | IITypeDecls of typedef list
    (* Value declarations. *)
  | IIValDecls of (string * typescheme) list
    (* Include directive. *)
  | IIInclude of module_type
    (* Submodule. *)
  | IIModule of string * module_type
    (* Comment. *)
  | IIComment of string
    (* Class. *)
  | IIClass of
      (* virtual? *)              virtuality *
      (* type parameters: *)      typeparams *
      (* class name: *)           class_name *
      (* self type annotation: *) typ option *
      (* content: *)              class_field_specs

and module_type =
  | MTNamedModuleType of string
  | MTWithType of module_type * string list * string * with_kind * typ
  | MTSigEnd of interface

and with_kind =
  | WKNonDestructive (* = *)
  | WKDestructive   (* := *)

and excdef = {

    (* Name of the exception. *)
    excname: string;

    (* Optional equality. *)
    exceq: string option;

    (* Optional parameters. *)
    excparams: typ list;

  }

and typedef = {

    (* Name of the algebraic data type. *)
    typename: string;

    (* Type parameters. *)
    typeparams: typeparams;

    (* Data constructors. *)
    typerhs: typedefrhs;

    (* Constraint. *)
    typeconstraint: (typ * typ) option

  }

and typeparams =
  typeparam list

(* A type parameter is a type variable name, without the leading quote, which
   will be added by the pretty-printer. It can also be "_". *)

and typeparam =
  string

and typedefrhs =
  | TDefRecord of fielddef list
  | TDefSum of datadef list
  | TAbbrev of typ
  | TAbstract

and fielddef = {

    (* Whether the field is mutable. *)
    modifiable: bool;

    (* Name of the field. *)
    fieldname: string;

    (* Type of the field. *)
    fieldtype: typescheme

  }

and datadef = {

    (* Name of the data constructor. *)
    dataname: string;

    (* Types of the value parameters. *)
    datavalparams: typ list;

    (* Instantiated type parameters, if this is a GADT --
       [None] if this is an ordinary ADT. *)
    datatypeparams: typ list option;

    (* A comment about this data constructor. *)
    comment: string option;

    (* An optional [@@unboxed] attribute. This attribute can be used only
       if there is a single data constructor and it carries a single field.
       This attribute is recognized by OCaml 4.04 and ignored by earlier
       versions of OCaml. *)
    unboxed: bool;

  }

and typ =

  (* Textual OCaml type. *)
  | TypTextual of Stretch.ocamltype

  (* Type variable, without its leading quote. Can also be "_". *)
  | TypVar of string

  (* Application of an algebraic data type constructor. *)
  | TypApp of string * typ list

  (* Anonymous tuple. *)
  | TypTuple of typ list

  (* Arrow type. *)
  | TypArrow of typ * typ

  (* Type sharing construct. *)
  | TypAs of typ * string

and typescheme = {

  (* Universal quantifiers, without leading quotes. *)
  quantifiers: string list;

  (* Whether the quantifiers are locally abstract. An OCaml locally abstract
     type is bound by [type a] and referred to as [a]. Such a reference is
     internally represented as a [TypApp] node. An ordinary type variable is
     bound by ['a] and referred to as ['a]. Such a reference is internally
     represented as a [TypVar] node. *)
  locally_abstract: bool;

  (* Body. *)
  body: typ;

  }

and valdef = {

  (* Whether the value is public. Public values cannot be
     suppressed by the inliner. They serve as seeds for the
     dead code analysis. *)

  valpublic: bool;

  (* Definition's left-hand side. *)
  valpat: pattern;

  (* Value to which it is bound. *)
  valval: expr

  }

and expr =

  (* Variable. *)
  | EVar of string

  (* Function. *)
  | EFun of pattern list * expr

  (* Function call. *)
  | EApp of expr * expr list

  (* Method call. *)
  | EMethodCall of expr * method_name

  (* Local definitions. This is a nested sequence of [let]
     definitions. *)
  | ELet of (pattern * expr) list * expr

  (* Case analysis. *)
  | EMatch of expr * branch list
  | EIfThen of expr * expr
  | EIfThenElse of expr * expr * expr

  (* An expression that claims to be dead code. *)
  | EDead

  (* A divergent expression. *)
  | EBottom

  (* Raising exceptions. *)
  | ERaise of expr

  (* Exception analysis. *)
  | ETry of expr * branch list

  (* Data construction. Tuples of length 1 are considered nonexistent,
     that is, [ETuple [e]] is considered the same expression as [e]. *)

  | EUnit
  | EIntConst of int
  | EStringConst of string
  | EData of string * expr list
  | ETuple of expr list

  (* Type annotation. *)
  | EAnnot of expr * typescheme

  (* Cheating on the typechecker. *)
  | EMagic of expr (* Obj.magic *)
  | ERepr of expr  (* Obj.repr *)

  (* Records. *)
  | ERecord of (string * expr) list
  | ERecordAccess of expr * string
  | ERecordWrite of expr * string * expr

  (* Textual OCaml code. *)
  | ETextual of Stretch.t

  (* Comments. *)
  | EComment of string * expr
  | EPatComment of string * pattern * expr

  (* Arrays. *)
  | EArray of expr list
  | EArrayAccess of expr * expr

and branch = {

  (* Branch pattern. *)
  branchpat: pattern;

  (* Branch body. *)
  branchbody: expr;

  }

and pattern =

  (* Wildcard. *)
  | PWildcard

  (* Variable. *)
  | PVar of string
  | PVarLocated of string located
      (* The positions must not be dummies. Use [pvarlocated]. *)

  (* Data deconstruction. Tuples of length 1 are considered nonexistent,
     that is, [PTuple [p]] is considered the same pattern as [p]. *)
  | PUnit
  | PData of string * pattern list
  | PTuple of pattern list
  | PRecord of (string * pattern) list

  (* Disjunction. *)
  | POr of pattern list

  (* Type annotation. *)
  | PAnnot of pattern * typ

(* Module expressions. *)

and modexpr =
    | MVar of string
    | MStruct of structure
    | MApp of modexpr * modexpr

(* Structures. *)

and program =
    structure

and structure =
    structure_item list

and structure_item =
    (* Functor. Called [Make]. No functor if no parameters. Very ad hoc! *)
  | SIFunctor of Stretch.t list * structure
    (* Exception definitions. *)
  | SIExcDefs of excdef list
    (* Algebraic data type definitions (mutually recursive). *)
  | SITypeDefs of typedef list
    (* Value definitions (mutually recursive or not, as per the flag). *)
  | SIValDefs of bool * valdef list
    (* Raw OCaml code. *)
  | SIStretch of Stretch.t list
    (* Sub-module definition. *)
  | SIModuleDef of string * modexpr
    (* Module inclusion. *)
  | SIInclude of modexpr
    (* Comment. *)
  | SIComment of string
    (* Toplevel attribute. *)
  | SIAttribute of (* attribute: *) string * (* payload: *) string
    (* Class. *)
  | SIClass of
      (* virtual? *)              virtuality *
      (* type parameters: *)      typeparams *
      (* class name: *)           class_name *
      (* self type annotation: *) typ option *
      (* content: *)              class_fields

(* Objects. *)

and virtuality =
  | NonVirtual
  | Virtual

and privacy =
  | Public
  | Private

and class_fields =
  class_field list

and class_field =
    (* Method definition. *)
  | CFMethod of privacy * method_name * expr
    (* Virtual method declaration. *)
  | CFMethodVirtual of method_name * typescheme
    (* Comment. *)
  | CFComment of string

and class_field_specs =
  class_field_spec list

and class_field_spec =
    (* Method declaration. *)
  | CFSMethod of virtuality * method_name * typescheme
    (* Comment. *)
  | CFSComment of string

and class_name =
  string

and method_name =
  string

(* A type of parameters, with injections both into patterns (formal parameters)
   and into expressions (actual parameters). *)

type xparam =
  | XVar of string
  | XMagic of xparam

let xvar x =
  XVar x

let xmagic xp =
  XMagic xp

let rec xparam2expr = function
  | XVar x ->
      EVar x
  | XMagic xp ->
      EMagic (xparam2expr xp)

let rec xparam2pat = function
  | XVar x ->
      PVar x
  | XMagic xp ->
      xparam2pat xp (* no magic *)

type xparams =
  xparam list

let xparams2exprs xps =
  List.map xparam2expr xps

let xparams2pats xps =
  List.map xparam2pat xps
