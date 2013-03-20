(* Helper functions for File bindings *)

open Batteries
open JSON.Operators
open Printf

(* TODO: more-granular streaming file I/O to reduce memory usage *)

(* Check all currently-available results from the thread pool; discard normal results
   and re-raise any exception result *)
let rec check_threads tp =
  match ThreadPool.any_result ~rm:true tp with
    | None -> ()
    | Some (_, `Ans _) -> check_threads tp
    | Some (_, `Exn exn) -> raise exn

(* thread to upload an individual part *)
let upload_part_thread (file_id,part_idx,buf) =
  let upload_ans = 
    DXAPI.file_upload file_id
      JSON.of_assoc ["index", `Int part_idx]
  let upload_url = JSON.string (upload_ans$"url")
  let headers = ["content-type", "application/octet-stream"]
  () |> DX.generic_retry ~desc:(sprintf "upload of part %d for %s" part_idx file_id)
    fun () ->
      match HTTP.(perform ~headers (POST buf) upload_url IO.stdnull) with
        | x when x >= 200 && x <= 299 -> ()
        | x -> failwith (sprintf "HTTP code %d while uploading %s part %d" x file_id part_idx)

let create_output ~part_size ~parallelism dx_file_id =
  if part_size < 5*1048576 then invalid_arg "DNAnexus.File part_size must be at least 5MB"
  if parallelism < 1 then invalid_arg "DNAnexus.File parallelism"

  let tp = ThreadPool.make ~maxthreads:parallelism ()

  (* Smallest permissible intermediate buffer that can be flushed (dictated by API's
     minimum file part size) *)
  let min_flush = 5 * 1048576

  (* output state *)
  let closed = ref false
  let part_idx = ref 1
  let buf = Buffer.create 1024

  let send_part () =    
    let part = Buffer.contents buf
    Buffer.reset buf
    (* note: ThreadPool.launch blocks if there are already maxthreads running *)
    ignore (ThreadPool.launch tp upload_part_thread (dx_file_id,!part_idx,part))
    incr part_idx
    check_threads tp

  (* output implementation *)
  let write chr =
    if !closed then raise IO.Output_closed
    Buffer.add_char buf chr
    if Buffer.length buf >= part_size then send_part ()
  let output data ofs len =
    if !closed then raise IO.Output_closed
    Buffer.add_substring buf data ofs len
    if Buffer.length buf >= part_size then send_part ()
    len
  let flush () =
    if !closed then raise IO.Output_closed
    if Buffer.length buf >= min_flush then send_part ()
    ThreadPool.drain tp
    check_threads tp
  let close () =
    closed := true
    if Buffer.length buf > 0 then send_part ()
    ThreadPool.drain tp
    check_threads tp

  let check_closure _ =
    if Buffer.length buf > 0 then
      eprintf "[WARN] DNAnexus-ocaml: buffered File data is being garbage-collected without having been uploaded!\n"
      IO.flush stderr

  let ans = IO.create_out ~write ~output ~flush ~close
  Gc.finalise check_closure ans
  ans

(* thread to HTTP GET a range of the download URL *)
let download_part_thread (file_id,url,ofs,len) =
  () |> DX.generic_retry ~desc:(sprintf "part download for %s" file_id)
    fun () ->
      let buf = IO.output_string ()
      match HTTP.(perform ~headers:["range", (sprintf "bytes=%d-%d" ofs (ofs+len-1))] GET url buf) with
        | x when x >= 200 && x <= 299 ->
          let rsp = IO.close_out buf
          if String.length rsp <> len then
            failwith (sprintf "Truncated response downloading %s bytes [%d,%d]" file_id ofs (ofs+len-1))
          rsp
        | x -> failwith (sprintf "HTTP code %d while downloading %s bytes [%d,%d]" x file_id ofs (ofs+len-1))

type input_state = New | Open | Closed
let create_input ?(pos=0) ~part_size ~parallelism ~url ~size dx_file_id =
  if part_size < 1 then invalid_arg "DNAnexus.File.download part_size"
  if parallelism < 1 then invalid_arg "DNAnexus.File.download parallelism"

  if pos >= size then invalid_arg "DNAnexus.File.open_in: requested pos is past EOF"

  let tp = ThreadPool.make ~maxthreads:parallelism ()

  (* input state *)
  let state = ref New
  let next_part = ref 0
  let iou_q = Queue.create ()
  let buf = ref ""
  let bufpos = ref 0

  let launch_next_download () =
    let ofs = pos + !next_part * part_size
    if ofs < size then
      let len = min part_size (size-ofs)
      Queue.add (ThreadPool.launch tp download_part_thread (dx_file_id,url,ofs,len)) iou_q
      incr next_part
  let rec ensure_availability () =
    match !state with
      | Open -> ()
      | Closed -> raise IO.Input_closed
      | New ->
        (* first read attempt -- launch the initial parallel download threads
          
          Future optimization: make the first reads smaller, to reduce latency
          of the first read operation (1MB, 4MB, 16MB, 64MB...) *)
        for i = 1 to parallelism do
          launch_next_download ()
        state := Open
    let av = String.length !buf - !bufpos
    if av > 0 then av
    else
      if Queue.is_empty iou_q then raise IO.No_more_input
      (* wait for the next pending part download *)
      match ThreadPool.await_result ~rm:true tp (Queue.take iou_q) with
        | `Exn exn -> raise exn
        | `Ans nextbuf ->
            (* replace the now-finished download with the next part *)
            launch_next_download ()
            buf := nextbuf
            bufpos := 0
            ensure_availability ()

  (* input implementation *)
  let read () =
    ignore (ensure_availability ())
    let c = !buf.[!bufpos]
    incr bufpos
    c

  let input data ofs len =
    let av = ensure_availability ()
    let n = min av len
    String.blit !buf !bufpos data ofs n
    bufpos := !bufpos + n
    n

  let close () =
    if !state = Closed then raise IO.Input_closed
    state := Closed
    buf := ""
    ThreadPool.drain tp
    while ThreadPool.any_result tp <> None do
      ignore (ThreadPool.any_result ~rm:true tp)

  IO.create_in ~read ~input ~close

