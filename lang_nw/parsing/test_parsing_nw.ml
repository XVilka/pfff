open Common

module Flag = Flag_parsing

(*****************************************************************************)
(* Subsystem testing *)
(*****************************************************************************)

let test_tokens_nw file = 
  if not (file =~ ".*\\.nw") 
  then pr2 "warning: seems not a noweb file";

  Flag.verbose_lexing := true;
  Flag.verbose_parsing := true;

  let toks = Parse_nw.tokens file in
  toks +> List.iter (fun x -> pr2_gen x);
  ()

let test_parse_nw file =
  Parse_nw.parse file |> ignore

let test_dump_nw file =
  let ((trees, _toks), _stat) = Parse_nw.parse file in
  let v = Ast_fuzzy.vof_trees trees in
  let s = Ocaml.string_of_v v in
  pr2 s

(*****************************************************************************)
(* Unit tests *)
(*****************************************************************************)

(*****************************************************************************)
(* Main entry for Arg *)
(*****************************************************************************)

let actions () = [
  "-tokens_nw", "   <file>", 
  Common.mk_action_1_arg test_tokens_nw;
  "-parse_nw", "   <file>", 
  Common.mk_action_1_arg test_parse_nw;
  "-dump_nw", "   <file>", 
  Common.mk_action_1_arg test_dump_nw;
]
