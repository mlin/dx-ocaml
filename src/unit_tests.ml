open OUnit
open Batteries
open Printf
open JSON.Operators
module DX = DNAnexus

Printexc.record_backtrace true
DX.reconfigure {(DX.config()) with DX.project_context_id = None}
let master_teardown () =
  if ((DX.config()).DX.project_context_id <> None) then
    try
      ignore (DXAPI.project_destroy (DX.project_id()) (JSON.of_assoc ["terminateJobs", `Bool true]))
      eprintf "Destroyed test project %s\n" (DX.project_id())
    with
      | exn ->
        eprintf "Exception trying to tear down test project %s:\n" (DX.project_id())
        eprintf "%s\n" (Printexc.to_string exn)
        Printexc.print_backtrace stderr
(*
dx find projects --name "Test project for OCaml bindings" --level ADMINISTER --brief | xargs -n 1 -iXXX dx api XXX destroy {}
*)

let skip_slow = try Sys.getenv "DX_SKIP_SLOW_TESTS" = "1" with Not_found -> false
let skip_msg = "(skipped, since DX_SKIP_SLOW_TESTS=1)"

module Basic = struct
  let make_project () =
    assert ((DX.config()).DX.project_context_id = None)

    let inp = JSON.of_assoc [
      "name", `String "Test project for OCaml bindings";
      "tags", JSON.of_list [`String "test"]
    ]

    let rslt = DXAPI.project_new inp
    
    let id = rslt$"id" |> JSON.string
    DX.reconfigure {(DX.config()) with DX.project_context_id = Some id}

    printf "created test project: %s\n" (DX.project_id()); flush stdout

  let tests = ["make a project" >:: make_project]

module ThreadPool = struct
  let basic () =
    let th i = Thread.delay 0.25; i
    let tp = ThreadPool.make ()
    for i = 1 to 10 do
      ignore (ThreadPool.launch tp th i)
    ThreadPool.drain tp
    let rec collect_results sofar =
      match ThreadPool.any_result ~rm:true tp with
        | Some rslt -> collect_results (rslt :: sofar)
        | None -> sofar
    let results = collect_results []
    assert (List.length results = 10)

  let tests = ["basic" >:: basic]

module Record = struct
  let make_record () =
    let opts =
      JSON.of_assoc
        ["name", `String "foo";
         "tags", JSON.of_list [`String "foo"]]
    let r = DX.Record.make_new opts
    DX.Record.set_details r (JSON.of_assoc ["foo", `String "bar"])
    DX.Record.add_types r ["foo"]
    DX.Record.set_properties r ["foo", Some "bar"; "bas", Some "baz"]
    DX.Record.close ~wait:true r
    let desc = DX.Record.describe r
    printf "created test record: %s\n" (JSON.to_string desc); flush stdout

  (* TODO: test error responses *)

  let tests = ["make a record" >:: make_record]

let lorem = "Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum."

module File = struct
  let loremfile () =
    File.with_temporary_out ~prefix:"TestDXFileUpload"
      fun outfile fn ->
        IO.nwrite outfile lorem
        fn

  let bigrandomfile size =
    let fn = Filename.temp_file "TestDXBigRandomFile" ""
    match Sys.command (sprintf "head -c %d /dev/urandom > %s" size fn) with
      | 0 -> fn
      | _ -> failwith "making big random file"

  let test_file ?part_size ?parallelism fn =
    let fid =
      DX.File.with_new ~wait:true JSON.empty
        fun f ->
          DX.File.reconfigure ?part_size ?parallelism f
          DX.File.upload f fn
          DX.File.id f
    let f = DX.File.bind (None,fid)
    DX.File.reconfigure ?part_size ?parallelism f
    let tmpfn = Filename.temp_file "TestDXFileDownload" ""
    () |> finally (fun () -> try Sys.remove tmpfn with _ -> ())
      fun () ->
        DX.File.download f tmpfn
        if Sys.command (sprintf "cmp -s %s %s" fn tmpfn) <> 0 then
          failwith "files differ!"

  let tiny () =
    let fn = loremfile()      
    finally (fun () -> try Sys.remove fn with _ -> ()) test_file fn

  let tiny_stream () =
    let dxfile =
      DX.File.with_new ~wait:true JSON.empty
        fun dxfile ->
          DX.File.with_output dxfile (fun output -> IO.nwrite output lorem)
          dxfile
    let ans = DX.File.with_input ~pos:28 dxfile IO.read_all
    assert_equal ~printer:(fun x -> x) (String.lchop ~n:28 lorem) ans

  let multipart () =
    skip_if skip_slow skip_msg
    let fn = bigrandomfile (64 * 1048576)
    finally (fun () -> try Sys.remove fn with _ -> ()) (fun fn -> test_file ~part_size:(5*1048576) fn) fn

  let multipart_stream () =
    skip_if skip_slow skip_msg
    let sz = 64 * 1048576
    let fn = bigrandomfile sz
    () |> finally (fun () -> try Sys.remove fn with _ -> ())
      fun _ ->
        let fnmd5 = Digest.file fn
        let dxfile =
          DX.File.with_new ~wait:true JSON.empty
            fun f ->
              DX.File.reconfigure ~part_size:(5*1048576) f
              DX.File.upload f fn
              f
        let part1 = DX.File.with_input dxfile ((flip IO.really_nread) (sz/2))
        let part2 = DX.File.with_input ~pos:(sz/2) dxfile IO.read_all
        assert_equal ~printer:Digest.to_hex fnmd5 (Digest.string (part1 ^ part2))

  let tests = [
    "make a tiny file using upload/download" >:: tiny;
    "make a tiny file using input/output streams" >:: tiny_stream;
    "make a 64MB file using upload/download" >:: multipart;
    "make a 64MB file using input/output streams" >:: multipart_stream
  ]

module GTable = struct
  (* helper functions for comparing GTable rows, with some tolerance for float comparisons *)
  let rows_equal row1 row2 =
    if Array.length row1 <> Array.length row2 then false
    else
      Array.for_all2
        fun a b ->
          match (a,b) with
            | (`Int x,`Float y) -> abs_float (float x -. y) < 1e-6
            | (`Float x,`Int y) -> abs_float (x -. float y) < 1e-6
            | (`Float x,`Float y) -> abs_float (x -. y) < 1e-6
            | _ -> a = b
        row1
        row2
  let string_of_row row = JSON.to_string (JSON.of_array (Array.map (fun x -> (x :> JSON.t)) row))
  let assert_rows_equal row1 row2 =
    if not (rows_equal row1 row2) then
      failwith (sprintf "expected %s but got %s" (string_of_row row1) (string_of_row row2))

  let tiny () =
    let tiny_rows = [|
      [| `Bool false; `Int 0; `Float 0.0; `String "" |];
      [| `Bool false; `Int 1; `Float 3.1415926; `String "foo" |];
      [| `Bool true; `Int (-1); `Float 2.718; `String "bar" |];
      [| `Bool true; `Int 9007199254740992; `Float 6e23; `String lorem |];
      [| `Bool true; `Int (-9007199254740992); `Float 42.0; `String lorem |]
    |]
    let opts =
      JSON.of_assoc
        ["name", `String "tiny gtable";
         "tags", JSON.of_list [`String "foo"];
         "columns", DNAnexus.GTable.json_of_columns [|
            "boolean_col", `Bool;
            "int64_col", `Int64;
            "double_col", `Double;
            "string_col", `String
         |]
        ] 
    let dxid =
      DX.GTable.with_new ~wait:true opts
        (flip DX.GTable.with_flush_rows)
          fun gt ->
            for i = 0 to 4 do
              DX.GTable.add_row gt tiny_rows.(i)
            DX.GTable.id gt
    let gt = DX.GTable.bind (None,dxid)
    let en = DX.GTable.iterate_rows gt
    for i = 0 to 4 do
      let exp = Array.concat [[|`Int i|]; tiny_rows.(i)]
      assert_rows_equal exp (Option.get (Enum.get en))
    assert (Enum.is_empty en)

  let number_typing () =
    let numeric_rows = [|
      [| `Int 0; `Float 0.0 |];
      [| `Int 0; `Int 0 |];
      [| `Int 0; `Int 314159 |];
      [| `Float 0.0; `Float 0.0 |];
      [| `Float 314159.0; `Float 0.0 |]
    |]
    let opts =
      JSON.of_assoc
        ["name", `String "numeric gtable";
         "tags", JSON.of_list [`String "foo"];
         "columns", DNAnexus.GTable.json_of_columns [|
            "int64_col", `Int64;
            "double_col", `Double
         |]
        ] 
    let dxid =
      DX.GTable.with_new ~wait:true opts
        (flip DX.GTable.with_flush_rows)
          fun gt ->
            for i = 0 to 4 do
              DX.GTable.add_row gt numeric_rows.(i)
            DX.GTable.id gt
    let gt = DX.GTable.bind (None,dxid)
    let en = DX.GTable.iterate_rows gt
    for i = 0 to 4 do
      match Enum.get en with
        | Some [| _; `Int _ ; `Float _ |] -> ()
        | Some [| _; `Int _ ; `Int _ |] -> failwith (sprintf "got int, expected float at [%d,2]" i)
        | Some [| _; `Float _ ; `Float _ |] -> failwith (sprintf "got float, expected int at [%d,1]" i)
        | None -> failwith (sprintf "missing row %d" i)
        | _ -> failwith (sprintf "something really unexpected in row %d" i)
    assert (Enum.is_empty en)
    let en2 = DX.GTable.iterate_rows ~columns:[|"__id__"; "double_col"|] gt
    for i = 0 to 4 do
      match Enum.get en2 with
        | Some [| _; `Float _ |] -> ()
        | Some [| _; `Int _ |] -> failwith (sprintf "got int, expected float at [%d,1]" i)
        | None -> failwith (sprintf "missing row %d" i)
        | _ -> failwith (sprintf "something really unexpected in row %d" i)
    assert (Enum.is_empty en2)

  (* helper functions for making random GTable data *)
  let col_ty i = match i mod 4 with
    | 0 -> `Bool
    | 1 -> `Int64
    | 2 -> `Double
    | 3 -> `String
    | _ -> assert false
  let random_datum i = match i mod 4 with
    | 0 -> `Bool (Random.bool ())
    | 1 -> `Int (Random.int 100)
    | 2 -> `Float (Random.float 1.0)
    | 3 ->
        let prefix = String.left lorem (1 + Random.int (String.length lorem - 1))
        `String (String.right prefix (Random.int (String.length prefix)))
    | _ -> assert false
  let random_row ncol = Array.init ncol random_datum

  let make_test_table nrow ncol =
    let columns = Array.concat [
      [| "ord", `String |];
      Array.init ncol (fun i -> (sprintf "col%d" i), (col_ty i))
    ]
    let opts =
      JSON.of_assoc
        ["name", `String (sprintf "%dx%d gtable" nrow ncol);
         "tags", JSON.of_list [`String "foo"];
         "columns", DNAnexus.GTable.json_of_columns columns;
         "indices", DNAnexus.GTable.json_of_indices [
            "ord_index", `Lexicographic ["ord", `Asc, None]
          ]
        ]
    let data =
      Array.init nrow
        fun row ->
          Array.concat [
            [|`String (sprintf "%09d" row)|];
            random_row ncol
          ]
    DX.GTable.with_new ~wait:true opts
      (flip DX.GTable.with_flush_rows)
        fun gt ->
          DX.GTable.reconfigure gt ~pagination:1000
          for i = 0 to nrow-1 do
            DX.GTable.add_row gt data.(i)
          data, DX.GTable.id gt

  let small_table =
    lazy
      let data, dxid = make_test_table 12345 10
      let gt = DX.GTable.bind (None,dxid)
      DX.GTable.reconfigure gt ~pagination:1000
      data, gt

  let small () =
    skip_if skip_slow skip_msg
    let data, gt = Lazy.force small_table
    let rows = DX.GTable.iterate_rows gt |> Array.of_enum
    assert_equal ~printer:string_of_int 12345 (Array.length rows)
    for i = 0 to 12344 do
      let row = Array.sub rows.(i) 1 11 (* skip rowid column returned by the server *)
      assert_rows_equal data.(i) row

  let small_query () =
    skip_if skip_slow skip_msg
    let data, gt = Lazy.force small_table
    let p = `Lexicographic ["ord", `Gte, (sprintf "%09d" 1234); "ord", `Lte, (sprintf "%09d" 9999)]
    let rows = DX.GTable.query_rows gt "ord_index" p |> Array.of_enum
    assert_equal ~printer:string_of_int 8766 (Array.length rows)
    rows |> Array.iteri
      fun ofs row ->
        let row = Array.sub row 1 11
        assert_rows_equal data.(1234+ofs) row

  (* TODO: test typecheck setting to add_row *)

  let tests = [
    "make a tiny table and read it back" >:: tiny;
    "resolve ambiguous number typing" >:: number_typing;
    "make a small table and read it back" >:: small;
    "query the small table" >:: small_query;
  ]


let all_tests = ("DNAnexus bindings tests" >::: [
    "basic" >::: Basic.tests;
    "ThreadPool" >::: ThreadPool.tests;
    "records" >::: Record.tests;
    "files" >::: File.tests;
    "gtables" >::: GTable.tests
])

at_exit master_teardown
run_test_tt ~verbose:true all_tests
