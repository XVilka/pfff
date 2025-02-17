(* Yoann Padioleau
 *
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

module V = Visitor_ast_generic
module M = Map_ast_generic

(*****************************************************************************)
(* Extract infos *)
(*****************************************************************************)

let extract_info_visitor recursor = 
  let globals = ref [] in
  let hooks = { V.default_visitor with
    V.kinfo = (fun (_k, _) i -> Common.push i globals)
  } in
  begin
    let vout = V.mk_visitor hooks in
    recursor vout;
    List.rev !globals
  end

let ii_of_any any = 
  extract_info_visitor (fun visitor -> visitor any)


(*****************************************************************************)
(* Abstract position *)
(*****************************************************************************)
let abstract_position_visitor recursor = 
  let hooks = { (* M.default_visitor with *)
    M.kinfo = (fun (_k, _) i -> 
      { i with Parse_info.token = Parse_info.Ab }
    )
  } in
  begin
    let vout = M.mk_visitor hooks in
    recursor vout;
  end
let abstract_position_info_any x = 
  abstract_position_visitor (fun visitor -> visitor.M.vany x)
