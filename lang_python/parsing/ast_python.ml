(* Yoann Padioleau
 *
 * Copyright (C) 2010 Facebook
 * Copyright (C) 2011-2015 Tomohiro Matsuyama
 * Copyright (C) 2019 r2c
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public License
 * version 2.1 as published by the Free Software Foundation, with the
 * special exception on linking described in file license.txt.
 * 
 * This library is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the file
 * license.txt for more details.
 *)

(*****************************************************************************)
(* Prelude *)
(*****************************************************************************)
(* Abstract Syntax Tree for Python.
 *
 * Most of the code in this file derives from code from 
 * Tomohiro Matsuyama in ocaml-pythonlib, which itself derives from
 * the official grammar definition of Python.
 *
 * reference: http://docs.python.org/3/library/ast.html 
 *
 * See also:
 *  - http://trevorjim.com/python-is-not-context-free/
 * 
 * related work:
 *  - https://github.com/m2ym/ocaml-pythonlib
 *    The original code. The repo was also forked by jeremy buisson
 *    who added a very basic simplifier but remains mostly the same.
 *  - Pyre-check
 *    typechecker and taint-tracker for Python, written in OCaml from facebook
 *  - https://github.com/mattgreen/hython
 *    Python3 interpreter written in Haskell
 *  - libCST (a concrete syntax tree, better for program transformation)
 *    by Instagram
 * 
 * history:
 *  - 2019 port to the pfff infrastructure.
 *  - 2019 modified to support types, and many other Python 3 features
 *)

(*****************************************************************************)
(* The AST related types *)
(*****************************************************************************)
(* ------------------------------------------------------------------------- *)
(* Token/info *)
(* ------------------------------------------------------------------------- *)

(* Contains among other things the position of the token through
 * the Parse_info.token_location embedded inside it, as well as the
 * transformation field that makes possible spatch on the code.
 *)
type tok = Parse_info.info
 (* with tarzan *)

(* a shortcut to annotate some information with token/position information *)
type 'a wrap = 'a * tok
 (* with tarzan *)

(* ------------------------------------------------------------------------- *)
(* Name *)
(* ------------------------------------------------------------------------- *)
type name = string wrap
 (* with tarzan *)

type dotted_name = name list
 (* with tarzan *)

type resolved_name =
  (* this can be computed by a visitor *)
  | LocalVar
  | Parameter
  | GlobalVar
  | ClassField
  | ImportedModule
  | ImportedEntity

  (* default case *)
  | NotResolved
 (* with tarzan *)

(* ------------------------------------------------------------------------- *)
(* Expression *)
(* ------------------------------------------------------------------------- *)
type expr =
  | Num of number (* n *)
  | Str of (string wrap) list (* s *)
  (* python3-ext: officially reserved keywords in python3 *)
  | Bool of bool wrap
  | ExprNone of tok

  (* introduce new vars when expr_context = Store *)
  | Name of name (* id *) * expr_context (* ctx *) * resolved_name ref

  | Tuple of expr list_or_comprehension (* elts *)  * expr_context (* ctx *)
  | List of expr list_or_comprehension (* elts *)   * expr_context (* ctx *)
  | DictOrSet of dictorset_elt list_or_comprehension

  (* python3-ext: *)
  | ExprStar of expr (* less: expr_context? always Store anyway no? *)

  (* python3-ext: *)
  (* inside an Assign (or ExprStmt) *)
  | TypedExpr of expr * type_
  | Ellipses of tok (* should be only in .pyi, types Dict[str,...], or sgrep *)

  | BoolOp of boolop (* op *) * expr list (* values *)
  | BinOp of expr (* left *) * operator (* op *) * expr (* right *)
  | UnaryOp of unaryop (* op *) * expr (* operand *)
  | Compare of expr (* left *) * cmpop list (* ops *) * expr list (* comparators *)

  (* note that Python does not have a 'new' keyword, a call with the name
   * of a class is a New *)
  | Call of expr (* func *) * argument list (* args *)

  | Subscript of expr (* value *) * slice list (* slice *) * expr_context

  (* the parameters do not have types here *)
  | Lambda of parameters (* args *) * expr (* body *)

  | IfExp of expr (* test *) * expr (* body *) * expr (* orelse *)

  | Yield of expr option (* value *)
  (* python3-ext: *)
  | Await of expr

  | Repr of expr (* value *)
  (* =~ ObjAccess *)
  | Attribute of expr (* value *) * name (* attr *) * expr_context (* ctx *)

  and number =
    | Int of string wrap
    | LongInt of string wrap
    | Float of string wrap
    | Imag of string wrap
  
  and boolop = And | Or
  
  and operator = 
    | Add | Sub | Mult | Div 
    | Mod | Pow | FloorDiv
    | LShift | RShift 
    | BitOr | BitXor | BitAnd 
  
  and unaryop = Invert | Not | UAdd | USub
  
  and cmpop = 
    | Eq | NotEq 
    | Lt | LtE | Gt | GtE 
    | Is | IsNot 
    | In | NotIn
  
  and 'a list_or_comprehension = 
    | CompList of 'a list
    | CompForIf of 'a comprehension

    and 'a comprehension = 'a * for_if list
      and for_if =
      | CompFor of expr (* introduce new vars *) * (* in *) expr
      | CompIf of expr
  
  and dictorset_elt = 
    | KeyVal of expr * expr
    | Key of expr
    (* python3-ext: *)
    | PowInline of expr
  
  (* AugLoad and AugStore are not used *)
  and expr_context = 
    | Load | Store 
    | Del 
    | AugLoad | AugStore
    | Param
  
  and slice =
    | Slice of expr option (* lower *) * expr option (* upper *) * expr option (* step *)
    | Index of expr (* value *)
  
  and parameters = parameter list
   and parameter = 
      (* the first expr can be only a Name or a Tuple (pattern?),
       * and the Name can have a type associated with it
       *)
     | ParamClassic of (name * type_ option) * expr option (* default value *)
     | ParamStar of (name * type_ option)
     | ParamPow  of (name * type_ option)
  
  and argument = 
    | Arg of expr
    | ArgKwd of name (* arg *) * expr (* value *)
    | ArgStar of expr
    | ArgPow of expr
    | ArgComp of expr * for_if list
 
  
