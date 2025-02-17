
type precision = {
  full_info: bool;
  token_info: bool;
  type_info: bool;
}
let default_precision = {
  full_info = false;
  token_info = false;
  type_info = false;
}

(* generated by ocamltarzan with: camlp4o -o /tmp/yyy.ml -I pa/ pa_type_conv.cmo pa_vof.cmo  pr_o.cmo /tmp/xxx.ml  *)

open Ast_generic

let vof_tok v = Parse_info.vof_info v
  
let vof_wrap _of_a (v1, v2) =
  let v1 = _of_a v1 and v2 = vof_tok v2 in Ocaml.VTuple [ v1; v2 ]
  
let vof_name v = vof_wrap Ocaml.vof_string v
  
let vof_dotted_name v = Ocaml.vof_list vof_name v
  
let vof_qualified_name v = vof_dotted_name v
  
let vof_module_name =
  function
  | FileName v1 ->
      let v1 = vof_wrap Ocaml.vof_string v1
      in Ocaml.VSum (("FileName", [ v1 ]))
  | DottedName v1 ->
      let v1 = vof_dotted_name v1 in Ocaml.VSum (("DottedName", [ v1 ]))
  
let vof_resolved_name =
  function
  | Local -> Ocaml.VSum (("Local", []))
  | Param -> Ocaml.VSum (("Param", []))
  | Global v1 ->
      let v1 = vof_qualified_name v1 in Ocaml.VSum (("Global", [ v1 ]))
  | NotResolved -> Ocaml.VSum (("NotResolved", []))
  | Macro -> Ocaml.VSum (("Macro", []))
  | EnumConstant -> Ocaml.VSum (("EnumConstant", []))
  | ImportedModule -> Ocaml.VSum (("ImportedModule", []))
  
let rec vof_expr =
  function
  | L v1 -> let v1 = vof_literal v1 in Ocaml.VSum (("L", [ v1 ]))
  | Container ((v1, v2)) ->
      let v1 = vof_container_operator v1
      and v2 = Ocaml.vof_list vof_expr v2
      in Ocaml.VSum (("Container", [ v1; v2 ]))
  | Tuple v1 ->
      let v1 = Ocaml.vof_list vof_expr v1 in Ocaml.VSum (("Tuple", [ v1 ]))
  | Record v1 ->
      let v1 = Ocaml.vof_list vof_field v1 in Ocaml.VSum (("Record", [ v1 ]))
  | Constructor ((v1, v2)) ->
      let v1 = vof_name v1
      and v2 = Ocaml.vof_list vof_expr v2
      in Ocaml.VSum (("Constructor", [ v1; v2 ]))
  | Lambda v1 ->
      let v1 = vof_function_definition v1
      in Ocaml.VSum (("Lambda", [ v1 ]))
  | Nop -> Ocaml.VSum (("Nop", []))
  | Id ((v1, v2)) ->
      let v1 = vof_name v1
      and v2 = vof_id_info v2
      in Ocaml.VSum (("Id", [ v1; v2 ]))
  | IdSpecial v1 ->
      let v1 = vof_special v1 in Ocaml.VSum (("IdSpecial", [ v1 ]))
  | Call ((v1, v2)) ->
      let v1 = vof_expr v1
      and v2 = vof_arguments v2
      in Ocaml.VSum (("Call", [ v1; v2 ]))
  | Assign ((v1, v2)) ->
      let v1 = vof_expr v1
      and v2 = vof_expr v2
      in Ocaml.VSum (("Assign", [ v1; v2 ]))
  | AssignOp ((v1, v2, v3)) ->
      let v1 = vof_expr v1
      and v2 = vof_arithmetic_operator v2
      and v3 = vof_expr v3
      in Ocaml.VSum (("AssignOp", [ v1; v2; v3 ]))
  | LetPattern ((v1, v2)) ->
      let v1 = vof_pattern v1
      and v2 = vof_expr v2
      in Ocaml.VSum (("LetPattern", [ v1; v2 ]))
  | ObjAccess ((v1, v2)) ->
      let v1 = vof_expr v1
      and v2 = vof_name v2
      in Ocaml.VSum (("ObjAccess", [ v1; v2 ]))
  | ArrayAccess ((v1, v2)) ->
      let v1 = vof_expr v1
      and v2 = vof_expr v2
      in Ocaml.VSum (("ArrayAccess", [ v1; v2 ]))
  | Conditional ((v1, v2, v3)) ->
      let v1 = vof_expr v1
      and v2 = vof_expr v2
      and v3 = vof_expr v3
      in Ocaml.VSum (("Conditional", [ v1; v2; v3 ]))
  | MatchPattern ((v1, v2)) ->
      let v1 = vof_expr v1
      and v2 = Ocaml.vof_list vof_action v2
      in Ocaml.VSum (("MatchPattern", [ v1; v2 ]))
  | Yield v1 -> let v1 = vof_expr v1 in Ocaml.VSum (("Yield", [ v1 ]))
  | Await v1 -> let v1 = vof_expr v1 in Ocaml.VSum (("Await", [ v1 ]))
  | Cast ((v1, v2)) ->
      let v1 = vof_type_ v1
      and v2 = vof_expr v2
      in Ocaml.VSum (("Cast", [ v1; v2 ]))
  | Seq v1 ->
      let v1 = Ocaml.vof_list vof_expr v1 in Ocaml.VSum (("Seq", [ v1 ]))
  | Ref v1 -> let v1 = vof_expr v1 in Ocaml.VSum (("Ref", [ v1 ]))
  | DeRef v1 -> let v1 = vof_expr v1 in Ocaml.VSum (("DeRef", [ v1 ]))
  | Ellipses v1 -> let v1 = vof_tok v1 in Ocaml.VSum (("Ellipses", [ v1 ]))
  | OtherExpr ((v1, v2)) ->
      let v1 = vof_other_expr_operator v1
      and v2 = Ocaml.vof_list vof_any v2
      in Ocaml.VSum (("OtherExpr", [ v1; v2 ]))
