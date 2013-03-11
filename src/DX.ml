(*
Internal implementation of the core DNAnexus module
*)

open Batteries
open JSON.Operators
open Printf

(* TODO: load configuration from ~/.dnanexus_config/environment.json
at lower precedence than environment variables *)

type configuration = {
  apiserver_host: string;
  apiserver_port: int;
  apiserver_protocol : string;
  auth_token: string;
  auth_token_type: string;
  project_context_id: string option;

  job : job_configuration option;

  retry_times: int;
  retry_initial_delay: float;
  retry_backoff_factor: float;
  retry_logger: (string -> exn option -> unit) option
}
and job_configuration = {
  job_id : string;
  workspace_id : string
}

let default_retry_logger msg maybe_exn =
  match maybe_exn with
    | Some (Curl.CurlException (_,curlcode,curlmsg)) -> eprintf "%s (CurlException (%d,%s))...\n" msg curlcode curlmsg
    | Some exn -> eprintf "%s (%s)...\n" msg (Printexc.to_string exn)
    | None -> eprintf "%s\n" msg
  flush stderr

(* load configuration from environment *)
let env_configuration () =
  let getenv_nonempty k =
    let s = Sys.getenv k
    let s' = String.trim s
    if String.length s' = 0 then raise Not_found
    s'
  let apiserver_host =
    try
      getenv_nonempty "DX_APISERVER_HOST"
    with Not_found -> failwith "Required environment variables not found. For interactive use, try 'source ~/.dnanexus_config/environment' and run again. (DX_APISERVER_HOST is not set)"
  let auth_token, auth_token_type =
    try
      let security_context = JSON.from_string (getenv_nonempty "DX_SECURITY_CONTEXT")
      (JSON.string (security_context$"auth_token")), (JSON.string (security_context$"auth_token_type"))
    with _ -> failwith "DX_SECURITY_CONTEXT environment variable is not valid"
  let jobcfg =
    try
      Some {
        job_id = getenv_nonempty "DX_JOB_ID";
        workspace_id = getenv_nonempty "DX_WORKSPACE_ID"
      }
    with Not_found -> None
  {
    apiserver_host = apiserver_host;
    apiserver_port = (try int_of_string (getenv_nonempty "DX_APISERVER_PORT") with Not_found -> 8124 | Failure _ -> failwith "invalid setting of DX_APISERVER_PORT");
    apiserver_protocol = (try getenv_nonempty "DX_APISERVER_PROTOCOL" with Not_found -> "http");
    project_context_id = (try Some (getenv_nonempty "DX_PROJECT_CONTEXT_ID") with Not_found -> None);
    auth_token = auth_token;
    auth_token_type = auth_token_type;

    job = jobcfg;

    retry_times = 5;
    retry_initial_delay = 1.0;
    retry_backoff_factor = 2.0;
    retry_logger = Some default_retry_logger
  }

let the_configuration = ref None
let config () =
    match !the_configuration with
      | Some cfg -> cfg
      | None ->
        let cfg = env_configuration ()
        the_configuration := Some cfg
        cfg
let reconfigure cfg = the_configuration := Some cfg

let config_json ?(security_context=false) () =
  let cfg = config()
  let sec_ctx =
    if security_context then
      Some (JSON.of_assoc [
        "auth_token_type", `String cfg.auth_token_type;
        "auth_token", `String cfg.auth_token
      ])
    else None

  let stanzas = [
    "DX_APISERVER_HOST", Some (`String cfg.apiserver_host);
    "DX_APISERVER_PORT", Some (`Int cfg.apiserver_port);
    "DX_APISERVER_PROTOCOL", Some (`String cfg.apiserver_protocol);
    "DX_PROJECT_CONTEXT_ID", Option.map (fun id -> `String id) cfg.project_context_id;
    "DX_SECURITY_CONTEXT", sec_ctx;
    "DX_JOB_ID", Option.map (fun {job_id} -> `String job_id) cfg.job;
    "DX_WORKSPACE_ID", Option.map (fun {workspace_id} -> `String workspace_id) cfg.job
  ]

  List.fold_left (fun json (k,vo) -> Option.map_default (fun v -> json $+ (k,v)) json vo) JSON.empty stanzas

let project_id () =
  match config() with
    | { project_context_id = None } -> failwith "DX_PROJECT_CONTEXT_ID environment is not configured"
    | { project_context_id = Some proj } -> proj