(* ------------------------------------------------------------------------- *)
(* Types *)
(* ------------------------------------------------------------------------- *)
(* see https://docs.python.org/3/library/typing.html for the semantic
 * and https://www.python.org/dev/peps/pep-3107/ (function annotations)
 * for https://www.python.org/dev/peps/pep-0526/ (variable annotations)
 * for its syntax.
 *)
and type_ = expr

(* used in inheritance, to allow default value for metaclass *)
and type_parent = argument
  (* with tarzan *)

(* ------------------------------------------------------------------------- *)
(* Patterns *)
(* ------------------------------------------------------------------------- *)
(* Name, or Tuple? or more? *)
type pattern = expr
  
(* ------------------------------------------------------------------------- *)
(* Statement *)
(* ------------------------------------------------------------------------- *)
type stmt =
  | ExprStmt of expr (* value *)

  (* the left expr should be an lvalue: Name, List, Tuple, Subscript,
   * or Attribute, or ExprStar, which are anything with an expr_context
   * (see also Parser_python.set_expr_ctx).
   * This can introduce new vars.
   * todo: why take an expr list? can reuse Tuple for tuple assignment
   *)
  | Assign of expr list (* targets *) * expr (* value *)
  | AugAssign of expr (* target *) * operator (* op *) * expr (* value *)

  | For of pattern (* (pattern) introduce new vars *) * expr (* 'in' iter *) * 
           stmt list (* body *) * stmt list (* orelse *)
  | While of expr (* test *) * stmt list (* body *) * stmt list (* orelse *)
  | If of expr (* test *) * stmt list (* body *) * stmt list (* orelse *)
  | With of expr (* context_expr *) * expr option (* optional_vars *) * stmt list (* body *)

  | Return of expr option (* value *)
  | Break | Continue
  | Pass

  | Raise of (expr * expr option (* from *)) option
  | TryExcept of stmt list (* body *) * excepthandler list (* handlers *) * stmt list (* orelse *)
  | TryFinally of stmt list (* body *) * stmt list (* finalbody *)
  | Assert of expr (* test *) * expr option (* msg *)

  | Global of name list (* names *)
  | Delete of expr list (* targets *)
  (* python3-ext: *)
  | NonLocal of name list (* names *)

  (* python3-ext: for With, For, and FunctionDef *)
  | Async of stmt

  | Import of alias_dotted list (* names *)
  | ImportFrom of dotted_name (* module *) * alias list (* names *) * int option (* level *)

  (* should be allowed just at the toplevel *)
  | FunctionDef of 
       name (* name *) * 
       parameters (* args *) * 
       type_ option * (* return type *)
       stmt list (* body *) * 
       decorator list (* decorator_list *)

  | ClassDef of 
        name (* name *) * 
        type_parent list (* bases *) * 
        stmt list (* body *) * 
        decorator list (* decorator_list *)


and excepthandler = 
  ExceptHandler of 
    type_ option (* type *) * 
    expr option (* name, introduce new var *) * 
    stmt list (* body *)


(* ------------------------------------------------------------------------- *)
(* Decorators (a.k.a annotations) *)
(* ------------------------------------------------------------------------- *)
and decorator = expr

(* ------------------------------------------------------------------------- *)
(* Function (or method) definition *)
(* ------------------------------------------------------------------------- *)

(* ------------------------------------------------------------------------- *)
(* Variable definition *)
(* ------------------------------------------------------------------------- *)

(* ------------------------------------------------------------------------- *)
(* Class definition *)
(* ------------------------------------------------------------------------- *)

(* ------------------------------------------------------------------------- *)
(* Module import/export *)
(* ------------------------------------------------------------------------- *)
and alias = name (* name *) * name option (* asname *)
and alias_dotted = dotted_name (* name *) * name option (* asname *)
  (* with tarzan *)

(* ------------------------------------------------------------------------- *)
(* Toplevel *)
(* ------------------------------------------------------------------------- *)
type program = stmt list
  (* with tarzan *)

(* ------------------------------------------------------------------------- *)
(* Any *)
(* ------------------------------------------------------------------------- *)
type any =
  | Expr of expr
  | Stmt of stmt
  | Stmts of stmt list
  | Program of program

  | DictElem of dictorset_elt
 (* with tarzan *)

(*****************************************************************************)
(* Wrappers *)
(*****************************************************************************)
let str_of_name = fst

(*****************************************************************************)
(* Accessors *)
(*****************************************************************************)
let context_of_expr = function
  | Attribute (_, _, ctx) -> Some ctx
  | Subscript (_, _, ctx) -> Some ctx
  | Name (_, ctx, _)   -> Some ctx
  | List (_, ctx)         -> Some ctx
  | Tuple (_, ctx)        -> Some ctx
  | _                     -> None