and vof_literal =
  function
  | Unit v1 -> let v1 = vof_tok v1 in Ocaml.VSum (("Unit", [ v1 ]))
  | Bool v1 ->
      let v1 = vof_wrap Ocaml.vof_bool v1 in Ocaml.VSum (("Bool", [ v1 ]))
  | Int v1 ->
      let v1 = vof_wrap Ocaml.vof_string v1 in Ocaml.VSum (("Int", [ v1 ]))
  | Float v1 ->
      let v1 = vof_wrap Ocaml.vof_string v1 in Ocaml.VSum (("Float", [ v1 ]))
  | Char v1 ->
      let v1 = vof_wrap Ocaml.vof_string v1 in Ocaml.VSum (("Char", [ v1 ]))
  | String v1 ->
      let v1 = vof_wrap Ocaml.vof_string v1
      in Ocaml.VSum (("String", [ v1 ]))
  | Regexp v1 ->
      let v1 = vof_wrap Ocaml.vof_string v1
      in Ocaml.VSum (("Regexp", [ v1 ]))
  | Null v1 -> let v1 = vof_tok v1 in Ocaml.VSum (("Null", [ v1 ]))
  | Undefined v1 -> let v1 = vof_tok v1 in Ocaml.VSum (("Undefined", [ v1 ]))
and vof_container_operator =
  function
  | Array -> Ocaml.VSum (("Array", []))
  | List -> Ocaml.VSum (("List", []))
  | Set -> Ocaml.VSum (("Set", []))
  | Dict -> Ocaml.VSum (("Dict", []))
and
  vof_id_info {
                id_qualifier = v_id_qualifier;
                id_typeargs = v_id_typeargs;
                id_resolved = v_id_resolved;
                id_type = v_id_type
              } =
  let bnds = [] in
  let arg = Ocaml.vof_ref (Ocaml.vof_option vof_type_) v_id_type in
  let bnd = ("id_type", arg) in
  let bnds = bnd :: bnds in
  let arg = Ocaml.vof_ref vof_resolved_name v_id_resolved in
  let bnd = ("id_resolved", arg) in
  let bnds = bnd :: bnds in
  let arg = Ocaml.vof_option vof_type_arguments v_id_typeargs in
  let bnd = ("id_typeargs", arg) in
  let bnds = bnd :: bnds in
  let arg = Ocaml.vof_option vof_dotted_name v_id_qualifier in
  let bnd = ("id_qualifier", arg) in
  let bnds = bnd :: bnds in Ocaml.VDict bnds
and vof_special =
  function
  | This -> Ocaml.VSum (("This", []))
  | Super -> Ocaml.VSum (("Super", []))
  | Self -> Ocaml.VSum (("Self", []))
  | Parent -> Ocaml.VSum (("Parent", []))
  | Eval -> Ocaml.VSum (("Eval", []))
  | Typeof -> Ocaml.VSum (("Typeof", []))
  | Instanceof -> Ocaml.VSum (("Instanceof", []))
  | Sizeof -> Ocaml.VSum (("Sizeof", []))
  | New -> Ocaml.VSum (("New", []))
  | Concat -> Ocaml.VSum (("Concat", []))
  | Spread -> Ocaml.VSum (("Spread", []))
  | ArithOp v1 ->
      let v1 = vof_arithmetic_operator v1 in Ocaml.VSum (("ArithOp", [ v1 ]))
  | IncrDecr (v) ->
      let v = vof_inc_dec v in
      Ocaml.VSum (("IncrDecr", [ v]))

and vof_inc_dec (v1, v2) =
      let v1 = vof_incr_decr v1
      and v2 = vof_prepost v2
      in Ocaml.VTuple [ v1; v2 ]

and vof_incr_decr =
  function
  | Incr -> Ocaml.VSum (("Incr", []))
  | Decr -> Ocaml.VSum (("Decr", []))

and vof_prepost =
  function
  | Prefix -> Ocaml.VSum (("Prefix", []))
  | Postfix -> Ocaml.VSum (("Postfix", []))

