(* Yoann Padioleau
 *
 * Copyright (C) 2010, 2013 Facebook
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
open Common 

module Flag = Flag_parsing
module Flag_js = Flag_parsing_js
module Ast = Cst_js
module TH   = Token_helpers_js
module PI = Parse_info

(*****************************************************************************)
(* Prelude *)
(*****************************************************************************)
(* Lots of copy paste with my other parsers (e.g. PHP, C, ML) but
 * copy paste is sometimes ok.
 *)

(*****************************************************************************)
(* Types *)
(*****************************************************************************)

(* the token list contains also the comment-tokens *)
type program_and_tokens = 
  Cst_js.program option * Parser_js.token list

(*****************************************************************************)
(* Error diagnostic  *)
(*****************************************************************************)
let error_msg_tok tok = 
  Parse_info.error_message_info (TH.info_of_tok tok)

(*****************************************************************************)
(* Helpers  *)
(*****************************************************************************)

(* Now that we parse individual items separately, and that we do not
 * rely on EOF as a final marker, we need to take care when
 * running the parser on the next item. Indeed, certain
 * items such as if and try have optional trailing element
 * (an else branch, a finally stmt) that forces the parser to
 * lookahead and consume an extra token in lexer_function to
 * decide to reduce or not the current item.
 * Before running the parser on the next item we need to put
 * back this consumed token back in the stream!
 * 
 * alt:
 *  - use ii_of_any and check if tr.current is in it
 *    WARNING!: this requires that the last token of what is
 *    parsed is in the CST! otherwise this will reintroduce in
 *    the stream an extra token so take care!
 *  - match for If without else and Try without Finally in AST
 *    (only cases?)
 *  - less: ask on caml list if can access parser state?
 *    but Parsing.parser_env is abstract and no much API around it.
 *
 * see also top comment in tests/js/items.js
 *)
let put_back_lookahead_token_if_needed tr item_opt =
  match item_opt with
  | None -> ()
  | Some item ->
     let iis = Lib_parsing_js.ii_of_any (Ast.Program [item]) in
     let current = tr.PI.current in
     let info = TH.info_of_tok current in
     (* bugfix: without test on is_origintok, the parser timeout
      * TODO: why?
      *)
     if not (PI.is_origintok info) || List.mem info iis
     then ()
     else begin
       if !Flag.debug_lexer
       then pr2 (spf "putting back %s" (Common.dump current));
       tr.PI.rest <- current::tr.PI.rest;
       tr.PI.passed <- List.tl tr.PI.passed;
     end

(*****************************************************************************)
(* ASI (Automatic Semicolon Insertion) part 2 *)
(*****************************************************************************)

(* To get the right to do an ASI, the parse error needs to be
 * on a new line. In some cases though the current offending token might
 * not be the first token on the line. Indeed in
 *   if(true) continue
 *   x = y;
 * the parser does not generate a parse error at 'x' but at '=' because
 * 'continue' can accept an identifier. 
 * In fact, the situation is worse, because for
 *   if(true) continue
 *   x;
 * we must generate two independent statements, even though it does
 * look like a parse error. To handle those cases we
 * need a parsing_hack phase that inserts semicolon after the
 * continue if there is a newline after.
 *)

let rec line_previous_tok xs =
  match xs with
  | [] -> None
  | x::xs ->
    if TH.is_comment x
    then line_previous_tok xs
    else Some (TH.line_of_tok x)

let asi_opportunity charpos last_charpos_error cur tr = 
  match tr.PI.passed with
  | _ when charpos <= !last_charpos_error -> None
  | [] -> None
  (* see tests/js/parsing/asi_incr_bis.js *)
  | offending::((Parser_js.T_INCR _|Parser_js.T_DECR _) as real_offender)::xs ->
    (match line_previous_tok xs, offending with
    | Some line, _ when TH.line_of_tok real_offender > line ->
       Some ([offending], real_offender, xs)
    | _, (Parser_js.T_RCURLY _ | Parser_js.EOF _) -> 
         Some ([], offending, (real_offender::xs))
    | _ -> None
    )
  | offending::xs -> 
     (match line_previous_tok xs, cur with
     | Some line, _ when TH.line_of_tok cur > line -> Some ([], offending, xs)
     | _, (Parser_js.T_RCURLY _ | Parser_js.EOF _) -> Some ([], offending, xs)
     | _ -> None
     )
  

let asi_insert charpos last_charpos_error tr 
  (passed_before, passed_offending, passed_after) =

    let info = TH.info_of_tok passed_offending in
    let virtual_semi = 
      Parser_js.T_VIRTUAL_SEMICOLON (Ast.fakeInfoAttach info) in
    if !Flag_js.debug_asi
    then pr2 (spf "insertion fake ';' at %s" (PI.string_of_info info));
  
    let toks = List.rev passed_after @
               [virtual_semi; passed_offending] @ 
               passed_before @
               tr.PI.rest 
    in
    (* like in Parse_info.mk_tokens_state *)
    tr.PI.rest <- toks;
    tr.PI.current <- List.hd toks;
    tr.PI.passed <- [];
    (* try again! 
     * This significantly slow-down parsing, especially on minimized
     * files. Indeed, minimizers put all the code inside a giant
     * function, which means no incremental parsing, and leverage ASI
     * before right curly brace to save one character (hmmm). This means
     * that we parse again and again the same series of tokens, just
     * progressing a bit more everytime, and restarting from scratch.
     * This is quadratic behavior.
     *)
    last_charpos_error := charpos


(*****************************************************************************)
(* Lexing only *)
(*****************************************************************************)

let tokens2 file = 
  let table     = Parse_info.full_charpos_to_pos_large file in

  Common.with_open_infile file (fun chan -> 
    let lexbuf = Lexing.from_channel chan in

    Lexer_js.reset();

      let jstoken lexbuf = 
        match Lexer_js.current_mode() with
        | Lexer_js.ST_IN_CODE ->
            Lexer_js.initial lexbuf
        | Lexer_js.ST_IN_XHP_TAG current_tag ->
            Lexer_js.st_in_xhp_tag current_tag lexbuf
        | Lexer_js.ST_IN_XHP_TEXT current_tag ->
            Lexer_js.st_in_xhp_text current_tag lexbuf
        | Lexer_js.ST_IN_BACKQUOTE ->
            Lexer_js.backquote lexbuf
      in
      let rec tokens_aux acc = 
        let tok = jstoken lexbuf in
        if !Flag.debug_lexer 
        then Common.pr2_gen tok;

        if not (TH.is_comment tok)
        then Lexer_js._last_non_whitespace_like_token := Some tok;

        let tok = tok +> TH.visitor_info_of_tok (fun ii -> 
        { ii with PI.token =
          (* could assert pinfo.filename = file ? *)
            match ii.PI.token with
            | PI.OriginTok pi ->
              PI.OriginTok (PI.complete_token_location_large file table pi)
            | PI.FakeTokStr _ | PI.Ab  | PI.ExpandedTok _ ->
              raise Impossible
        })
        in

        if TH.is_eof tok
        then List.rev (tok::acc)
        else tokens_aux (tok::acc)
    in
    tokens_aux []
 )

let tokens a = 
  Common.profile_code "Parse_js.tokens" (fun () -> tokens2 a)

(*****************************************************************************)
(* Helper for main entry point *)
(*****************************************************************************)

(* Hacked lex. This function use refs passed by parse.
 * 'tr' means 'token refs'.
 *)
let rec lexer_function tr = fun lexbuf ->
  match tr.PI.rest with
  | [] -> (pr2 "LEXER: ALREADY AT END"; tr.PI.current)
  | v::xs -> 
      tr.PI.rest <- xs;
      tr.PI.current <- v;
      tr.PI.passed <- v::tr.PI.passed;

      if TH.is_comment v (* || other condition to pass tokens ? *)
      then lexer_function (*~pass*) tr lexbuf
      else v

(*****************************************************************************)
(* Main entry point *)
(*****************************************************************************)

exception Parse_error of Parse_info.info

let parse2 filename =
  let stat = PI.default_stat filename in

  let toks = tokens filename in
  let toks = Parsing_hacks_js.fix_tokens toks in
  let toks = Parsing_hacks_js.fix_tokens_ASI toks in

  let tr = PI.mk_tokens_state toks in
  let last_charpos_error = ref 0 in
  let lexbuf_fake = Lexing.from_function (fun _buf _n -> raise Impossible) in

   Sys.set_signal Sys.sigalrm (Sys.Signal_handle (fun _ -> raise Timeout ));
   (* todo: minimized files abusing ASI before '}' requires a very long time
    * to parse 
    *)
   ignore(Unix.alarm 5);

  let rec parse_module_item_or_eof tr =
    try 
     let item = 
       (* -------------------------------------------------- *)
       (* Call parser *)
       (* -------------------------------------------------- *)
       Common.profile_code "Parser_js.module_item" (fun () ->
         Parser_js.module_item_or_eof (lexer_function tr) lexbuf_fake
       )
     in
     (* this seems optional *)
     Parsing.clear_parser ();
     put_back_lookahead_token_if_needed tr item;
     Left item
   with 
   | Lexer_js.Lexical_error (s, _) ->
      let cur = tr.PI.current in
      if !Flag.show_parsing_error
      then pr2 ("lexical error " ^s^ "\n =" ^ error_msg_tok cur);
      Right cur

   | Parsing.Parse_error ->
      let cur = tr.PI.current in
      let info = TH.info_of_tok cur in
      let charpos = Parse_info.pos_of_info info in

      (* try Automatic Semicolon Insertion *)
      (match asi_opportunity charpos last_charpos_error cur tr with
      | None -> 
         if !Flag.show_parsing_error 
         then pr2 ("parse error \n = " ^ error_msg_tok cur);
         Right cur
      | Some (passed_before, passed_offending, passed_after) ->
          asi_insert charpos last_charpos_error tr
             (passed_before, passed_offending, passed_after);
          parse_module_item_or_eof tr
      )
  in
  let rec aux tr =
    let line_start = TH.line_of_tok tr.PI.current in
    let res = parse_module_item_or_eof tr in
    let passed = tr.PI.passed in
    tr.PI.passed <- [];
    let lines =
      try 
        let (head, _middle, last) = Common2.head_middle_tail passed in
        let line1 = TH.line_of_tok last in
        let line2 = TH.line_of_tok head in
        line2 - line1 (* +1? *)
      with _ -> 1
    in
    match res with
    (* EOF *)
    | Left None -> 
        stat.PI.correct <- stat.PI.correct + lines;
        []
    | Left (Some x) -> 
        stat.PI.correct <- stat.PI.correct + lines;
        if !Flag_js.debug_asi
        then pr2 (spf "parsed: %s"
                (Ast.Program [x] |> Meta_cst_js.vof_any |> Ocaml.string_of_v));

        x::aux tr 
    | Right err_tok ->
       let max_line = Common.cat filename +> List.length in
       if !Flag.show_parsing_error
       then begin
         let filelines = Common2.cat_array filename in
         let cur = tr.PI.current in
         let line_error = TH.line_of_tok cur in
         PI.print_bad line_error (line_start, min max_line (line_error + 10))
              filelines;
       end;
       if !Flag.error_recovery
       then begin
        (* todo? try to recover? call 'aux tr'? but then can be really slow *)
        stat.PI.bad <- stat.PI.bad + (max_line - line_start);
        []
       end 
       else raise (Parse_error (TH.info_of_tok err_tok))
  in
  let items = 
   try 
     aux tr 
   with Timeout ->
      ignore(Unix.alarm 0);
      if !Flag.show_parsing_error
      then pr2 (spf "TIMEOUT on %s" filename);
      stat.PI.bad <- Common.cat filename |> List.length;
      stat.PI.have_timeout <- true;
      stat.PI.correct <- 0;
      []
  in
  ignore(Unix.alarm 0);
  (* the correct count is accurate because items do not fall always
   * on clean line boundaries so we may count multiple times the same line
   *)
  if stat.PI.bad = 0
  then stat.PI.correct <- Common.cat filename |> List.length;

  (Some items, toks), stat

let parse a = 
  Common.profile_code "Parse_js.parse" (fun () -> parse2 a)

let parse_program file = 
  let ((astopt, _toks), _stat) = parse file in
  Common2.some astopt


let parse_string (w : string) : Ast.program =
  Common2.with_tmp_file ~str:w ~ext:"js" parse_program

(*****************************************************************************)
(* Sub parsers *)
(*****************************************************************************)

let (program_of_string: string -> Cst_js.program) = fun s -> 
  Common2.with_tmp_file ~str:s ~ext:"js" (fun file ->
    parse_program file
  )

(* for sgrep/spatch *)
let any_of_string s = 
  Common2.with_tmp_file ~str:s ~ext:"js" (fun file ->
    let toks = tokens file in
    let tr = PI.mk_tokens_state toks in
    let lexbuf_fake = Lexing.from_function (fun _buf _n -> raise Impossible) in
       (* -------------------------------------------------- *)
       (* Call parser *)
       (* -------------------------------------------------- *)
       Parser_js.sgrep_spatch_pattern (lexer_function tr) lexbuf_fake
  )


(*****************************************************************************)
(* Fuzzy parsing *)
(*****************************************************************************)

let parse_fuzzy file =
  let toks = tokens file in
  let trees = Parse_fuzzy.mk_trees { Parse_fuzzy.
     tokf = TH.info_of_tok;
     kind = TH.token_kind_of_tok;
  } toks 
  in
  trees, toks
