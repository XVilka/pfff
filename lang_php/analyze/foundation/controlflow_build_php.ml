(*s: controlflow_build_php.ml *)
(*s: Facebook copyright *)
(* Yoann Padioleau
 *
 * Copyright (C) 2009, 2010, 2011 Facebook
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
(*e: Facebook copyright *)
open Common

open Cst_php
module Ast = Cst_php
module F = Controlflow_php

(*****************************************************************************)
(* Prelude *)
(*****************************************************************************)
(*
 * less: start from ast_php_simple? would not need those stmts_of_colon_stmt()
 * functions then. But we need to have position information for the nodes
 * for good error reports and right now ast_php_simple keep position
 * information only for identifiers so let's stay with ast_php for now.
 *)

(*****************************************************************************)
(* Types *)
(*****************************************************************************)

(*s: type nodei *)
(* an int representing the index of a node in the graph *)
type nodei = Ograph_extended.nodei
(*e: type nodei *)

(*s: type state *)
(* Information passed recursively in cfg_stmt or cfg_stmt_list below.
 * The graph g is mutable, so most of the work is done by side effects on it.
 * No need to return a new state.
 *)
type state = {
  g: F.flow;

  (* When there is a 'return' we need to know the exit node to link to *)
  exiti: nodei;

  (* Sometimes when there is a 'continue' or 'break' we must know where
   * to jump and so we must know the node index for the end of the loop.
   * The same kind of information is needed for 'switch' or 'try/throw'.
   *
   * Because loops can be inside switch or try, and vice versa, you need
   * a stack of context.
   *)
  ctx: context Common.stack;
}
 and context =
  | NoCtx
  | LoopCtx   of nodei (* head *) * nodei (* end *)
  | SwitchCtx of nodei (* end *)
  | TryCtx    of nodei (* the first catch *)
(*e: type state *)

(*s: type Controlflow_build_php.error *)
type error = error_kind * Cst_php.info
 and error_kind =
  | DeadCode of Controlflow_php.node_kind
  | NoEnclosingLoop
  | ColonSyntax
  | DynamicBreak
(*e: type Controlflow_build_php.error *)

exception Error of error

(*****************************************************************************)
(* Helpers *)
(*****************************************************************************)

(*s: controlflow_php helpers *)
let stmts_of_stmt_or_defs xs =
  xs +> Common.map_filter (fun stmt_or_def ->
    match stmt_or_def with
    | FuncDefNested _ | ClassDefNested _ ->
        pr2_once ("ignoring nested func/class/interface in CFG");
        None
    | st -> Some st
  )

let stmts_of_colon_stmt colon =
  match colon with
  | SingleStmt stmt -> [stmt]
  | ColonStmt (tok, _, _, _) -> raise (Error (ColonSyntax, tok))

let rec intvalue_of_expr e =
  match e with
  | (Sc (C (Int (i_str, _)))) -> Some (s_to_i i_str)
  | ParenExpr (_, e, _)       -> intvalue_of_expr e
  | _ -> None


(*x: controlflow_php helpers *)
let add_arc (starti, nodei) g =
  g#add_arc ((starti, nodei), F.Direct)

let add_arc_opt (starti_opt, nodei) g =
  starti_opt +> Common.do_option (fun starti ->
    g#add_arc ((starti, nodei), F.Direct)
  )

(*
 * When there is a 'break', 'continue', or 'throw', we need to look up in the
 * stack of contexts whether there is an appropriate one. In the case
 * of 'break/continue', because PHP allows statements like 'break 2;', we also
 * need to know how many upper contexts we need to look for.
 *)
let (lookup_some_ctx:
  ?level:int ->
  ctx_filter:(context -> 'a option) ->
  context list -> 'a option) =
 fun ?(level=1) ~ctx_filter xs ->

   let rec aux depth xs =
     match xs with
     | [] -> None
     | x::xs ->
         (match ctx_filter x with
         | None -> aux depth xs
         | Some a ->
             if depth = level
             then (Some a)
             else
               aux (depth+1) xs
         )
   in
   aux 1 xs

(*e: controlflow_php helpers *)

(*****************************************************************************)
(* Algorithm *)
(*****************************************************************************)

(*s: controlflow_php main algorithm *)
(*
 * The CFG building algorithm works by iteratively visiting the
 * statements in the AST of a function. At each statement,
 * the cfg_stmt function is called, and passed the index of the
 * previous node (if there is one), and returns the index of
 * the created node (if there is one).
 *
 * history:
 *
 * ver1: old code was returning a nodei, but break has no end, so
 * cfg_stmt should return a nodei option.
 *
 * ver2: old code was taking a nodei, but should also take a nodei
 * option. There can be deadcode in the function.
 *
 * subtle: try/throw. The current algo is not very precise, but
 * it's probably good enough for many analysis.
 *)
let rec (cfg_stmt: state -> nodei option -> stmt -> nodei option) =
 fun state previ stmt ->

   let i () = Some (List.hd (Lib_parsing_php.ii_of_any (Stmt2 stmt))) in

   match stmt with
   | ExprStmt (e, _tok) ->
       cfg_expr state F.Normal previ e

   | StaticVars (_, static_vars, _) ->
     let var_list = Ast.uncomma static_vars +> List.map (fun (v, _) -> v) in
     List.fold_left (cfg_var_def state) previ var_list

   | Block xs ->
       let stmts = stmts_of_stmt_or_defs (Ast.unbrace xs) in
       cfg_stmt_list state previ stmts

   | For _ | Foreach _  | While _ ->
     (* previ -> newi ---> newfakethen -> ... -> finalthen -
      *             |---|-----------------------------------|
      *                 |-> newfakelse 
      *)
       let node, colon_stmt = 
         (match stmt with 
         | While (_, e, colon_stmt) ->
             F.WhileHeader (Ast.unparen e), colon_stmt
         | For (_, _, _, _, _, _, _, _, colon_stmt) ->
             F.ForHeader, colon_stmt
         | Foreach (_, _, _, _, _, _, _, colon_stmt) ->
             F.ForeachHeader, colon_stmt
         | _ -> raise Impossible
         )
       in

       let newi = state.g#add_node { F.n = node; i=i() } in
       state.g +> add_arc_opt (previ, newi);

       let newfakethen = state.g#add_node { F.n = F.TrueNode;i=None } in
       let newfakeelse = state.g#add_node { F.n = F.FalseNode;i=None } in
       state.g +> add_arc (newi, newfakethen);
       state.g +> add_arc (newi, newfakeelse);

       let state = { state with
         ctx = LoopCtx (newi, newfakeelse)::state.ctx;
       }
       in
       let finalthen = 
         cfg_colon_stmt state (Some newfakethen) colon_stmt
       in
       state.g +> add_arc_opt (finalthen, newi);
       Some newfakeelse

(* this was a tentative by jiao to work with dataflow_php.ml but it
   has some regression so I've commented it out
   | While (t1, e, colon_stmt) ->
     (* previ -> newi ---> newfakethen -> ... -> finalthen
      *             |--|---------------------------------|
      *                |-> newfakelse -> <rest>
      *)
       let node = F.WhileHeader (Ast.unparen e) in

       let newi = state.g#add_node { F.n = node; i=i() } in
       state.g +> add_arc_opt (previ, newi);

       let newfakethen = state.g#add_node { F.n = F.TrueNode;i=None } in
       let newfakeelse = state.g#add_node { F.n = F.FalseNode;i=None } in
       state.g +> add_arc (newi, newfakethen);
       state.g +> add_arc (newi, newfakeelse);

       let state = { state with
         ctx = LoopCtx (newi, newfakeelse)::state.ctx;
       }
       in
       let finalthen = cfg_colon_stmt state (Some newfakethen) colon_stmt in
       (* let's loop *)
       state.g +> add_arc_opt (finalthen, newi);
       Some newfakeelse

   | For (t1, t2, e1, t3, e2, t4, e5, t6, colon_stmt) ->
     (* previ -> e1i ->newi -> e2i --> newfakethen -> ... -> finalthen -> e5i
      *                  |--------|----------------------------------------|
      *                           |-> newfakelse -> <rest>
      *)
       let exprs = Ast.uncomma e1 in
       let e1i = List.fold_left (cfg_expr state F.SpecialMaybeUnused)
         previ exprs in

       let node = F.ForHeader in
       let newi = state.g#add_node { F.n = node; i=i() } in
       state.g +> add_arc_opt (e1i, newi);

       let exprs = Ast.uncomma e2 in
       let e2i = List.fold_left (cfg_expr state F.Normal)
         (Some newi) exprs in

       let newfakethen = state.g#add_node { F.n = F.TrueNode;i=None } in
       let newfakeelse = state.g#add_node { F.n = F.FalseNode;i=None } in
       state.g +> add_arc_opt (e2i, newfakethen);
       state.g +> add_arc_opt (e2i, newfakeelse);

       (* todo: the head should not be newi but the node just before
        * the increment, see tests/php/controlflow/continue_for.php
        *)
       let state = { state with
         ctx = LoopCtx (newi, newfakeelse)::state.ctx;
       }
       in
       let finalthen = cfg_colon_stmt state (Some newfakethen) colon_stmt in

       let exprs = Ast.uncomma e5 in
       let e5i = List.fold_left (cfg_expr state F.Normal) finalthen exprs in

       state.g +> add_arc_opt (e5i, newi);
       Some newfakeelse

   | Foreach (t1, t2, e1, t3, v_arrow_opt, t4, colon_stmt) ->
     (* previ -> e1i ->newi ---> newfakethen -> ... -> finalthen
      *                  |---|----------------------------------|
      *                      |-> newfakelse -> <rest>
      *)
       let e1i = cfg_expr state F.Normal previ e1 in

       let names =
         match v_arrow_opt with
         | ForeachVar (var) -> [var]
         | ForeachArrow (var1, _, var2) ->
           [var1;var2]
         | ForeachList (_, xs) ->
           failwith "Warning: list foreach"
       in
       let node = F.ForeachHeader names in
       let newi = state.g#add_node { F.n = node; i=i() } in
       state.g +> add_arc_opt (e1i, newi);

       let newfakethen = state.g#add_node { F.n = F.TrueNode;i=None } in
       let newfakeelse = state.g#add_node { F.n = F.FalseNode;i=None } in
       state.g +> add_arc (newi, newfakethen);
       state.g +> add_arc (newi, newfakeelse);

       let state = { state with
         ctx = LoopCtx (newi, newfakeelse)::state.ctx;
       }
       in
       let finalthen =
         cfg_colon_stmt state (Some newfakethen) colon_stmt
       in
       state.g +> add_arc_opt (finalthen, newi);
       Some newfakeelse
*)

  (* This time, we may return None, for instance if return in body of dowhile
   * (whereas While can't return None). But if we return None, certainly
   * sign of buggy code.
   *)
   | Do (_, st, _, e, _) ->
     (* previ -> doi ---> ... ---> finalthen (opt) ---> taili
      *           |--------- newfakethen ----------------| |-> newfakelse <rest>
      *)
       let doi = state.g#add_node { F.n = F.DoHeader;i=i() } in
       state.g +> add_arc_opt (previ, doi);

       let taili = state.g#add_node
         { F.n = F.DoWhileTail (Ast.unparen e);i=None } in
       let newfakethen = state.g#add_node { F.n = F.TrueNode;i=None } in
       let newfakeelse = state.g#add_node { F.n = F.FalseNode;i=None } in
       state.g +> add_arc (taili, newfakethen);
       state.g +> add_arc (taili, newfakeelse);
       state.g +> add_arc (newfakethen, doi);

       let state = { state with
         ctx = LoopCtx (taili, newfakeelse)::state.ctx;
       }
       in
       let finalthen = cfg_stmt state (Some doi) st in
       (match finalthen with
       | None ->
           (* weird, probably wrong code *)
           None
       | Some finalthen ->
           state.g +> add_arc (finalthen, taili);
           Some newfakeelse
       )

   | IfColon (_t1, _e, tok, _st, _elseifs, _else, _t2, _t3)  ->
       raise (Error (ColonSyntax, tok))

   | If (_, e, st_then, st_elseifs, st_else_opt) ->
     (* previ -> newi --->  newfakethen -> ... -> finalthen --> lasti -> <rest>
      *                |                                     |
      *                |->  newfakeelse -> ... -> finalelse -|
      *
      * Can generate either special nodes for elseif, or just consider
      * elseif as syntactic sugar that translates into regular ifs, which
      * is what I do for now.
      * The lasti can be a Join when there is no return in either branch.
      *)
       let newi = state.g#add_node { F.n = F.IfHeader (Ast.unparen e);i=i() } in
       state.g +> add_arc_opt (previ, newi);

       let newfakethen = state.g#add_node { F.n = F.TrueNode;i=None } in
       let newfakeelse = state.g#add_node { F.n = F.FalseNode;i=None } in
       state.g +> add_arc (newi, newfakethen);
       state.g +> add_arc (newi, newfakeelse);

       let finalthen = cfg_stmt state (Some newfakethen) st_then in

       let finalelse =
         (match st_elseifs, st_else_opt with
         | [], None ->
             Some newfakeelse
         | [], Some (_, st_else) ->
             cfg_stmt state (Some newfakeelse) st_else
         | (t', e', st_then')::xs, else_opt ->
             (* syntactic unsugaring  *)
             cfg_stmt state (Some newfakeelse)
               (If (t', e', st_then', xs, else_opt))
         )
       in
       (match finalthen, finalelse with
       | None, None ->
           (* probably a return in both branches *)
           None
       | Some nodei, None
       | None, Some nodei ->
           Some nodei
       | Some n1, Some n2 ->
           let lasti = state.g#add_node { F.n = F.Join;i=None } in
           state.g +> add_arc (n1, lasti);
           state.g +> add_arc (n2, lasti);
           Some lasti
       )

   | Return (_, eopt, _) ->
       let newi = state.g#add_node { F.n = F.Return eopt;i=i() } in
       state.g +> add_arc_opt (previ, newi);
       state.g +> add_arc (newi, state.exiti);
       (* the next statement if there is one will not be linked to
        * this new node *)
       None

   | Continue (t1, e, _) | Break (t1, e, _) ->

       let is_continue, node =
         match stmt with
         | Continue _ -> true,  F.Continue
         | Break _    -> false, F.Break
         | _ -> raise Impossible
       in
       let depth =
         match e with
         | None -> 1
         | Some e ->
             (match intvalue_of_expr e with
             | Some i -> i
             | None ->
                 (* a dynamic variable ? *)
                 raise (Error (DynamicBreak, t1))
             )
       in

       let newi = state.g#add_node { F.n = node;i=i() } in
       state.g +> add_arc_opt (previ, newi);

       let nodei_to_jump_to =
         state.ctx +> lookup_some_ctx
           ~level:depth
           ~ctx_filter:(function
           | LoopCtx (headi, endi) ->
               if is_continue
               then Some (headi)
               else Some (endi)

           | SwitchCtx (endi) ->
               (* it's ugly but PHP allows to 'continue' inside 'switch' (even
                * when the switch is not inside a loop) in which case
                * it has the same semantic than 'break'.
                *)
               Some endi
           | TryCtx _ | NoCtx  -> None
           )
       in
       (match nodei_to_jump_to with
       | Some nodei ->
           state.g +> add_arc (newi, nodei);
       | None ->
           raise (Error (NoEnclosingLoop, t1))
       );
       None

   | Switch (_, e, cases) ->
       (match cases with
       | CaseList (_obrace, _colon_opt, cases, _cbrace) ->
           let newi = state.g#add_node
             { F.n = F.SwitchHeader (Ast.unparen e);i=i() } in
           state.g +> add_arc_opt (previ, newi);

           (* note that if all cases have return, then we will remove
            * this endswitch node later.
            *)
           let endi = state.g#add_node { F.n = F.SwitchEnd;i=None } in

           (* if no default: then must add path from start to end directly
            * todo? except if the cases cover the full spectrum ?
            *)
           if (not (cases +> List.exists
                       (function Ast.Default _ -> true | _ -> false)))
           then begin
             state.g +> add_arc (newi, endi);
           end;
           (* let's process all cases *)
           let last_stmt_opt =
             cfg_cases (newi, endi) state (None) cases
           in
           state.g +> add_arc_opt (last_stmt_opt, endi);

           (* remove endi if for instance all branches contained a return *)
           if (state.g#predecessors endi)#null then begin
             state.g#del_node endi;
             None
           end else
             Some endi

       | CaseColonList (tok, _, _, _, _) ->
           raise (Error (ColonSyntax, tok))
       )

   (*
    * Handling try part 1. See the case for Throw below and the
    * cfg_catches function for the second part.
    *
    * Any function call in the body of the try could potentially raise
    * an exception, so should we add edges to the catch nodes ?
    * In the same way any function call could potentially raise
    * a divide by zero or call exit().
    * For now we don't add all those edges. We do it only for explicit throw.
    *
    * todo? Maybe later the CFG could be extended with information
    * computed by a global bottom-up analysis (so that we would add certain
    * edges)
    *
    * todo? Maybe better to just add edges for all the nodes in the body
    * of the try to all the catches ?
    *
    * So for now, we mostly consider catches as a serie of elseifs,
    * and add some goto to be conservative at a few places. For instance
    *
    *   try {
    *     ...;
    *   } catch (E1 $x) {
    *     throw $x;
    *   } catch (E2 $x) {
    *     ...
    *   }
    *   ...
    *
    * is rougly considered as this code:
    *
    *   <tryheader> {
    *    if(true) goto catchstart;
    *    else {
    *      ...;
    *      goto tryend;
    *    }
    *   }
    *   <catchstart>
    *   if (is E1) {
    *     goto exit; /* or next handler if nested try */
    *   } elseif (is E2) {
    *     ...
    *     goto tryend;
    *   } else {
    *     goto exit; /* or next handler if nested try */
    *   }
    *
    *   <tryend>
    *)

   | Try(_, body, catches, _finallys) ->
       (* TODO Task #3622443: Update the logic below to account for "finally"
          clauses *)
       let newi = state.g#add_node { F.n = F.TryHeader;i=i() } in
       let catchi = state.g#add_node { F.n = F.CatchStart;i=None } in
       state.g +> add_arc_opt (previ, newi);

       (* may have to delete it later if nobody connected to it *)
       let endi = state.g#add_node { F.n = F.TryEnd;i=None } in

       (* for now we add a direct edge between the try and catch,
        * as even the first statement in the body of the try could
        * be a function raising internally an exception.
        *
        * I just don't want certain analysis like the deadcode-path
        * to report that the code in catch are never executed. I want
        * the catch nodes to have at least one parent. So I am
        * kind of conservative.
        *)
       state.g +> add_arc (newi, catchi);

       let state' = { state with
         ctx = TryCtx (catchi)::state.ctx;
       }
       in

       let stmts = stmts_of_stmt_or_defs (Ast.unbrace body) in
       let last_stmt_opt = cfg_stmt_list state' (Some newi) stmts in
       state.g +> add_arc_opt (last_stmt_opt, endi);

      (* note that we use state, not state' here, as we want the possible
       * throws inside catches to be themselves link to a possible surrounding
       * try.
       *)
       let last_false_node =
         cfg_catches state catchi endi (catches) in

       (* we want to connect the end of the catch list with
        * the next handler, if try are nested, or to the exit if
        * there is no more handler in this context
        *)
       let nodei_to_jump_to =
         state.ctx +> lookup_some_ctx ~ctx_filter:(function
         | TryCtx (nextcatchi) -> Some nextcatchi
         | LoopCtx _ | SwitchCtx _ | NoCtx -> None
         )
       in
       (match nodei_to_jump_to with
       | Some nextcatchi ->
           state.g +> add_arc (last_false_node, nextcatchi)
       | None ->
           state.g +> add_arc (last_false_node, state.exiti)
       );

       (* if nobody connected to endi erase the node. For instance
        * if have only return in the try body.
        *)
       if (state.g#predecessors endi)#null then begin
         state.g#del_node endi;
         None
       end
       else
        Some endi

   (*
    * For now we don't do any fancy analysis to statically detect
    * which exn handler a throw should go to. The argument of throw can
    * be static as in 'throw new ExnXXX' but it could also be dynamic. So for
    * now we just branch to the first catch and make edges between
    * the different catches in cfg_catches below
    * (which is probably what is done at runtime by the PHP interpreter).
    *
    * todo? Again maybe later the CFG could be sharpened with
    * path sensitive analysis to be more precise (so that we would remove
    * certain edges)
    *)
   | Throw (_, e, _) ->
       let newi = state.g#add_node { F.n = F.Throw e; i=i() } in
       state.g +> add_arc_opt (previ, newi);

       let nodei_to_jump_to =
         state.ctx +> lookup_some_ctx
           ~ctx_filter:(function
           | TryCtx (catchi) ->
               Some catchi
           | LoopCtx _ | SwitchCtx _ | NoCtx ->
               None
           )
       in
       (match nodei_to_jump_to with
       | Some catchi ->
           state.g +> add_arc (newi, catchi)
       | None ->
           (* no enclosing handler, branch to exit node of the function *)
           state.g +> add_arc (newi, state.exiti)
       );
       None

   | EmptyStmt _
   | Echo (_, _, _)
   | InlineHtml _

   | Declare (_, _, _)
   | Unset (_, _, _)
   | Use (_, _, _)
   | Globals (_, _, _)
       ->
       let simple_stmt = F.TodoSimpleStmt in
       let newi = state.g#add_node { F.n = F.SimpleStmt simple_stmt;i=i() } in
       state.g +> add_arc_opt (previ, newi);
       Some newi

   (* should be filtered *)
   | FuncDefNested _ | ClassDefNested _ ->
       raise Impossible


and cfg_stmt_list state previ xs =
  xs +> List.fold_left (fun previ stmt ->
    cfg_stmt state previ stmt
  ) previ

and cfg_colon_stmt state previ colon =
  let stmts = stmts_of_colon_stmt colon in
  cfg_stmt_list state previ stmts

(*
 * Creating the CFG nodes and edges for the cases of a switch.
 *
 * PHP allows to write code like  case X: case Y: ... This is
 * parsed as a [Case (X, []); Case (Y, ...)] which means
 * the statement list of the X case is empty. In this situation we just
 * want to link the node for X directly to the node for Y.
 *
 * So cfg_cases works like cfg_stmt by optionally taking the index of
 * the previous node (here for instance the node of X), and optionally
 * returning a node (if the case contains a break, then this will be
 * None)
 *)
and (cfg_cases:
    (nodei * nodei) -> state ->
    nodei option -> Cst_php.case list -> nodei option) =
 fun (switchi, endswitchi) state previ cases ->

   let state = { state with
     ctx = SwitchCtx (endswitchi)::state.ctx;
   }
   in

   cases +> List.fold_left (fun previ case ->
     let node, stmt_or_defs =
       match case with
       | Case (_, _e, _, stmt_or_defs) ->
           F.Case, stmt_or_defs
       | Default (_, _, stmt_or_defs) ->
           F.Default, stmt_or_defs
     in

     let i () = Some (List.hd (Lib_parsing_php.ii_of_any (Case2 case))) in

     let newi = state.g#add_node { F.n = node; i=i() } in
     state.g +> add_arc_opt (previ, newi);
     (* connect SwitchHeader to Case node *)
     state.g +> add_arc (switchi, newi);

     let stmts = stmts_of_stmt_or_defs stmt_or_defs in
     (* the stmts can contain 'break' that will be linked to the endswitch *)
     cfg_stmt_list state (Some newi) stmts
   ) previ

(*
 * Creating the CFG nodes and edges for the catches of a try.
 *
 * We will conside catch(Exn $e) as a kind of if, with a TrueNode for
 * the case the thrown exn matched the specified class,
 * and FalseNode otherwise.
 *
 * cfg_catches takes the nodei of the previous catch nodes (or false node
 * of the previous catch node), process the catch body, and return
 * a new False Node.
 *)

and (cfg_catches: state -> nodei -> nodei -> Cst_php.catch list -> nodei) =
 fun state previ tryendi catches ->
   catches +> List.fold_left (fun previ catch ->
     let (t, e_paren, stmt_or_defs) = catch in
     let (_, name) = Ast.unparen e_paren in
     let newi = state.g#add_node { F.n = F.Catch; i=Some t } in
     state.g +> add_arc (previ, newi);
     let ei = cfg_var_def state (Some newi) name in
     let truei = state.g#add_node { F.n = F.TrueNode;i=None } in
     let falsei = state.g#add_node { F.n = F.FalseNode;i=None } in
     state.g +> add_arc_opt (ei, truei);
     state.g +> add_arc_opt (ei, falsei);

     let stmts = stmts_of_stmt_or_defs (Ast.unbrace stmt_or_defs) in
     (* the stmts can contain 'throw' that will be linked to an upper try or
      * exit node *)
     let last_stmt_opt = cfg_stmt_list state (Some truei) stmts in
     state.g +> add_arc_opt (last_stmt_opt, tryendi);

     (* we chain the catches together, like elseifs *)
     falsei
   ) previ

and cfg_expr state kind previ expr =
  let i = Some (List.hd (Lib_parsing_php.ii_of_any (Expr expr))) in
  let newi = state.g#add_node { 
    F.n = F.SimpleStmt (F.ExprStmt (expr, kind)); 
    i=i 
  } in
  state.g +> add_arc_opt (previ, newi);
  Some newi

and cfg_var_def state previ dname =
  let i = Ast.info_of_dname dname in
  let vari = state.g#add_node { F.n = F.Parameter dname; i=Some i } in
  state.g +> add_arc_opt (previ, vari);
  Some vari

(*e: controlflow_php main algorithm *)

(*****************************************************************************)
(* Main entry point *)
(*****************************************************************************)

(*s: controlflow builders *)
let (control_flow_graph_of_stmts: dname list -> stmt list -> F.flow) =
  fun params xs ->
  (* yes, I sometimes use objects, and even mutable objects in OCaml ... *)
  let g = new Ograph_extended.ograph_mutable in

  let enteri = g#add_node { F.n = F.Enter;i=None } in
  let exiti  = g#add_node { F.n = F.Exit; i=None } in
  let newi = params +> List.fold_left (fun previ param ->
    let parami = g#add_node { F.n = F.Parameter param; i=None } in
    g +> add_arc (previ, parami);
    parami
    ) enteri 
  in
  let state = {
    g = g;
    exiti = exiti;
    ctx = [NoCtx]; (* could also remove NoCtx and use an empty list *)
  }
  in
  let last_node_opt =
    cfg_stmt_list state (Some newi) xs
  in
  (* maybe the body does not contain a single 'return', so by default
   * connect last stmt to the exit node
   *)
  g +> add_arc_opt (last_node_opt, exiti);
  g

(*x: controlflow builders *)
let (cfg_of_func: func_def -> F.flow) = fun def ->
  let stmts = stmts_of_stmt_or_defs (Ast.unbrace def.f_body) in
  let params = 
    def.f_params +> Ast.unparen +> Ast.uncomma_dots 
    +> List.map (fun p -> p.p_name)
  in
  (* less: could create a node with function name ? *)
  control_flow_graph_of_stmts params stmts

(*x: controlflow builders *)
(* alias *)
let cfg_of_stmts = control_flow_graph_of_stmts
(*e: controlflow builders *)

(*****************************************************************************)
(* Deadcode stmts detection. See also deadcode_php.ml *)
(*****************************************************************************)

(*s: function deadcode_detection *)
let (deadcode_detection : F.flow -> unit) = fun flow ->
  flow#nodes#iter (fun (k, node) ->
    let pred = flow#predecessors k in
    if pred#null then
      (match node.F.n with
      | F.Enter -> ()
      | _ ->
          let info = node.F.i in
          (match info with
          | None ->
              pr2 "CFG: PB, found dead node but cant trace to location";
          | Some info ->
              raise (Error (DeadCode node.F.n, info))
          )
      )
  )
(*e: function deadcode_detection *)

(*****************************************************************************)
(* Error management *)
(*****************************************************************************)

let string_of_error_kind error_kind =
  match error_kind with
  | ColonSyntax ->
      "Dude, don't use the old PHP colon syntax: "
  | DeadCode (node_kind) ->
      "Deadcode path detected " ^
        (F.short_string_of_node_kind node_kind)
  | NoEnclosingLoop ->
      "No enclosing loop found for break or continue"
  | DynamicBreak ->
      "Dynamic break/continue are not supported"

(* note that the output is emacs compile-mode compliant *)
let string_of_error (error_kind, info) =
  let info = Parse_info.token_location_of_info info in
  spf "%s:%d:%d: FLOW %s"
    info.Parse_info.file info.Parse_info.line info.Parse_info.column
    (string_of_error_kind error_kind)
 (* old:
  let error_from_info info =
    let pinfo = Ast.parse_info_of_info info in
    Parse_info.error_message_short
      pinfo.Parse_info.file ("", pinfo.Parse_info.charpos)
  in
 *)

(*s: function Controlflow_build_php.report_error *)
let (report_error : error -> unit) = fun err ->
  pr2 (string_of_error err)
(*e: function Controlflow_build_php.report_error *)

(*e: controlflow_build_php.ml *)