and vof_arithmetic_operator =
  function
  | Plus -> Ocaml.VSum (("Plus", []))
  | Minus -> Ocaml.VSum (("Minus", []))
  | Mult -> Ocaml.VSum (("Mult", []))
  | Div -> Ocaml.VSum (("Div", []))
  | Mod -> Ocaml.VSum (("Mod", []))
  | Pow -> Ocaml.VSum (("Pow", []))
  | FloorDiv -> Ocaml.VSum (("FloorDiv", []))
  | LSL -> Ocaml.VSum (("LSL", []))
  | LSR -> Ocaml.VSum (("LSR", []))
  | ASR -> Ocaml.VSum (("ASR", []))
  | BitOr -> Ocaml.VSum (("BitOr", []))
  | BitXor -> Ocaml.VSum (("BitXor", []))
  | BitAnd -> Ocaml.VSum (("BitAnd", []))
  | BitNot -> Ocaml.VSum (("BitNot", []))
  | And -> Ocaml.VSum (("And", []))
  | Or -> Ocaml.VSum (("Or", []))
  | Not -> Ocaml.VSum (("Not", []))
  | Eq -> Ocaml.VSum (("Eq", []))
  | NotEq -> Ocaml.VSum (("NotEq", []))
  | PhysEq -> Ocaml.VSum (("PhysEq", []))
  | NotPhysEq -> Ocaml.VSum (("NotPhysEq", []))
  | Lt -> Ocaml.VSum (("Lt", []))
  | LtE -> Ocaml.VSum (("LtE", []))
  | Gt -> Ocaml.VSum (("Gt", []))
  | GtE -> Ocaml.VSum (("GtE", []))
and vof_arguments v = Ocaml.vof_list vof_argument v
and vof_argument =
  function
  | Arg v1 -> let v1 = vof_expr v1 in Ocaml.VSum (("Arg", [ v1 ]))
  | ArgKwd ((v1, v2)) ->
      let v1 = vof_name v1
      and v2 = vof_expr v2
      in Ocaml.VSum (("ArgKwd", [ v1; v2 ]))
  | ArgType v1 -> let v1 = vof_type_ v1 in Ocaml.VSum (("ArgType", [ v1 ]))
  | ArgOther ((v1, v2)) ->
      let v1 = vof_other_argument_operator v1
      and v2 = Ocaml.vof_list vof_any v2
      in Ocaml.VSum (("ArgOther", [ v1; v2 ]))
and vof_other_argument_operator =
  function
  | OA_ArgPow -> Ocaml.VSum (("OA_ArgPow", []))
  | OA_ArgComp -> Ocaml.VSum (("OA_ArgComp", []))
and vof_action (v1, v2) =
  let v1 = vof_pattern v1 and v2 = vof_expr v2 in Ocaml.VTuple [ v1; v2 ]
and vof_other_expr_operator =
  function
  | OE_Exports -> Ocaml.VSum (("OE_Exports", []))
  | OE_Module -> Ocaml.VSum (("OE_Module", []))
  | OE_Define -> Ocaml.VSum (("OE_Define", []))
  | OE_Arguments -> Ocaml.VSum (("OE_Arguments", []))
  | OE_NewTarget -> Ocaml.VSum (("OE_NewTarget", []))
  | OE_Delete -> Ocaml.VSum (("OE_Delete", []))
  | OE_YieldStar -> Ocaml.VSum (("OE_YieldStar", []))
  | OE_Encaps -> Ocaml.VSum (("OE_Encaps", []))
  | OE_Require -> Ocaml.VSum (("OE_Require", []))
  | OE_UseStrict -> Ocaml.VSum (("OE_UseStrict", []))
  | OE_ObjAccess_PN_Computed -> Ocaml.VSum (("OE_ObjAccess_PN_Computed", []))
  | OE_ExprClass -> Ocaml.VSum (("OE_ExprClass", []))
  | OE_Imag -> Ocaml.VSum (("OE_Imag", []))
  | OE_Is -> Ocaml.VSum (("OE_Is", []))
  | OE_IsNot -> Ocaml.VSum (("OE_IsNot", []))
  | OE_In -> Ocaml.VSum (("OE_In", []))
  | OE_NotIn -> Ocaml.VSum (("OE_NotIn", []))
  | OE_Invert -> Ocaml.VSum (("OE_Invert", []))
  | OE_Slice -> Ocaml.VSum (("OE_Slice", []))
  | OE_SliceIndex -> Ocaml.VSum (("OE_SliceIndex", []))
  | OE_SliceRange -> Ocaml.VSum (("OE_SliceRange", []))
  | OE_CompForIf -> Ocaml.VSum (("OE_CompForIf", []))
  | OE_CompFor -> Ocaml.VSum (("OE_CompFor", []))
  | OE_CompIf -> Ocaml.VSum (("OE_CompIf", []))
  | OE_CmpOps -> Ocaml.VSum (("OE_CmpOps", []))
  | OE_Repr -> Ocaml.VSum (("OE_Repr", []))
  | OE_NameOrClassType -> Ocaml.VSum (("OE_NameOrClassType", []))
  | OE_ClassLiteral -> Ocaml.VSum (("OE_ClassLiteral", []))
  | OE_GetRefLabel -> Ocaml.VSum (("OE_GetRefLabel", []))
  | OE_ArrayInitDesignator -> Ocaml.VSum (("OE_ArrayInitDesignator", []))
  | OE_GccConstructor -> Ocaml.VSum (("OE_GccConstructor", []))
  | OE_Unpack -> Ocaml.VSum (("OE_Unpack", []))