let with_project_id json = json$+("project",`String (project_id()))

exception Escape_retry of exn

let rec generic_retry ?(i=0) ?(desc="") f x =
  let cfg = config()
  try
    let y = f x
    match cfg.retry_logger with
      | Some log when i > 0 ->
          try
            log
              sprintf "Successful%s after retrying %d times"
                if desc <> "" then " " ^ desc else ""
                i
              None
          with
            | exn -> raise (Escape_retry exn)
      | _ -> ()
    y
  with
    | Escape_retry exn -> raise exn
    | exn when i >= 0 && i < cfg.retry_times ->
        let d = cfg.retry_initial_delay *. (cfg.retry_backoff_factor ** (float i))
        match cfg.retry_logger with
          | Some log ->
              log
                sprintf "Retrying%s after %.1fs"
                  if desc <> "" then " " ^ desc else ""
                  d
                Some exn
          | None -> ()
        Thread.delay d
        generic_retry ~i:(i+1) ~desc f x

exception APIError of string*string*JSON.t

(* TODO: retry only certain routes *)

let api_call_raw_body ?(retry=true) path input =
  let cfg = config()
  let url =
    if path = [] then invalid_arg "DNAnexus.api_call_prepare: empty route"
    let base = sprintf "%s://%s:%d" cfg.apiserver_protocol cfg.apiserver_host cfg.apiserver_port
    String.concat "/" (base :: path)
  let headers = ["content-type", "application/json"; "authorization", (sprintf "%s %s" cfg.auth_token_type cfg.auth_token)]
  () |> generic_retry ~desc:("/" ^ (String.concat "/" path)) ~i:(if retry then 0 else (-1))
    fun () ->
      let buf = IO.output_string ()
      let code = HTTP.(perform ~headers (POST input) url buf)
      let rsp = IO.close_out buf
      if code >= 200 && code < 300 then JSON.from_string rsp
      else
        try
          match code with
            | 400 | 401 | 404 | 422 | 500 ->
              let response = JSON.from_string rsp
              let err = response$"error"
              let details = if err$?"details" then err$"details" else `Null
              let api_error = APIError (JSON.string (err$"type"), JSON.string (err$"message"), details)
              if code <> 500 then
                raise (Escape_retry api_error)
              else
                raise api_error
            | _ -> failwith ""
        with
          | (APIError _) as err -> raise err
          | (Escape_retry (APIError _)) as err -> raise err
          | _ -> failwith (sprintf "Unrecognized response from DNAnexus API server with HTTP code %d: %s" code rsp)

let api_call ?retry path input =
  api_call_raw_body ?retry path (JSON.to_string input)

let original_cwd = Sys.getcwd () (* in case user's code does chdir *)

let job_error ty msg =
  let json = JSON.of_assoc [ "error", JSON.of_assoc [
    "type", `String ty;
    "message", `String msg
  ]]
  JSON.to_file (Filename.concat original_cwd "job_error.json") json
  exit 2

exception AppError of string
exception AppInternalError of string

let job_main app_logic =
  try
    let input = JSON.from_file (Filename.concat original_cwd "job_input.json")
    let output = app_logic input
    JSON.to_file (Filename.concat original_cwd "job_output.json") output
  with
    | AppError msg -> job_error "AppError" msg
    | AppInternalError msg -> job_error "AppInternalError" msg
    (* TODO: special pretty-printing handlers for JSON.No_key *)
    | exn ->
      let shortmsg = Printexc.to_string exn
      let msg =
        if Printexc.backtrace_status () then shortmsg ^ "\n" ^ (Printexc.get_backtrace ())
        else shortmsg
      eprintf "%s\n" msg
      job_error "AppInternalError" shortmsg

let is_job () = match (config()).job with
  | Some _ -> true
  | None -> false

let job_config () = match (config()).job with
  | Some cfg -> cfg
  | None -> failwith "This program is meant to execute as an app/applet on the DNAnexus platform. (DX_JOB_ID and/or DX_WORKSPACE_ID are not set)"

let job_id () = (job_config()).job_id

let workspace_id () = match config() with
    | { job = Some { workspace_id = ws } } -> ws
    | { project_context_id = None } -> failwith "DX_PROJECT_CONTEXT_ID environment is not configured"
    | { project_context_id = Some proj } -> proj

let with_workspace_id json = json $+ ("project",`String (workspace_id()))

let new_job ?(options=JSON.empty) function_name input =
  let input = options $+ ("function",`String function_name) $+ ("input",input)
  let ans = api_call ["job"; "new"] input
  JSON.string (ans$"id")

let get_link json =
  try
    match json$"$dnanexus_link" with
      | `String id -> None, id
      | (`Object _) as tuple -> (Some (JSON.string (tuple$"project"))), (JSON.string (tuple$"id"))
      | _ -> failwith ""
  with _ -> invalid_arg ("Invalid $dnanexus_link: " ^ (JSON.to_string json))


let make_link ?project id =
  let body = match project with
    | None -> `String id
    | Some proj_id -> JSON.of_assoc ["project", `String proj_id; "id", `String id]
  JSON.empty $+ ("$dnanexus_link",body)

let make_jobref job field = JSON.empty $+ ("job",`String job) $+ ("field",`String field)

type overcome_ocamldoc_bug_so_that_the_above_example_appears
