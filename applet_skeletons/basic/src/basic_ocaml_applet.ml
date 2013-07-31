(*
Skeleton of a basic dx-ocaml applet

Basic execution pattern: Your app will run on a single machine from
beginning to end.

References:
- DNAnexus (dx-ocaml) module documentation:
  http://mlin.github.io/dx-ocaml/DNAnexus.html
- JSON (yajl-ocaml) module documentation:
  http://mlin.github.io/yajl-ocaml/extra/JSON.html
- Execution Environment Reference:
  https://wiki.dnanexus.com/Execution-Environment-Reference
- API specification:
  https://wiki.dnanexus.com/API-Specification-v1.0.0/Introduction
*)
open JSON.Operators
open DNAnexus
open Printf

(* Applet logic: download one of the files, upload a copy, and output the copy *)
let process file1 file2 output_2nd =
  let the_file = if output_2nd then file2 else file1 in
  let name = (JSON.string (File.describe the_file $ "name")) in
  begin
    (* Job logging examples: print file's name to stdout, and its id to stderr *)
    printf "The file name is %s\n" name;
    eprintf "The file id is %s\n" (File.id the_file);

    (* Download the file to the local scratch filesystem *)
    File.download file1 "the_file";

    (* In a real applet, we might now perform some analysis on the_file. We could also
       have streamed the file contents using File.open_input *)

    (* Upload a copy of the file to the job workspace, giving it an appropriate name *)
    let upload_options = JSON.of_assoc [
      "name", `String (sprintf "%s from basic_ocaml_applet" name)
    ] in
    File.upload_new ~options:upload_options "the_file"
  end

(* Entry point: bind JSON inputs, call main, and produce JSON outputs *)
let entry input =
  let file1 = File.bind_link (input$"file1") in       (* create a binding for input file 1 *)
  let file2 = File.bind_link (input$"file2") in       (* and 2 *)
  let output_2nd = JSON.bool (input$"output_2nd") in  (* get the output_2nd flag as a bool *)

  let output_file = process file1 file2 output_2nd in (* call main *)

    (* produce output JSON *)
    JSON.of_assoc [
      "output_file", make_link (File.id output_file)
    ]
;;

(* Call DNAnexus.job_main *)
Printexc.record_backtrace true;;
job_main entry