and vof_type_ =
  function
  | TyBuiltin v1 ->
      let v1 = vof_wrap Ocaml.vof_string v1
      in Ocaml.VSum (("TyBuiltin", [ v1 ]))
  | TyFun ((v1, v2)) ->
      let v1 = Ocaml.vof_list vof_type_ v1
      and v2 = vof_type_ v2
      in Ocaml.VSum (("TyFun", [ v1; v2 ]))
  | TyApply ((v1, v2)) ->
      let v1 = vof_name v1
      and v2 = vof_type_arguments v2
      in Ocaml.VSum (("TyApply", [ v1; v2 ]))
  | TyVar v1 -> let v1 = vof_name v1 in Ocaml.VSum (("TyVar", [ v1 ]))
  | TyArray ((v1, v2)) ->
      let v1 = Ocaml.vof_option vof_expr v1
      and v2 = vof_type_ v2
      in Ocaml.VSum (("TyArray", [ v1; v2 ]))
  | TyPointer v1 ->
      let v1 = vof_type_ v1 in Ocaml.VSum (("TyPointer", [ v1 ]))
  | TyTuple v1 ->
      let v1 = Ocaml.vof_list vof_type_ v1
      in Ocaml.VSum (("TyTuple", [ v1 ]))
  | TyQuestion v1 ->
      let v1 = vof_type_ v1 in Ocaml.VSum (("TyQuestion", [ v1 ]))
  | OtherType ((v1, v2)) ->
      let v1 = vof_other_type_operator v1
      and v2 = Ocaml.vof_list vof_any v2
      in Ocaml.VSum (("OtherType", [ v1; v2 ]))
and vof_type_arguments v = Ocaml.vof_list vof_type_argument v
and vof_type_argument =
  function
  | TypeArg v1 -> let v1 = vof_type_ v1 in Ocaml.VSum (("TypeArg", [ v1 ]))
  | OtherTypeArg ((v1, v2)) ->
      let v1 = vof_other_type_argument_operator v1
      and v2 = Ocaml.vof_list vof_any v2
      in Ocaml.VSum (("OtherTypeArg", [ v1; v2 ]))
and vof_other_type_argument_operator =
  function | OTA_Question -> Ocaml.VSum (("OTA_Question", []))
and vof_other_type_operator =
  function
  | OT_Expr -> Ocaml.VSum (("OT_Expr", []))
  | OT_Arg -> Ocaml.VSum (("OT_Arg", []))
  | OT_StructName -> Ocaml.VSum (("OT_StructName", []))
  | OT_UnionName -> Ocaml.VSum (("OT_UnionName", []))
  | OT_EnumName -> Ocaml.VSum (("OT_EnumName", []))
  | OT_Shape -> Ocaml.VSum (("OT_Shape", []))
  | OT_Variadic -> Ocaml.VSum (("OT_Variadic", []))
and vof_attribute =
  function
  | Static -> Ocaml.VSum (("Static", []))
  | Volatile -> Ocaml.VSum (("Volatile", []))
  | Extern -> Ocaml.VSum (("Extern", []))
  | Public -> Ocaml.VSum (("Public", []))
  | Private -> Ocaml.VSum (("Private", []))
  | Protected -> Ocaml.VSum (("Protected", []))
  | Abstract -> Ocaml.VSum (("Abstract", []))
  | Final -> Ocaml.VSum (("Final", []))
  | Var -> Ocaml.VSum (("Var", []))
  | Let -> Ocaml.VSum (("Let", []))
  | Const -> Ocaml.VSum (("Const", []))
  | Generator -> Ocaml.VSum (("Generator", []))
  | Async -> Ocaml.VSum (("Async", []))
  | Ctor -> Ocaml.VSum (("Ctor", []))
  | Dtor -> Ocaml.VSum (("Dtor", []))
  | Getter -> Ocaml.VSum (("Getter", []))
  | Setter -> Ocaml.VSum (("Setter", []))
  | Variadic -> Ocaml.VSum (("Variadic", []))
  | NamedAttr ((v1, v2)) ->
      let v1 = vof_name v1
      and v2 = Ocaml.vof_list vof_any v2
      in Ocaml.VSum (("NamedAttr", [ v1; v2 ]))
  | OtherAttribute ((v1, v2)) ->
      let v1 = vof_other_attribute_operator v1
      and v2 = Ocaml.vof_list vof_any v2
      in Ocaml.VSum (("OtherAttribute", [ v1; v2 ]))
