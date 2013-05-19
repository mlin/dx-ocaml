(*
HTTP client module -- thin wrapper for ocurl

Info:
  http://repo.or.cz/w/ocurl.git/blob/HEAD:/curl.mli
  https://gist.github.com/1432555
  http://curl.haxx.se/libcurl/c/post-callback.html
*)
open Batteries
open Printf

let ensure_init =
  let p =
    lazy
      let _ =
        Ssl.init ~thread_safe:true () (* performs incantations to ensure thread-safety of OpenSSL *)
        Curl.global_init Curl.CURLINIT_GLOBALALL
      ()
  fun () -> Lazy.force p

(* Simple pool of curl handles (reusing them permits reuse of kept-alive
connections). There's no limit to how many connections can be checked out; of
handles that are checked back in, at most n will be held in the pool for
future checkouts. When a handle is checked out it must either be checked back
in or Curl.cleanup must be called on it. *)
let checkout_conn, checkin_conn =
  let n = 16
  let connpool = ref []

  (* make the pool pid-specific, in case the process is forked *)
  let lastpid = ref (Unix.getpid ())
  (* also protect the pool with a mutex, in case the program is multithreaded *)
  let lock = Mutex.create ()
  
  let checkout_conn =
    BatteriesThread.Mutex.synchronize ~lock
      fun () ->
        let pid = Unix.getpid ()
        if pid <> !lastpid then
          List.iter Curl.cleanup !connpool
          connpool := []
          lastpid := pid
        match !connpool with
          | fst :: rest -> connpool := rest; fst
          | [] -> Curl.init ()
  let checkin_conn =
    BatteriesThread.Mutex.synchronize ~lock
      fun c ->
        if (List.length !connpool) < n then
          Curl.reset c
          connpool := c :: !connpool
        else
          Curl.cleanup c

  checkout_conn, checkin_conn

(* Supported HTTP request types *)
type request_type = GET | POST of string | POST_stream of IO.input

(* Synchronously perform an HTTP request.

HTTP response bodies are streamed to an [IO.output]. For a small expected
response body, it's typical to use [IO.output_string ()] to buffer it in-
memory and then retrieve it as a string using [IO.close_out]. The [IO.output]
is {e not} automatically closed when the request is finished. Any exceptions
raised attempting to write to the [IO.output] will abort the request.

HTTP request bodies can be streamed from an [IO.input] by specifying an
appropriate [request_type]. (If you have the entire request body in-memory as
a string, there is no need to worry about this, as you can provide it that way
using the simpler request types.) To stream a request body whose length is
known in advance, provide the appropriate [content-length] header to
[perform]. If no such header is provided, [perform] will insert a [transfer-
encoding: chunked] header and begin streaming the data until no more data can
be read from the input. The [IO.input] is {e not} automatically closed when
the request is finished. Exceptions raised while attempting to read from the
[IO.input] currently cannot be handled properly due to limitations of upstream
libraries, and will cause the program to abruptly exit. *)
let perform ?(headers=[]) ty url response_body =
  let headers = ref (List.map (fun (k,v) -> String.lowercase (String.trim k), String.trim v) headers)

  ensure_init()
  let c = checkout_conn()
  try
    let streaming_exn = ref None

    Curl.set_timeout c 1200
    (*
    Curl.set_sslverifypeer c false
    Curl.set_sslverifyhost c Curl.SSLVERIFYHOST_EXISTENCE
    *)
    Curl.set_tcpnodelay c true
    Curl.set_verbose c false
    Curl.set_url c url

    match ty with
      | GET -> Curl.set_post c false
      | POST data ->
          Curl.set_post c true
          Curl.set_postfields c data
          Curl.set_postfieldsize c (String.length data)
      | POST_stream request_body ->
          Curl.set_post c true
          try
            Curl.set_postfieldsize c (int_of_string (List.assoc "content-length" !headers))
          with
            | Not_found ->
                if not (List.mem_assoc "transfer-encoding" !headers) then
                  headers := ("transfer-encoding", "chunked") :: !headers
          Curl.set_readfunction c
            fun n ->
              try
                IO.really_nread request_body n
              with
                | exn ->
                    if !streaming_exn = None then streaming_exn := Some exn
                    (*
                    FIXME: we are now supposed to return
                    CURL_READFUNC_ABORT (0x10000000), but ocurl does not
                    provide this value, and the stub in curl-helper.c
                    would clobber such a return value anyway!
                    *)
                    eprintf "[PANIC] DNAnexus-ocaml: the following exception was raised while streaming an HTTP request body; it cannot be handled gracefully due to limitations in upstream libraries.\n"
                    eprintf "%s\n" (Printexc.to_string exn)
                    if Printexc.backtrace_status () then Printexc.print_backtrace stderr
                    flush stderr
                    exit 2

    if !headers <> [] then Curl.set_httpheader c (List.map (fun (k,v) -> sprintf "%s: %s" k v) !headers)

    Curl.set_writefunction c
      fun data ->
        try
          IO.really_output response_body data 0 (String.length data)
        with
          | exn ->
            if !streaming_exn = None then streaming_exn := Some exn
            (* libcurl docs: "Return the number of bytes actually taken care of.
               If that amount differs from the amount passed to your function,
               it'll signal an error to the library."
               ...
               "This function may be called with zero bytes data if the
               transferred file is empty." *)
            1 + String.length data
    Curl.perform c
    match !streaming_exn with None -> () | Some exn -> raise exn
    let ans = Curl.get_responsecode c (* TODO get headers, etc. *)
    checkin_conn c
    ans
  with exn -> Curl.cleanup c; raise exn

