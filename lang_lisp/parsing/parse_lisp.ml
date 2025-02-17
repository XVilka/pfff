(* Yoann Padioleau
 * 
 * Copyright (C) 2010 Facebook
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License (GPL)
 * version 2 as published by the Free Software Foundation.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * file license.txt for more details.
 *)

open Common 

open Parser_lisp
open Ast_lisp
module Flag = Flag_parsing
module PI = Parse_info
(* we don't need a full grammar for lisp code, so we put everything,
 * the token type, the helper in parser_ml. No token_helpers_lisp.ml
 *)
module TH = Parser_lisp

(*****************************************************************************)
(* Prelude *)
(*****************************************************************************)
(* 
 * alt: 
 *  - Could reuse the parser in ocamlsexp ? but they just have Atom | Sexp
 *    and I need to differentiate numbers in the highlighter, and
 *    also handling quoted, anti-quoted and other lisp special things.
 *)

(*****************************************************************************)
(* Types *)
(*****************************************************************************)

(* the token list contains also the comment-tokens *)
type program_and_tokens = 
  Ast_lisp.program option * Parser_lisp.token list

exception Parse_error of string * Parse_info.info

(*****************************************************************************)
(* Lexing only *)
(*****************************************************************************)

(* could factorize and take the tokenf and visitor_of_infof in argument
 * but sometimes copy-paste is ok.
 *)
let tokens2 file = 
  let table     = Parse_info.full_charpos_to_pos_large file in

  Common.with_open_infile file (fun chan -> 
    let lexbuf = Lexing.from_channel chan in

    try 
      let ftoken lexbuf = 
        Lexer_lisp.token lexbuf
      in
      
      let rec tokens_aux acc = 
        let tok = ftoken lexbuf in
        if !Flag.debug_lexer then Common.pr2_gen tok;

        let tok = tok +> TH.visitor_info_of_tok (fun ii -> 
        { ii with PI.token=
          (* could assert pinfo.filename = file ? *)
           match ii.PI.token with
           | PI.OriginTok pi ->
               PI.OriginTok 
                 (PI.complete_token_location_large file table pi)
           | _ -> raise Todo
        })
        in
        
        if TH.is_eof tok
        then List.rev (tok::acc)
        else tokens_aux (tok::acc)
      in
      tokens_aux []
  with
  | Lexer_lisp.Lexical s -> 
      failwith ("lexical error " ^ s ^ "\n =" ^ 
                 (PI.error_message file (PI.lexbuf_to_strpos lexbuf)))
  | e -> raise e
 )

let tokens a = 
  Common.profile_code "Parse_lisp.tokens" (fun () -> tokens2 a)

(*****************************************************************************)
(* Parser *)
(*****************************************************************************)

(* simple recursive descent parser *)
let rec sexps toks =
  match toks with
  | [] -> [], []
  | [EOF _] -> [], []
  | (TCParen _ | TCBracket _)::_ -> [], toks
  | xs ->
    let s, rest = sexp xs in
    let xs, rest = sexps rest in
    s::xs, rest

and sexp toks =
  match toks with
  | [] -> raise Todo
  | x::xs ->
    (match x with
    | TComment _ | TCommentSpace _ | TCommentNewline _ -> raise Impossible

    | TNumber x -> Atom (Number x), xs
    | TString x -> Atom (String x), xs
    | TIdent x -> Atom (Id x), xs

    | TOParen t1 -> 
      let (xs, rest) = sexps xs in
      (match rest with
      | TCParen t2::rest ->
          Sexp ((t1, xs, t2)), rest
      | _ -> raise (Parse_error ("unclosed parenthesis", t1))
      )

    | TOBracket t1 -> 
      let (xs, rest) = sexps xs in
      (match rest with
      | TCBracket t2::rest ->
          Sexp ((t1, xs, t2)), rest
      | _ -> raise (Parse_error ("unclosed bracket", t1))
      )

    | TCParen t | TCBracket t ->
      raise (Parse_error ("closing bracket/paren without opening one", t))

    | TQuote t ->
      let (s, rest) = sexp xs in
      Special ((Quote, t), s), rest
    | TBackQuote t ->
      let (s, rest) = sexp xs in
      Special ((BackQuote, t), s), rest
    | TAt t ->
      let (s, rest) = sexp xs in
      Special ((At, t), s), rest
    | TComma t ->
      let (s, rest) = sexp xs in
      Special ((Comma, t), s), rest

    (* hmmm probably unicode *)
    | TUnknown t ->
      Atom (String (PI.str_of_info t, t)), xs

    | EOF t ->
      raise (Parse_error ("unexpected eof", t))
    )
      

(*****************************************************************************)
(* Main entry point *)
(*****************************************************************************)

let parse2 filename =

  let stat = Parse_info.default_stat filename in
  let toks_orig = tokens filename in

  let toks = toks_orig +> Common.exclude TH.is_comment in
  let nblines = Common2.nblines filename in

  let ast = 
    try
      (match sexps toks with
      | xs, [] ->
        stat.PI.correct <- nblines;
        Some xs
      | _, x::_xs ->
        raise (Parse_error ("trailing constructs", (TH.info_of_tok x)))
      )
    with
    | Parse_error (s, info) ->
      pr2 (spf "Parse error: %s, {%s} at %s" 
             s 
             (PI.str_of_info info)
             (PI.string_of_info info));
      stat.PI.bad <- nblines;
      None
    | exn -> 
      raise exn
  in
  (ast, toks_orig), stat

let parse a = 
  Common.profile_code "Parse_lisp.parse" (fun () -> parse2 a)

let parse_program file =
  let (ast, _toks), _stat =  parse file in
  Common2.some ast