and vof_other_attribute_operator =
  function
  | OA_StrictFP -> Ocaml.VSum (("OA_StrictFP", []))
  | OA_Transient -> Ocaml.VSum (("OA_Transient", []))
  | OA_Synchronized -> Ocaml.VSum (("OA_Synchronized", []))
  | OA_Native -> Ocaml.VSum (("OA_Native", []))
  | OA_AnnotJavaOther -> Ocaml.VSum (("OA_AnnotJavaOther", [ ]))
  | OA_AnnotThrow -> Ocaml.VSum (("OA_AnnotThrow", []))
  | OA_Expr -> Ocaml.VSum (("OA_Expr", []))
and vof_stmt =
  function
  | ExprStmt v1 -> let v1 = vof_expr v1 in Ocaml.VSum (("ExprStmt", [ v1 ]))
  | LocalDef v1 ->
      let v1 = vof_definition v1 in Ocaml.VSum (("LocalDef", [ v1 ]))
  | LocalDirective v1 ->
      let v1 = vof_directive v1 in Ocaml.VSum (("LocalDirective", [ v1 ]))
  | Block v1 ->
      let v1 = Ocaml.vof_list vof_stmt v1 in Ocaml.VSum (("Block", [ v1 ]))
  | If ((v1, v2, v3)) ->
      let v1 = vof_expr v1
      and v2 = vof_stmt v2
      and v3 = vof_stmt v3
      in Ocaml.VSum (("If", [ v1; v2; v3 ]))
  | While ((v1, v2)) ->
      let v1 = vof_expr v1
      and v2 = vof_stmt v2
      in Ocaml.VSum (("While", [ v1; v2 ]))
  | DoWhile ((v1, v2)) ->
      let v1 = vof_stmt v1
      and v2 = vof_expr v2
      in Ocaml.VSum (("DoWhile", [ v1; v2 ]))
  | For ((v1, v2)) ->
      let v1 = vof_for_header v1
      and v2 = vof_stmt v2
      in Ocaml.VSum (("For", [ v1; v2 ]))
  | Switch ((v1, v2)) ->
      let v1 = vof_expr v1
      and v2 = Ocaml.vof_list vof_case_and_body v2
      in Ocaml.VSum (("Switch", [ v1; v2 ]))
  | Return v1 -> let v1 = vof_expr v1 in Ocaml.VSum (("Return", [ v1 ]))
  | Continue v1 ->
      let v1 = Ocaml.vof_option vof_expr v1
      in Ocaml.VSum (("Continue", [ v1 ]))
  | Break v1 ->
      let v1 = Ocaml.vof_option vof_expr v1 in Ocaml.VSum (("Break", [ v1 ]))
  | Label ((v1, v2)) ->
      let v1 = vof_label v1
      and v2 = vof_stmt v2
      in Ocaml.VSum (("Label", [ v1; v2 ]))
  | Goto v1 -> let v1 = vof_label v1 in Ocaml.VSum (("Goto", [ v1 ]))
  | Throw v1 -> let v1 = vof_expr v1 in Ocaml.VSum (("Throw", [ v1 ]))
  | Try ((v1, v2, v3)) ->
      let v1 = vof_stmt v1
      and v2 = Ocaml.vof_list vof_catch v2
      and v3 = Ocaml.vof_option vof_finally v3
      in Ocaml.VSum (("Try", [ v1; v2; v3 ]))
  | Assert ((v1, v2)) ->
      let v1 = vof_expr v1
      and v2 = Ocaml.vof_option vof_expr v2
      in Ocaml.VSum (("Assert", [ v1; v2 ]))
  | OtherStmt ((v1, v2)) ->
      let v1 = vof_other_stmt_operator v1
      and v2 = Ocaml.vof_list vof_any v2
      in Ocaml.VSum (("OtherStmt", [ v1; v2 ]))
and vof_case_and_body (v1, v2) =
  let v1 = Ocaml.vof_list vof_case v1
  and v2 = vof_stmt v2
  in Ocaml.VTuple [ v1; v2 ]
and vof_case =
  function
  | Case v1 -> let v1 = vof_expr v1 in Ocaml.VSum (("Case", [ v1 ]))
  | Default -> Ocaml.VSum (("Default", []))
and vof_catch (v1, v2) =
  let v1 = vof_pattern v1 and v2 = vof_stmt v2 in Ocaml.VTuple [ v1; v2 ]
and vof_finally v = vof_stmt v
and vof_label v = vof_name v
and vof_for_header =
  function
  | ForClassic ((v1, v2, v3)) ->
      let v1 = Ocaml.vof_list vof_for_var_or_expr v1
      and v2 = vof_expr v2
      and v3 = vof_expr v3
      in Ocaml.VSum (("ForClassic", [ v1; v2; v3 ]))
  | ForEach ((v1, v2)) ->
      let v1 = vof_pattern v1
      and v2 = vof_expr v2
      in Ocaml.VSum (("ForEach", [ v1; v2 ]))
and vof_for_var_or_expr =
  function
  | ForInitVar ((v1, v2)) ->
      let v1 = vof_entity v1
      and v2 = vof_variable_definition v2
      in Ocaml.VSum (("ForInitVar", [ v1; v2 ]))
  | ForInitExpr v1 ->
      let v1 = vof_expr v1 in Ocaml.VSum (("ForInitExpr", [ v1 ]))
