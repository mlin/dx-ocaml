(* Helper functions for GTable bindings *)

open Batteries
open JSON.Operators
open Printf

type datum = [`Bool of bool | `Int of int | `Float of float | `String of string]
type row = datum array

let json_of_row row = Array.enum row /@ (fun x -> (x :> JSON.t)) |> Vect.of_enum |> (fun v -> ((`Array v) :> JSON.t))

type column_type = [`Bool | `UInt8 | `Int16 | `UInt16 | `Int32 | `UInt32 | `Int64 | `Float | `Double | `String]
let column_type_string_mapping = [
  `Bool, "boolean";
  `UInt8, "uint8";
  `Int16, "int16";
  `UInt16, "uint16";
  `Int32, "int32";
  `UInt32, "uint32";
  `Int64, "int64";
  `Float, "float";
  `Double, "double";
  `String, "string"
]
let column_type_of_string s =
  try
    List.assoc_inv s column_type_string_mapping
  with Not_found -> failwith (sprintf "DNAnexus.GTable: unrecognized column type \"%s\"" s)
let string_of_column_type x = List.assoc x column_type_string_mapping
type column_desc = string*column_type

let json_of_columns cols = 
  JSON.of_array
    cols |> Array.map
      fun (nm,ty) ->
        JSON.of_assoc [
          "name", `String nm;
          "type", `String (string_of_column_type ty)
        ]

let columns_of_json cols =
  JSON.array cols |> Vect.enum |> List.of_enum |> List.map
    fun json_col -> (JSON.string (json_col$"name"))

type index = string*[
    `GRI of string*string*string
  | `Lexicographic of ((string*[`Asc|`Desc]) list)
]

let json_of_indices indices =
  JSON.of_list
    indices |> List.map
      function
        | nm, `GRI (chr,lo,hi) ->
            JSON.of_assoc [
              "name", `String nm;
              "type", `String "genomic";
              "chr", `String chr;
              "lo", `String lo;
              "hi", `String hi
            ]
        | nm, `Lexicographic cols ->
            let json_cols =
              JSON.of_list
                cols |> List.map
                  fun (colnm,colord) ->
                    JSON.of_list [
                      `String colnm;
                      `String (match colord with `Asc -> "asc" | `Desc -> "desc")
                    ]
            JSON.of_assoc [
              "name", `String nm;
              "type", `String "lexicographic";
              "columns", json_cols
            ]

let indices_of_json json =
  JSON.array json |> Vect.enum |> List.of_enum |> List.map
    fun json_idx ->
      let s k = JSON.string (json_idx$k)
      let nm = s "name"
      match s "type" with
        | "genomic" -> nm, `GRI (s "chr", s "lo", s "hi")
        | "lexicographic" ->
            let cols =
              JSON.array (json_idx$"columns") |> Vect.enum |> List.of_enum |> List.map
                fun col ->
                  let colord = match String.lowercase (JSON.string (col$"order")) with
                    | "asc" -> `Asc
                    | "desc" -> `Desc
                    | _ -> failwith (sprintf "DNAnexus.GTable: unrecognized column order in lexicographic index %s" (JSON.to_string json_idx))
                  JSON.string (col$"name"), colord
            nm, `Lexicographic cols
        | _ -> failwith (sprintf "DNAnexus.GTable: unrecognized index %s" (JSON.to_string json_idx))

type query_parameters = [
  | `GRI of string*int*int*[`Overlap|`Enclose]
  | `Lexicographic of (string*[`Eq|`Gt|`Gte|`Lt|`Lte]*string) list
]

let json_of_query idxnm params =
  let p = match params with
    | `GRI (chr,lo,hi,mode) ->
        JSON.of_assoc [
          "coords", JSON.of_list [`String chr; `Int lo; `Int hi];
          "mode", `String (match mode with `Overlap -> "overlap" | `Enclose -> "enclose")
        ]
    | `Lexicographic clauses ->
        JSON.of_assoc [
          "$and", JSON.of_list (clauses |> List.map
            (fun (colnm,op,v) -> JSON.of_assoc [
              colnm, JSON.of_assoc [
                (match op with `Eq -> "$eq" | `Gt -> "$gt" | `Gte -> "$gte" | `Lt -> "$lt" | `Lte -> "$lte"),
                `String v
              ]
            ]))
        ]
  JSON.of_assoc [
    "index", `String idxnm;
    "parameters", p
  ]

module RowAdder = struct
  (* FIXME: set ~always_retry:true *)
  let perform_addRows id reqbdy = ignore (DX.api_call_raw_body [id; "addRows"] reqbdy)

  let addRows_thread (id,row_gen) =
    let part = JSON.int (DXAPI.gtable_next_part id JSON.empty $ "part")
    YAJL.gen_end_array row_gen
    YAJL.gen_string row_gen "part"
    YAJL.gen_int row_gen part
    YAJL.gen_end_map row_gen
    (* TODO: reduce copying *)
    let reqbdy, reqbdyofs, reqbdylen = YAJL.gen_get_buf row_gen
    let reqbdy = String.sub reqbdy reqbdyofs reqbdylen
    YAJL.gen_clear row_gen
    (* finish with a tail-call so that row_gen can be garbage-collected *)
    perform_addRows id reqbdy

  type t = {
    (* GTable ID *)
    dxid : string;

    (* maximum # of rows to buffer before calling addRows *)
    pagination : int;
    (* current # of rows buffered *)
    mutable row_count : int;
    (* YAJL generator for the array of arrays *)
    mutable row_gen : YAJL.gen;

    tp : unit ThreadPool.t
  }

  let fresh_gen () =
    let gen = YAJL.make_gen ~options:[`Validate_UTF8] ()
    YAJL.gen_start_map gen
    YAJL.gen_string gen "data"
    YAJL.gen_start_array gen
    (* now gen is ready to receive individual rows *)
    gen

  let check_unflushed adder =
    if adder.row_count > 0 then
      eprintf "[WARN] DNAnexus-ocaml: buffered row data in a GTable object is being garbage-collected without having been uploaded!\n"
      flush stderr      

  let make ~pagination ~parallelism ~dxid =
    let adder = {
      dxid;
      pagination;
      row_count = 0;
      row_gen = fresh_gen ();
      tp = ThreadPool.make ~maxthreads:parallelism ()
    }
    Gc.finalise check_unflushed adder
    adder

  let launch_addRows adder =
    if adder.row_count > 0 then
      ignore (ThreadPool.launch adder.tp addRows_thread (adder.dxid,adder.row_gen))
      adder.row_gen <- fresh_gen ()
      adder.row_count <- 0
      FileHelpers.check_threads adder.tp

  let flush_rows adder =
    launch_addRows adder
    ThreadPool.drain adder.tp
    FileHelpers.check_threads adder.tp

  let add_row adder (row:row) =
    JSON.generate adder.row_gen
      `Array
        Array.fold_right
          fun cell v -> BatVect.prepend (cell :> JSON.t) v
          row
          BatVect.empty
    adder.row_count <- 1 + adder.row_count
    if adder.row_count >= adder.pagination then launch_addRows adder

  exception IntOutOfRange of int64*int64
  let int_bounds = [`UInt8, (0L,255L); `UInt16, (0L,65535L); `Int16, (-32768L,32767L);
    `Int32, (-2_147_483_648L,2_147_483_647L); `UInt32, (0L,4_294_967_295L);
    `Int64, (-9_007_199_254_740_992L,9_007_199_254_740_992L)]
  let typecheck_int ty x =
    let (lo,hi) = List.assoc ty int_bounds
    let xL = Int64.of_int x
    if xL < lo || xL > hi then
      raise (IntOutOfRange (lo,hi))

  let typecheck_row columns row =
    let n = Array.length columns
    try
      if Array.length row <> n then
        invalid_arg (sprintf "DNAnexus.GTable.add_row: expected row with %d columns, got %d columns" n (Array.length row))
      for i = 0 to n-1 do
        match (snd columns.(i)), row.(i) with
          | (`UInt8 as ty), `Int x 
          | (`Int16 as ty), `Int x
          | (`UInt16 as ty), `Int x
          | (`Int32 as ty), `Int x
          | (`UInt32 as ty), `Int x
          | (`Int64 as ty), `Int x ->
              try typecheck_int ty x
              with IntOutOfRange (lo,hi) ->
                invalid_arg (sprintf "DNAnexus.GTable.add_row: expected int in the range [%Ld,%Ld] in column \"%s\", got %d" lo hi (fst columns.(i)) x)
          | `Bool, `Bool _
          | `Float, `Float _ (* TODO: detect loss of precision *)
          | `Double, `Float _
          | `String, `String _ -> ()
          | `Bool, _ -> invalid_arg (sprintf "DNAnexus.GTable.add_row: expected bool in column \"%s\"" (fst columns.(i)))
          | `Float, _
          | `Double, _ -> invalid_arg (sprintf "DNAnexus.GTable.add_row: expected float in column \"%s\"" (fst columns.(i)))
          | `String, _ -> invalid_arg (sprintf "DNAnexus.GTable.add_row: expected string in column \"%s\"" (fst columns.(i)))
          | _ -> invalid_arg (sprintf "DNAnexus.GTable.add_row: expected int in column \"%s\"" (fst columns.(i)))
    with
      | Invalid_argument msg ->
          invalid_arg (msg ^ "\n" ^ (JSON.to_string (json_of_row row)))

let datum_of_json = function
  | `Bool _ 
  | `Float _
  | `Int _
  | `String _ as x -> (x:datum)
  | _ -> failwith "Invalid table entry returned by /gtable-xxxx/get"

let row_of_json = function
  | `Array vect -> Vect.enum vect /@ datum_of_json |> Array.of_enum
  | _ -> failwith "Invalid row returned by /gtable-xxxx/get"

(* create an enum to perform paginated /gtable-xxxx/get requests, either for scrolling
   through the table in its natural order, or for performing a query. *)
module RowEnum = struct
  (* thread to perform /gtable-xxxx/get API call *)
  let get_thread (dxid,pagination,starting,query,columns) =
    let input =
      List.filter_map
        fun x -> x
        [Some ("limit",`Int pagination);
         Option.map (fun n -> "starting", `Int n) starting;
         Option.map (fun q -> "query", q) query;
         Option.map (fun c -> "columns", c) columns]
    let ans = DXAPI.gtable_get dxid (JSON.of_assoc input)
    let starting =
      if not (ans $? "next") then None
      else if ans$"next" = `Null then None
      else Some (JSON.int (ans$"next"))
    let rows = Vect.enum (JSON.array (ans$"data")) /@ row_of_json |> List.of_enum
    rows, starting

  (* given the table schema and requested columns, return a function that will
     fix up ambiguous JSON numbers. Specifically, if the column type is
     floating-point but we decoded the JSON number as an int (especially 0),
     replace it with a float. *)
  let make_row_fixerupper dxid table_schema columns =
    (* make array of column types we expect to be returned by /gtable-xxxx/get *)
    let row_types = match columns with
      | None -> Array.of_list (`Int64 :: (List.map snd (Array.to_list table_schema)))
      | Some cols ->
          let schema_assoc = Array.to_list table_schema
          let resolve colnm =
            if colnm = "__id__" then `Int64
            else
              try List.assoc colnm schema_assoc
              with Not_found -> invalid_arg (sprintf "DNAnexus.GTable: %s has no column \"%s\"" dxid colnm)
          Array.map resolve cols
    (* make list of floating-point columns *)
    let n = Array.length row_types
    let fpcols = (0 --^ n) // (fun i -> match row_types.(i) with `Float | `Double -> true | _ -> false) |> List.of_enum
    (* given row, check those columns to see if any were decoded from JSON as
       ints; if so, cast them to floats *)
    fun row ->
      if Array.length row <> n then
        failwith (sprintf "DNAnexus.GTable: expected /%s/get to return %d columns, but got at least one row with %d columns" dxid n (Array.length row))
      fpcols |> List.iter
        fun i ->
          match row.(i) with
            | `Int x -> Array.unsafe_set row i (`Float (float x)) (* TODO verify no loss of precision *)
            | _ -> ()
      row

  let create ~pagination ~parallelism ?query ?columns ?starting ?limit ~table_rows ~table_schema dxid =
    let fixup = make_row_fixerupper dxid table_schema columns
    let columns_json = Option.map (fun cols -> JSON.of_array (Array.map (fun c -> `String c) cols)) columns
    let tp = ThreadPool.make ~maxthreads:parallelism ()

    (* TODO: handling of 'limit' is not optimal. If limit < pagination then we do the 
       right thing. Otherwise our requests are still in full-size pages. The worst case
       is limit=pagination+1 -- we'd retrieve twice as much data as necessary *)

    (* queue of 'starting' values with which to issue requests *)
    let starting_q = Queue.create ()
    (* queue of ThreadPool iou's for in-progress requests *)
    let iou_q = Queue.create ()

    let init_once =
      (* launch the initial /gtable-xxxx/get request(s) *)
      let init () =
        if query = None then
          (* we'll be paging through the table in its natural order, maxing out parallelism *)

          let starting = Option.default 0 starting
          if starting < table_rows then
            let limit = Option.default table_rows limit
            let endrow = min table_rows (starting+limit)
            (* load starting_q with the starting rowid of each request needed to page through
               the entire table (with 'pagination' rows per page)

               TODO: it would be nice to make this lazy *)
            foreach
              Enum.seq starting ((+) pagination) (fun rowid -> rowid < endrow)
              (flip Queue.add) starting_q

            (* fire the first 'parallelism' requests *)
            for i = 1 to parallelism do
              if not (Queue.is_empty starting_q) then
                Queue.add
                  ThreadPool.launch tp get_thread (dxid,(min limit pagination),Some (Queue.take starting_q),None,columns_json)
                  iou_q

            assert (not (Queue.is_empty iou_q))
        else
          (* caller should not specify 'starting' with query *)
          assert (starting = None)

          (* we'll be paging through results of a query, using the 'starting' value returned
             in the each request to issue the next request -- this limits parallelism to one
             background thread *)
          Queue.add
            ThreadPool.launch tp get_thread (dxid,(min (Option.default max_int limit) pagination),None,query,columns_json)
            iou_q

          (* starting_q is empty at this point; we won't know the next 'starting' value
             until we get the results of the API call we just fired. *)
      lazy (init ())
    
    (* buffer of rows available from the most recent results retrieved from the thread pool *)
    let available_rows = ref []
    let rows_returned = ref 0

    (* 'next' function for enum *)
    let next () = 
      Lazy.force init_once (* ensure initialization *)
      match !available_rows with
        | _ when !rows_returned >= (Option.default max_int limit) -> raise Enum.No_more_elements
        (* we have some available_rows, so just pop the first one *)
        | row :: rest -> available_rows := rest; incr rows_returned; fixup row
        (* available_rows is exhausted, but we still have pending threads *)
        | [] when not (Queue.is_empty iou_q) ->
            match ThreadPool.await_result ~rm:true tp (Queue.take iou_q) with
              | `Exn exn -> raise exn
              (* no rows from API server and no 'starting': this occurs exactly iff we've
                 been running a query and there are no further results *)
              | `Ans ([],None) when query <> None -> raise Enum.No_more_elements
              (* under all other circumstances, we should get nonzero rows from the API server *)
              | `Ans ([],_) -> failwith "DNAnexus.GTable.get_rows: unexpected empty result from API server"
              | `Ans (rows,maybe_starting) ->
                  (* the 'starting' returned by the API server is only interesting to us if
                     we're running a query, in which case we need to queue it up *)
                  if query <> None then
                    assert (Queue.length starting_q = 0)
                    maybe_starting |> Option.may ((flip Queue.add) starting_q)

                  (* fire the next /gtable-xxxx/get request *)
                  if not (Queue.is_empty starting_q) then
                    Queue.add
                      ThreadPool.launch tp get_thread (dxid,pagination,Some (Queue.take starting_q),query,columns_json)
                      iou_q

                  available_rows := List.tl rows
                  incr rows_returned
                  fixup (List.hd rows)
        (* no available_rows and no pending results: we're done*)
        | [] -> raise Enum.No_more_elements

    Enum.from next
