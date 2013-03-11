(* records, files, gtables *)
open Printf
open Batteries
open JSON.Operators

(* External interface common to all data objects *)
module type S = sig
  type t

  val make_new : JSON.t -> t
  val bind : (string option*string) -> t

  val close : ?wait:bool -> t -> unit
  val with_new : ?wait:bool -> JSON.t -> (t -> 'a) -> 'a

  val id : t -> string
  val describe : ?options:JSON.t -> t -> JSON.t

  val rename : t -> string -> unit 
  val set_properties : t -> (string*(string option)) list -> unit
  val add_tags : t -> string list -> unit
  val remove_tags : t -> string list -> unit

  val add_types : t -> string list -> unit  
  val remove_types : t -> string list -> unit
  val set_details : t -> JSON.t -> unit
  val get_details : t -> JSON.t
  val set_visibility : t -> hidden:bool -> unit

(* Internal representation common to all data objects *)
module Base = struct
  type t = {
    id : string;
    project : string option
  }

  let id {id} = id
  let project {project} = project      

(* Internal interface to the base representation that must be provided by all subclasses *)
module type Subclass = sig
  val dxclass : string   (* class name, e.g. "file", "gtable" *)
  type t                 (* the subclass' type *)
  val bind : Base.t -> t (* bind to specified existing data object *)
  val base : t -> Base.t (* retrieve base representation from data object *)

(* Functor to implement common external interface for given subclass *)
module Make = functor (T : Subclass) -> struct
  type t = T.t

  (* helpers: add appropriate "project" key to given JSON *)
  let with_required_project x json =
    if json $? "project" then json
    else
      match Base.project (T.base x) with
        | Some p -> json $+ ("project",`String p)
        | None -> json $+ ("project",`String (DX.workspace_id()))
  let with_optional_project x json =
    try
      with_required_project x json
    with
      | _ -> json    

  let bind (project,id) = T.bind {Base.id; project}

  let make_new options =
    let options =
      if options $? "project" then options
      else
        let project = DX.workspace_id()
        options $+ ("project",`String project)
    let ans = DX.api_call [T.dxclass; "new"] options
    bind (Some (JSON.string (options$"project")), JSON.string (ans$"id"))

  let id x = Base.id (T.base x)

  let describe ?(options=JSON.empty) x = DX.api_call [id x; "describe"] (with_optional_project x options)

  (* metadata *)

  let rename x nm =
    let input = with_required_project x (JSON.of_assoc ["name", `String nm])
    ignore (DX.api_call [id x; "rename"] input)
        
  let set_properties x props =
    let prophash =
      JSON.of_assoc
        List.map
          function
            | (k,Some v) -> k,`String v
            | (k,None) -> k,`Null
          props 
    let input =
      with_required_project x
        JSON.empty $+ ("properties",prophash)
    ignore (DX.api_call [id x; "setProperties"] input)

  let string_list_json_helper k lst =
    JSON.of_assoc [k, JSON.of_list (List.map (fun t -> `String t) lst)]

  let add_tags x tags =
    let input = with_required_project x (string_list_json_helper "tags" tags)
    ignore (DX.api_call [id x; "addTags"] input)

  let remove_tags x tags =
    let input = with_required_project x (string_list_json_helper "tags" tags)
    ignore (DX.api_call [id x; "removeTags"] input)

  (* data *)

  let add_types x types =
    ignore (DX.api_call [id x; "addTypes"] (string_list_json_helper "types" types))

  let remove_types x types =
    ignore (DX.api_call [id x; "removeTypes"] (string_list_json_helper "types" types))

  let get_details x = DX.api_call [id x; "getDetails"] JSON.empty

  let set_details x deets = ignore (DX.api_call [id x; "setDetails"] deets)

  let set_visibility x ~hidden =
    ignore
      DX.api_call [id x; "setVisibility"]
        JSON.of_assoc ["hidden", `Bool hidden]

  (* close *)

  (* TODO: make wait an int timeout instead of a bool *)

  let rec await_close x =
    if JSON.string ((describe x)$"state") <> "closed" then
      Thread.delay 2.0
      await_close x
  let close ?(wait=false) x =
    ignore (DX.api_call [id x; "close"] JSON.empty)
    if wait then await_close x

  let with_new ?(wait=false) options f =
    let o = make_new options
    let ans = f o
    try
      ignore (DX.api_call [id o; "close"] JSON.empty)
    with
      (* object is already closing/closed -- that's okay *)
      | DX.APIError ("InvalidState", _, _) -> ()
    if wait then await_close o
    ans


(* Record *)
module Record = struct
  module T = struct
    let dxclass = "record"
    type t = Base.t
    let bind b = b
    let base b = b

  include Make(T)


(* File *)
module File = struct
  let oneMB = 1048576

  module T = struct
    let dxclass = "file"
    type t = { b : Base.t; mutable closed_size : int option; mutable part_size : int; mutable parallelism : int }
    let bind b = { b; closed_size = None; part_size = 64*oneMB; parallelism = 4 }
    let base { b } = b

  include Make(T)

  let describe ?options x =
    let desc = describe ?options x
    (* if the file is closed, cache its size so that calls to download don't need to call describe again *)
    if x.T.closed_size = None && JSON.string (desc$"state") = "closed" then
      x.T.closed_size <- Some (JSON.int (desc$"size"))
    desc

  let open_output ({T.part_size; parallelism} as fo) =
    FileHelpers.create_output ~part_size ~parallelism (id fo)
  let with_output fo f =
    let output = open_output fo
    finally (fun _ -> IO.close_out output) f output

  let upload fo fn =
    File.with_file_in fn
      fun infile ->
        let output = open_output fo
        IO.copy ~buffer:oneMB infile output
        IO.close_out output

  let download_url ?duration fo = 
    let api_input = match duration with
      | None -> JSON.empty
      | Some dur -> JSON.of_assoc ["duration", `Int dur]
    JSON.string (DX.api_call [id fo; "download"] api_input $ "url")

  let open_input ?duration ?pos ({T.part_size; parallelism; closed_size} as fo) =
    let size = match closed_size with
      | Some sz -> sz
      | None -> JSON.int (describe fo $ "size")
    FileHelpers.create_input ~part_size ~parallelism ?pos ~url:(download_url ?duration fo) ~size (id fo)
  let with_input ?duration ?pos fo f =
    let input = open_input ?duration ?pos fo
    finally (fun _ -> IO.close_in input) f input

  let download ?duration ({T.part_size; parallelism} as fo) fn =
    with_input ?duration fo
      fun input ->
        File.with_file_out fn (IO.copy ~buffer:1048576 input)

  let reconfigure ?part_size ?parallelism fo =
    let open T
    part_size |> Option.may 
      fun n ->
        if n < 1 then invalid_arg "DNAnexus.File.reconfigure part_size <= 0"
        fo.part_size <- n
    parallelism |> Option.may
      fun n ->
        if n < 1 then invalid_arg "DNAnexus.File.reconfigure parallelism <= 0"
        fo.parallelism <- n

  let upload_new ?(options=JSON.empty) ?wait fn =
    if not (Sys.file_exists fn) then failwith "DNAnexus.File.upload_new: local file not found"
    let input =
      List.fold_left
        fun hash key -> hash $+ (key, (options $ key))
        JSON.of_assoc ["name", `String (Filename.basename fn)]
        JSON.obj_keys options
    with_new ?wait input (fun dxfile -> upload dxfile fn; dxfile)

(* GTable *)
module GTable = struct

  type datum =  GTableHelpers.datum
  type row = GTableHelpers.row
  let json_of_row = GTableHelpers.json_of_row

  type column_type = GTableHelpers.column_type
  let column_type_of_string = GTableHelpers.column_type_of_string
  type column_desc = GTableHelpers.column_desc
  let json_of_columns = GTableHelpers.json_of_columns

  type index = GTableHelpers.index
  let json_of_indices = GTableHelpers.json_of_indices

  type query_parameters = GTableHelpers.query_parameters

  open GTableHelpers

  module T = struct
    let dxclass = "gtable"
    type t = { b : Base.t;
               mutable known_columns : column_desc array option;
               mutable known_indices : index list option;
               mutable closed_rows : int option;
               mutable maybe_adder : RowAdder.t option;
               mutable pagination : int; mutable parallelism : int }
    let bind b = { b; known_columns = None; known_indices = None; closed_rows = None; maybe_adder = None; pagination = 100000; parallelism = 4 }
    let base { b } = b
  open T
  include Make(T)

  let describe ?options x =
    let desc = describe ?options x
    (* cache immutable info from the description, to reduce the need for future describe calls *)
    if x.known_columns = None then
      let cols = 
        Array.of_enum
          Enum.map
            fun cj -> JSON.string (cj$"name"), column_type_of_string (JSON.string (cj$"type"))
            Vect.enum (JSON.array (desc$"columns"))
      x.known_columns <- Some cols
    if x.known_indices = None then
      x.known_indices <- Some (if desc$?"indices" then indices_of_json (desc$"indices") else [])
    if x.closed_rows = None && (desc$"state") = `String "closed" then
      x.closed_rows <- Some (JSON.int (desc$"length"))
    desc

  let columns x =
    if x.known_columns = None then ignore (describe x)
    Array.copy (Option.get x.known_columns)

  let indices x =
    if x.known_indices = None then ignore (describe x)
    Option.get x.known_indices
  
  let adder gt = match gt.maybe_adder with
    | Some adder -> adder
    | None ->
        let adder = RowAdder.make ~pagination:gt.pagination ~parallelism:gt.parallelism ~dxid:(id gt)
        gt.maybe_adder <- Some adder
        adder

  let add_row ?(typecheck=false) gt row =
    if typecheck then RowAdder.typecheck_row (columns gt) row
    RowAdder.add_row (adder gt) row

  let flush_rows gt = RowAdder.flush_rows (adder gt)

  let with_flush_rows gt f =
    let y = f gt
    flush_rows gt
    y

  let schema = columns

  let iterate_rows ?starting ?limit ?columns gt =
    let table_rows = match gt.closed_rows with
      | Some n -> n
      | None ->
          ignore (describe gt)
          if gt.closed_rows = None then failwith "DNAnexus.GTable.iterate_rows: GTable must be in the \"closed\" state"
          Option.get gt.closed_rows
    RowEnum.create ~pagination:gt.pagination ~parallelism:gt.parallelism ?columns ?starting ?limit ~table_rows ~table_schema:(schema gt) (id gt)

  let query_rows ?limit ?columns gt index_name parameters =
    let table_rows = match gt.closed_rows with
      | Some n -> n
      | None ->
          ignore (describe gt)
          if gt.closed_rows = None then failwith "DNAnexus.GTable.query_rows: GTable must be in the \"closed\" state"
          Option.get gt.closed_rows
    RowEnum.create ~pagination:gt.pagination ~parallelism:gt.parallelism ~query:(json_of_query index_name parameters) ?columns ?limit ~table_rows ~table_schema:(schema gt) (id gt)

  (* TODO: pagination should be based on size of buffered JSON, not # rows *)

  let reconfigure ?pagination ?parallelism gt =
    pagination |> Option.may 
      fun n ->
        if n < 1 then invalid_arg "DNAnexus.GTable.reconfigure pagination <= 0"
        gt.pagination <- n
    parallelism |> Option.may
      fun n ->
        if n < 1 then invalid_arg "DNAnexus.GTable.reconfigure parallelism <= 0"
        gt.parallelism <- n