and vof_other_stmt_operator =
  function
  | OS_Delete -> Ocaml.VSum (("OS_Delete", []))
  | OS_Async -> Ocaml.VSum (("OS_Async", []))
  | OS_ForOrElse -> Ocaml.VSum (("OS_ForOrElse", []))
  | OS_WhileOrElse -> Ocaml.VSum (("OS_WhileOrElse", []))
  | OS_TryOrElse -> Ocaml.VSum (("OS_TryOrElse", []))
  | OS_With -> Ocaml.VSum (("OS_With", []))
  | OS_ThrowFrom -> Ocaml.VSum (("OS_ThrowFrom", []))
  | OS_ThrowNothing -> Ocaml.VSum (("OS_ThrowNothing", []))
  | OS_Global -> Ocaml.VSum (("OS_Global", []))
  | OS_NonLocal -> Ocaml.VSum (("OS_NonLocal", []))
  | OS_Pass -> Ocaml.VSum (("OS_Pass", []))
  | OS_Sync -> Ocaml.VSum (("OS_Sync", []))
  | OS_Asm -> Ocaml.VSum (("OS_Asm", []))
and vof_pattern =
  function
  | PatVar v1 -> let v1 = vof_name v1 in Ocaml.VSum (("PatVar", [ v1 ]))
  | PatLiteral v1 ->
      let v1 = vof_literal v1 in Ocaml.VSum (("PatLiteral", [ v1 ]))
  | PatConstructor ((v1, v2)) ->
      let v1 = vof_name v1
      and v2 = Ocaml.vof_list vof_pattern v2
      in Ocaml.VSum (("PatConstructor", [ v1; v2 ]))
  | PatTuple v1 ->
      let v1 = Ocaml.vof_list vof_pattern v1
      in Ocaml.VSum (("PatTuple", [ v1 ]))
  | PatList v1 ->
      let v1 = Ocaml.vof_list vof_pattern v1
      in Ocaml.VSum (("PatList", [ v1 ]))
  | PatKeyVal ((v1, v2)) ->
      let v1 = vof_pattern v1
      and v2 = vof_pattern v2
      in Ocaml.VSum (("PatKeyVal", [ v1; v2 ]))
  | PatUnderscore v1 ->
      let v1 = vof_tok v1 in Ocaml.VSum (("PatUnderscore", [ v1 ]))
  | PatDisj ((v1, v2)) ->
      let v1 = vof_pattern v1
      and v2 = vof_pattern v2
      in Ocaml.VSum (("PatDisj", [ v1; v2 ]))
  | PatTyped ((v1, v2)) ->
      let v1 = vof_pattern v1
      and v2 = vof_type_ v2
      in Ocaml.VSum (("PatTyped", [ v1; v2 ]))
  | OtherPat ((v1, v2)) ->
      let v1 = vof_other_pattern_operator v1
      and v2 = Ocaml.vof_list vof_any v2
      in Ocaml.VSum (("OtherPat", [ v1; v2 ]))
and vof_other_pattern_operator =
  function
  | OP_Expr -> Ocaml.VSum (("OP_Expr", []))
  | OP_Var -> Ocaml.VSum (("OP_Var", []))
and vof_definition (v1, v2) =
  let v1 = vof_entity v1
  and v2 = vof_definition_kind v2
  in Ocaml.VTuple [ v1; v2 ]
and
  vof_entity {
               name = v_name;
               attrs = v_attrs;
               type_ = v_type_;
               tparams = v_tparams
             } =
  let bnds = [] in
  let arg = Ocaml.vof_list vof_type_parameter v_tparams in
  let bnd = ("tparams", arg) in
  let bnds = bnd :: bnds in
  let arg = Ocaml.vof_option vof_type_ v_type_ in
  let bnd = ("type_", arg) in
  let bnds = bnd :: bnds in
  let arg = Ocaml.vof_list vof_attribute v_attrs in
  let bnd = ("attrs", arg) in
  let bnds = bnd :: bnds in
  let arg = vof_name v_name in
  let bnd = ("name", arg) in let bnds = bnd :: bnds in Ocaml.VDict bnds
and vof_definition_kind =
  function
  | FuncDef v1 ->
      let v1 = vof_function_definition v1 in Ocaml.VSum (("FuncDef", [ v1 ]))
  | VarDef v1 ->
      let v1 = vof_variable_definition v1 in Ocaml.VSum (("VarDef", [ v1 ]))
  | ClassDef v1 ->
      let v1 = vof_class_definition v1 in Ocaml.VSum (("ClassDef", [ v1 ]))
  | TypeDef v1 ->
      let v1 = vof_type_definition v1 in Ocaml.VSum (("TypeDef", [ v1 ]))
and vof_type_parameter (v1, v2) =
  let v1 = vof_name v1
  and v2 = vof_type_parameter_constraints v2
  in Ocaml.VTuple [ v1; v2 ]
and vof_type_parameter_constraints v =
  Ocaml.vof_list vof_type_parameter_constraint v
and vof_type_parameter_constraint =
  function
  | Extends v1 -> let v1 = vof_type_ v1 in Ocaml.VSum (("Extends", [ v1 ]))
and
  vof_function_definition {
                            fparams = v_fparams;
                            frettype = v_frettype;
                            fbody = v_fbody
                          } =
  let bnds = [] in
  let arg = vof_stmt v_fbody in
  let bnd = ("fbody", arg) in
  let bnds = bnd :: bnds in
  let arg = Ocaml.vof_option vof_type_ v_frettype in
  let bnd = ("frettype", arg) in
  let bnds = bnd :: bnds in
  let arg = vof_parameters v_fparams in
  let bnd = ("fparams", arg) in let bnds = bnd :: bnds in Ocaml.VDict bnds
and vof_parameters v = Ocaml.vof_list vof_parameter v
and vof_parameter =
  function
  | ParamClassic v1 ->
      let v1 = vof_parameter_classic v1
      in Ocaml.VSum (("ParamClassic", [ v1 ]))
  | ParamPattern v1 ->
      let v1 = vof_pattern v1 in Ocaml.VSum (("ParamPattern", [ v1 ]))
  | OtherParam ((v1, v2)) ->
      let v1 = vof_other_parameter_operator v1
      and v2 = Ocaml.vof_list vof_any v2
      in Ocaml.VSum (("OtherParam", [ v1; v2 ]))
and
  vof_parameter_classic {
                          pname = v_pname;
                          pdefault = v_pdefault;
                          ptype = v_ptype;
                          pattrs = v_pattrs
                        } =
  let bnds = [] in
  let arg = Ocaml.vof_list vof_attribute v_pattrs in
  let bnd = ("pattrs", arg) in
  let bnds = bnd :: bnds in
  let arg = Ocaml.vof_option vof_type_ v_ptype in
  let bnd = ("ptype", arg) in
  let bnds = bnd :: bnds in
  let arg = Ocaml.vof_option vof_expr v_pdefault in
  let bnd = ("pdefault", arg) in
  let bnds = bnd :: bnds in
  let arg = vof_name v_pname in
  let bnd = ("pname", arg) in let bnds = bnd :: bnds in Ocaml.VDict bnds
and vof_other_parameter_operator =
  function
  | OPO_KwdParam -> Ocaml.VSum (("OPO_KwdParam", []))
  | OPO_Ref -> Ocaml.VSum (("OPO_Ref", []))
and vof_variable_definition { vinit = v_vinit; vtype = v_vtype } =
  let bnds = [] in
  let arg = Ocaml.vof_option vof_type_ v_vtype in
  let bnd = ("vtype", arg) in
  let bnds = bnd :: bnds in
  let arg = Ocaml.vof_option vof_expr v_vinit in
  let bnd = ("vinit", arg) in let bnds = bnd :: bnds in Ocaml.VDict bnds
and vof_field =
  function
  | FieldVar ((v1, v2)) ->
      let v1 = vof_entity v1
      and v2 = vof_variable_definition v2
      in Ocaml.VSum (("FieldVar", [ v1; v2 ]))
  | FieldMethod ((v1, v2)) ->
      let v1 = vof_entity v1
      and v2 = vof_function_definition v2
      in Ocaml.VSum (("FieldMethod", [ v1; v2 ]))
  | FieldDynamic ((v1, v2, v3)) ->
      let v1 = vof_expr v1
      and v2 = Ocaml.vof_list vof_attribute v2
      and v3 = vof_expr v3
      in Ocaml.VSum (("FieldDynamic", [ v1; v2; v3 ]))
  | FieldSpread v1 ->
      let v1 = vof_expr v1 in Ocaml.VSum (("FieldSpread", [ v1 ]))
  | FieldStmt v1 ->
      let v1 = vof_stmt v1 in Ocaml.VSum (("FieldStmt", [ v1 ]))
and vof_type_definition =
  function
  | OrType v1 ->
      let v1 = Ocaml.vof_list vof_or_type_element v1
      in Ocaml.VSum (("OrType", [ v1 ]))
  | AndType v1 ->
      let v1 = Ocaml.vof_list vof_field v1
      in Ocaml.VSum (("AndType", [ v1 ]))
  | AliasType v1 ->
      let v1 = vof_type_ v1 in Ocaml.VSum (("AliasType", [ v1 ]))
  | OtherTypeKind ((v1, v2)) ->
      let v1 = vof_other_type_kind_operator v1
      and v2 = Ocaml.vof_list vof_any v2
      in Ocaml.VSum (("OtherTypeKind", [ v1; v2 ]))
and vof_other_type_kind_operator =
  function | OTKO_EnumWithValue -> Ocaml.VSum (("OTKO_EnumWithValue", []))
and vof_or_type_element =
  function
  | OrConstructor ((v1, v2)) ->
      let v1 = vof_name v1
      and v2 = Ocaml.vof_list vof_type_ v2
      in Ocaml.VSum (("OrConstructor", [ v1; v2 ]))
  | OrEnum ((v1, v2)) ->
      let v1 = vof_name v1
      and v2 = vof_expr v2
      in Ocaml.VSum (("OrEnum", [ v1; v2 ]))
  | OrUnion ((v1, v2)) ->
      let v1 = vof_name v1
      and v2 = vof_type_ v2
      in Ocaml.VSum (("OrUnion", [ v1; v2 ]))
and
  vof_class_definition {
                         ckind = v_ckind;
                         cextends = v_cextends;
                         cimplements = v_cimplements;
                         cbody = v_cbody
                       } =
  let bnds = [] in
  let arg = Ocaml.vof_list vof_field v_cbody in
  let bnd = ("cbody", arg) in
  let bnds = bnd :: bnds in
  let arg = Ocaml.vof_list vof_type_ v_cimplements in
  let bnd = ("cimplements", arg) in
  let bnds = bnd :: bnds in
  let arg = Ocaml.vof_list vof_type_ v_cextends in
  let bnd = ("cextends", arg) in
  let bnds = bnd :: bnds in
  let arg = vof_class_kind v_ckind in
  let bnd = ("ckind", arg) in let bnds = bnd :: bnds in Ocaml.VDict bnds
and vof_class_kind =
  function
  | Class -> Ocaml.VSum (("Class", []))
  | Interface -> Ocaml.VSum (("Interface", []))
  | Trait -> Ocaml.VSum (("Trait", []))
and vof_directive =
  function
  | Import ((v1, v2)) ->
      let v1 = vof_module_name v1
      and v2 = Ocaml.vof_list vof_alias v2
      in Ocaml.VSum (("Import", [ v1; v2 ]))
  | ImportAll ((v1, v2)) ->
      let v1 = vof_module_name v1
      and v2 = Ocaml.vof_option vof_name v2
      in Ocaml.VSum (("ImportAll", [ v1; v2 ]))
  | OtherDirective ((v1, v2)) ->
      let v1 = vof_other_directive_operator v1
      and v2 = Ocaml.vof_list vof_any v2
      in Ocaml.VSum (("OtherDirective", [ v1; v2 ]))
and vof_alias (v1, v2) =
  let v1 = vof_name v1
  and v2 = Ocaml.vof_option vof_name v2
  in Ocaml.VTuple [ v1; v2 ]
and vof_other_directive_operator =
  function
  | OI_Export -> Ocaml.VSum (("OI_Export", []))
  | OI_ImportCss -> Ocaml.VSum (("OI_ImportCss", []))
  | OI_ImportEffect -> Ocaml.VSum (("OI_ImportEffect", []))
  | OI_Package -> Ocaml.VSum (("OI_Package", []))
  | OI_Define -> Ocaml.VSum (("OI_Define", []))
  | OI_Macro -> Ocaml.VSum (("OI_Macro", []))
  | OI_Prototype -> Ocaml.VSum (("OI_Prototype", []))
  | OI_Namespace -> Ocaml.VSum (("OI_Namespace", []))
and vof_item =
  function
  | IStmt v1 -> let v1 = vof_stmt v1 in Ocaml.VSum (("IStmt", [ v1 ]))
  | IDef v1 -> let v1 = vof_definition v1 in Ocaml.VSum (("IDef", [ v1 ]))
  | IDir v1 -> let v1 = vof_directive v1 in Ocaml.VSum (("IDir", [ v1 ]))
and vof_program v = Ocaml.vof_list vof_item v
and vof_any =
  function
  | N v1 -> let v1 = vof_name v1 in Ocaml.VSum (("N", [ v1 ]))
  | En v1 -> let v1 = vof_entity v1 in Ocaml.VSum (("En", [ v1 ]))
  | E v1 -> let v1 = vof_expr v1 in Ocaml.VSum (("E", [ v1 ]))
  | S v1 -> let v1 = vof_stmt v1 in Ocaml.VSum (("S", [ v1 ]))
  | T v1 -> let v1 = vof_type_ v1 in Ocaml.VSum (("T", [ v1 ]))
  | P v1 -> let v1 = vof_pattern v1 in Ocaml.VSum (("P", [ v1 ]))
  | D v1 -> let v1 = vof_definition v1 in Ocaml.VSum (("D", [ v1 ]))
  | Di v1 -> let v1 = vof_directive v1 in Ocaml.VSum (("Di", [ v1 ]))
  | Dn v1 -> let v1 = vof_dotted_name v1 in Ocaml.VSum (("Dn", [ v1 ]))
  | I v1 -> let v1 = vof_item v1 in Ocaml.VSum (("I", [ v1 ]))
  | Pa v1 -> let v1 = vof_parameter v1 in Ocaml.VSum (("Pa", [ v1 ]))
  | Ar v1 -> let v1 = vof_argument v1 in Ocaml.VSum (("Ar", [ v1 ]))
  | At v1 -> let v1 = vof_attribute v1 in Ocaml.VSum (("At", [ v1 ]))
  | Dk v1 -> let v1 = vof_definition_kind v1 in Ocaml.VSum (("Dk", [ v1 ]))
  | Pr v1 -> let v1 = vof_program v1 in Ocaml.VSum (("Pr", [ v1 ]))
  
