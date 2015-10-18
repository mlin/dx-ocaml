(** Bindings to the DNAnexus API, using libcurl for HTTP operations and
{{: https://github.com/mlin/yajl-ocaml} yajl-ocaml} for JSON processing.

Note on parallelism: some parts of the bindings (especially File and GTable
operations) use multiple threads to perform parallel HTTP requests. If your
program will use [fork()], it's inadvisable to do so while such operations are
in progress.

@see < http://wiki.dnanexus.com/ > DNAnexus Documentation Wiki
@see < http://mlin.github.com/yajl-ocaml/extra/JSON.html > yajl-ocaml JSON API
*)

(*
DEVELOPER NOTE:

DNAnexus.mli is auto-generated from DNAnexus.TEMPLATE.mli. The Makefile
inserts the auto-generated module signature and documentation for the API
method wrappers. Do not modify DNAnexus.mli by hand!
*)

(** {2 Bindings configuration} *)

(** General configuration needed to make API calls from both inside and outside
the platform. *)
type configuration = {
  apiserver_host: string;
  apiserver_port: int;
  apiserver_protocol : string;
  auth_token: string;
  auth_token_type: string;
  project_context_id: string option;
  
  job : job_configuration option;

  retry_times : int;
  retry_initial_delay : float;
  retry_backoff_factor : float;
  retry_logger: (string -> exn option -> unit) option
}
and job_configuration = {
  job_id : string;
  workspace_id : string

  (* TODO
  resources_id : string option;
  project_cache_id : string option *)
}
(** Configuration relevant to apps and applets executing on the
platform. *)

(** Get the current configuration. The configuration is initially loaded from
environment variables the first time it's needed.

@see < http://wiki.dnanexus.com/Execution-Environment-Reference#Environment-variables-in-the-container > Execution Environment Reference : Environment variables in the container
*)
val config : unit -> configuration

(** Get the current configuration as JSON (useful to print for debugging).

@param security_context include the authentication token (default false)
*)
val config_json : ?security_context:bool -> unit -> JSON.t

(** Change the configuration (rarely necessary). For example, to change the project
context:
[DNAnexus.reconfigure {(DNAnexus.config()) with DNAnexus.project_context_id = Some "project-xxxx"}]
*)
val reconfigure : configuration -> unit

(** Return the project ID in the configuration [project_context_id].

Note: apps and applets executing on the platform may be able to read from this
project, but cannot write to it. They may instead write to a "workspace" (see
the "Execution Environment" section below).

@raise Failure if [project_context_id = None] *)
val project_id : unit -> string

(** Add the key ["project": DNAnexus.project_id()] to the given JSON object.
Convenient for formulating JSON inputs to API calls requiring this field. *)
val with_project_id : JSON.t -> JSON.t

(** {2 Low-level API calls} *)

(** [DNAnexus.api_call ["noun"; "verb"] input] synchronously executes an HTTP
request for the API route [/noun/verb] (e.g. [/gtable-xxxx/get]) with the
given input JSON, and returns the response JSON.

Built-in retry logic detects "safe" errors (indicating that the HTTP request
was never received by the API server), and by default:

- The request is retried up to 5 times
- There is a delay of one second before the first retry
- The delay increases by a factor of two on each subsequent retry
- Each retry attempt, and the eventual success, is logged to standard error

These defaults can be changed using [reconfigure] (above); in particular,
retry logic can be disabled entirely by setting [retry_times] to 0. If all
retry attempts fail, then the exception raised on the {e last} attempt is re-
raised.

@param always_retry Enable retry in the event the HTTP request is interrupted
midway through, not just for "safe" errors. This should only be used for
idempotent API methods.

@raise APIError for error responses returned by the DNAnexus API server; also,
various other exceptions that can arise in the course of attempting an HTTP
request (especially [CurlException]).
*)
val api_call : ?always_retry:bool -> string list -> JSON.t -> JSON.t

(** Exception representing errors returned by the DNAnexus API server. Carries
the HTTP code, error type, message, and "details" JSON (which can be [`Null])

@see < http://wiki.dnanexus.com/API-Specification-v1.0.0/Protocols#Errors > API Specification : Protocols : Errors
*)
exception APIError of int*string*string*JSON.t

(** {b API method wrappers} *)

(** Low-level wrapper functions for each individual method in the DNAnexus API. 

These functions are thin wrappers around {! DNAnexus.api_call } for individual
API methods. Each function has an optional [always_retry] argument, which
adjusts the retry logic as described in the documentation for {!
DNAnexus.api_call }. This argument defaults to true for idempotent methods,
and false for others.

@see < http://wiki.dnanexus.com/API-Specification-v1.0.0/Introduction# > DNAnexus API Specification
*)
module API : sig
  (* Do not modify this module signature by hand. It is automatically generated by
     util/generateOCamlAPIWrappers_mli.py. *)

  (** Invokes the [/analysis-xxxx/addTags] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Workflows-and-Analyses#API-method%3A-%2Fanalysis-xxxx%2FaddTags > DNAnexus API Specification : /analysis-xxxx/addTags *)
  val analysis_add_tags : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/analysis-xxxx/describe] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Workflows-and-Analyses#API-method%3A-%2Fanalysis-xxxx%2Fdescribe > DNAnexus API Specification : /analysis-xxxx/describe *)
  val analysis_describe : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/analysis-xxxx/removeTags] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Workflows-and-Analyses#API-method%3A-%2Fanalysis-xxxx%2FremoveTags > DNAnexus API Specification : /analysis-xxxx/removeTags *)
  val analysis_remove_tags : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/analysis-xxxx/setProperties] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Workflows-and-Analyses#API-method%3A-%2Fanalysis-xxxx%2FsetProperties > DNAnexus API Specification : /analysis-xxxx/setProperties *)
  val analysis_set_properties : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/analysis-xxxx/terminate] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Workflows-and-Analyses#API-method%3A-%2Fanalysis-xxxx%2Fterminate > DNAnexus API Specification : /analysis-xxxx/terminate *)
  val analysis_terminate : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/app-xxxx/addAuthorizedUsers] API method with the given app name/ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Apps#API-method:-/app-xxxx%5B/yyyy%5D/addAuthorizedUsers > DNAnexus API Specification : /app-xxxx/addAuthorizedUsers *)
  val app_add_authorized_users : ?always_retry:bool -> ?alias:string -> string -> JSON.t -> JSON.t

  (** Invokes the [/app-xxxx/addCategories] API method with the given app name/ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Apps#API-method:-/app-xxxx%5B/yyyy%5D/addCategories > DNAnexus API Specification : /app-xxxx/addCategories *)
  val app_add_categories : ?always_retry:bool -> ?alias:string -> string -> JSON.t -> JSON.t

  (** Invokes the [/app-xxxx/addDevelopers] API method with the given app name/ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Apps#API-method:-/app-xxxx%5B/yyyy%5D/addDevelopers > DNAnexus API Specification : /app-xxxx/addDevelopers *)
  val app_add_developers : ?always_retry:bool -> ?alias:string -> string -> JSON.t -> JSON.t

  (** Invokes the [/app-xxxx/addTags] API method with the given app name/ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Apps#API-method:-/app-xxxx%5B/yyyy%5D/addTags > DNAnexus API Specification : /app-xxxx/addTags *)
  val app_add_tags : ?always_retry:bool -> ?alias:string -> string -> JSON.t -> JSON.t

  (** Invokes the [/app-xxxx/delete] API method with the given app name/ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Apps#API-method:-/app-xxxx%5B/yyyy%5D/delete > DNAnexus API Specification : /app-xxxx/delete *)
  val app_delete : ?always_retry:bool -> ?alias:string -> string -> JSON.t -> JSON.t

  (** Invokes the [/app-xxxx/describe] API method with the given app name/ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Apps#API-method:-/app-xxxx%5B/yyyy%5D/describe > DNAnexus API Specification : /app-xxxx/describe *)
  val app_describe : ?always_retry:bool -> ?alias:string -> string -> JSON.t -> JSON.t

  (** Invokes the [/app-xxxx/get] API method with the given app name/ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Apps#API-method:-/app-xxxx%5B/yyyy%5D/get > DNAnexus API Specification : /app-xxxx/get *)
  val app_get : ?always_retry:bool -> ?alias:string -> string -> JSON.t -> JSON.t

  (** Invokes the [/app-xxxx/install] API method with the given app name/ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Apps#API-method:-/app-xxxx%5B/yyyy%5D/install > DNAnexus API Specification : /app-xxxx/install *)
  val app_install : ?always_retry:bool -> ?alias:string -> string -> JSON.t -> JSON.t

  (** Invokes the [/app-xxxx/listAuthorizedUsers] API method with the given app name/ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Apps#API-method:-/app-xxxx%5B/yyyy%5D/listAuthorizedUsers > DNAnexus API Specification : /app-xxxx/listAuthorizedUsers *)
  val app_list_authorized_users : ?always_retry:bool -> ?alias:string -> string -> JSON.t -> JSON.t

  (** Invokes the [/app-xxxx/listCategories] API method with the given app name/ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Apps#API-method:-/app-xxxx%5B/yyyy%5D/listCategories > DNAnexus API Specification : /app-xxxx/listCategories *)
  val app_list_categories : ?always_retry:bool -> ?alias:string -> string -> JSON.t -> JSON.t

  (** Invokes the [/app-xxxx/listDevelopers] API method with the given app name/ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Apps#API-method:-/app-xxxx%5B/yyyy%5D/listDevelopers > DNAnexus API Specification : /app-xxxx/listDevelopers *)
  val app_list_developers : ?always_retry:bool -> ?alias:string -> string -> JSON.t -> JSON.t

  (** Invokes the [/app-xxxx/publish] API method with the given app name/ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Apps#API-method:-/app-xxxx%5B/yyyy%5D/publish > DNAnexus API Specification : /app-xxxx/publish *)
  val app_publish : ?always_retry:bool -> ?alias:string -> string -> JSON.t -> JSON.t

  (** Invokes the [/app-xxxx/removeAuthorizedUsers] API method with the given app name/ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Apps#API-method:-/app-xxxx%5B/yyyy%5D/removeAuthorizedUsers > DNAnexus API Specification : /app-xxxx/removeAuthorizedUsers *)
  val app_remove_authorized_users : ?always_retry:bool -> ?alias:string -> string -> JSON.t -> JSON.t

  (** Invokes the [/app-xxxx/removeCategories] API method with the given app name/ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Apps#API-method:-/app-xxxx%5B/yyyy%5D/removeCategories > DNAnexus API Specification : /app-xxxx/removeCategories *)
  val app_remove_categories : ?always_retry:bool -> ?alias:string -> string -> JSON.t -> JSON.t

  (** Invokes the [/app-xxxx/removeDevelopers] API method with the given app name/ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Apps#API-method:-/app-xxxx%5B/yyyy%5D/removeDevelopers > DNAnexus API Specification : /app-xxxx/removeDevelopers *)
  val app_remove_developers : ?always_retry:bool -> ?alias:string -> string -> JSON.t -> JSON.t

  (** Invokes the [/app-xxxx/removeTags] API method with the given app name/ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Apps#API-method:-/app-xxxx%5B/yyyy%5D/removeTags > DNAnexus API Specification : /app-xxxx/removeTags *)
  val app_remove_tags : ?always_retry:bool -> ?alias:string -> string -> JSON.t -> JSON.t

  (** Invokes the [/app-xxxx/run] API method with the given app name/ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Apps#API-method:-/app-xxxx%5B/yyyy%5D/run > DNAnexus API Specification : /app-xxxx/run *)
  val app_run : ?always_retry:bool -> ?alias:string -> string -> JSON.t -> JSON.t

  (** Invokes the [/app-xxxx/uninstall] API method with the given app name/ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Apps#API-method:-/app-xxxx%5B/yyyy%5D/uninstall > DNAnexus API Specification : /app-xxxx/uninstall *)
  val app_uninstall : ?always_retry:bool -> ?alias:string -> string -> JSON.t -> JSON.t

  (** Invokes the [/app-xxxx/update] API method with the given app name/ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Apps#API-method:-/app-xxxx%5B/yyyy%5D/update > DNAnexus API Specification : /app-xxxx/update *)
  val app_update : ?always_retry:bool -> ?alias:string -> string -> JSON.t -> JSON.t

  (** Invokes the [/app/new] API method with the given JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Apps#API-method:-/app/new > DNAnexus API Specification : /app/new *)
  val app_new : ?always_retry:bool -> JSON.t -> JSON.t

  (** Invokes the [/applet-xxxx/addTags] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Tags#API-method%3A-%2Fclass-xxxx%2FaddTags > DNAnexus API Specification : /applet-xxxx/addTags *)
  val applet_add_tags : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/applet-xxxx/describe] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Applets-and-Entry-Points#API-method%3A-%2Fapplet-xxxx%2Fdescribe > DNAnexus API Specification : /applet-xxxx/describe *)
  val applet_describe : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/applet-xxxx/get] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Applets-and-Entry-Points#API-method%3A-%2Fapplet-xxxx%2Fget > DNAnexus API Specification : /applet-xxxx/get *)
  val applet_get : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/applet-xxxx/getDetails] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Details-and-Links#API-method%3A-%2Fclass-xxxx%2FgetDetails > DNAnexus API Specification : /applet-xxxx/getDetails *)
  val applet_get_details : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/applet-xxxx/listProjects] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Cloning#API-method%3A-%2Fclass-xxxx%2FlistProjects > DNAnexus API Specification : /applet-xxxx/listProjects *)
  val applet_list_projects : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/applet-xxxx/removeTags] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Tags#API-method%3A-%2Fclass-xxxx%2FremoveTags > DNAnexus API Specification : /applet-xxxx/removeTags *)
  val applet_remove_tags : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/applet-xxxx/rename] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Name#API-method%3A-%2Fclass-xxxx%2Frename > DNAnexus API Specification : /applet-xxxx/rename *)
  val applet_rename : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/applet-xxxx/run] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Applets-and-Entry-Points#API-method%3A-%2Fapplet-xxxx%2Frun > DNAnexus API Specification : /applet-xxxx/run *)
  val applet_run : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/applet-xxxx/setProperties] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Properties#API-method%3A-%2Fclass-xxxx%2FsetProperties > DNAnexus API Specification : /applet-xxxx/setProperties *)
  val applet_set_properties : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/applet/new] API method with the given JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Applets-and-Entry-Points#API-method%3A-%2Fapplet%2Fnew > DNAnexus API Specification : /applet/new *)
  val applet_new : ?always_retry:bool -> JSON.t -> JSON.t

  (** Invokes the [/container-xxxx/clone] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Cloning#API-method%3A-%2Fclass-xxxx%2Fclone > DNAnexus API Specification : /container-xxxx/clone *)
  val container_clone : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/container-xxxx/describe] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Containers-for-Execution#API-method%3A-%2Fcontainer-xxxx%2Fdescribe > DNAnexus API Specification : /container-xxxx/describe *)
  val container_describe : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/container-xxxx/destroy] API method with the given object ID and JSON input, returning the JSON output.
   *)
  val container_destroy : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/container-xxxx/listFolder] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Folders-and-Deletion#API-method%3A-%2Fclass-xxxx%2FlistFolder > DNAnexus API Specification : /container-xxxx/listFolder *)
  val container_list_folder : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/container-xxxx/move] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Folders-and-Deletion#API-method%3A-%2Fclass-xxxx%2Fmove > DNAnexus API Specification : /container-xxxx/move *)
  val container_move : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/container-xxxx/newFolder] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Folders-and-Deletion#API-method%3A-%2Fclass-xxxx%2FnewFolder > DNAnexus API Specification : /container-xxxx/newFolder *)
  val container_new_folder : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/container-xxxx/removeFolder] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Folders-and-Deletion#API-method%3A-%2Fclass-xxxx%2FremoveFolder > DNAnexus API Specification : /container-xxxx/removeFolder *)
  val container_remove_folder : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/container-xxxx/removeObjects] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Folders-and-Deletion#API-method%3A-%2Fclass-xxxx%2FremoveObjects > DNAnexus API Specification : /container-xxxx/removeObjects *)
  val container_remove_objects : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/container-xxxx/renameFolder] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Folders-and-Deletion#API-method%3A-%2Fclass-xxxx%2FrenameFolder > DNAnexus API Specification : /container-xxxx/renameFolder *)
  val container_rename_folder : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/file-xxxx/addTags] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Tags#API-method%3A-%2Fclass-xxxx%2FaddTags > DNAnexus API Specification : /file-xxxx/addTags *)
  val file_add_tags : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/file-xxxx/addTypes] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Types#API-method%3A-%2Fclass-xxxx%2FaddTypes > DNAnexus API Specification : /file-xxxx/addTypes *)
  val file_add_types : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/file-xxxx/close] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Files#API-method%3A-%2Ffile-xxxx%2Fclose > DNAnexus API Specification : /file-xxxx/close *)
  val file_close : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/file-xxxx/describe] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Files#API-method%3A-%2Ffile-xxxx%2Fdescribe > DNAnexus API Specification : /file-xxxx/describe *)
  val file_describe : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/file-xxxx/download] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Files#API-method%3A-%2Ffile-xxxx%2Fdownload > DNAnexus API Specification : /file-xxxx/download *)
  val file_download : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/file-xxxx/getDetails] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Details-and-Links#API-method%3A-%2Fclass-xxxx%2FgetDetails > DNAnexus API Specification : /file-xxxx/getDetails *)
  val file_get_details : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/file-xxxx/listProjects] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Cloning#API-method%3A-%2Fclass-xxxx%2FlistProjects > DNAnexus API Specification : /file-xxxx/listProjects *)
  val file_list_projects : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/file-xxxx/removeTags] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Tags#API-method%3A-%2Fclass-xxxx%2FremoveTags > DNAnexus API Specification : /file-xxxx/removeTags *)
  val file_remove_tags : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/file-xxxx/removeTypes] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Types#API-method%3A-%2Fclass-xxxx%2FremoveTypes > DNAnexus API Specification : /file-xxxx/removeTypes *)
  val file_remove_types : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/file-xxxx/rename] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Name#API-method%3A-%2Fclass-xxxx%2Frename > DNAnexus API Specification : /file-xxxx/rename *)
  val file_rename : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/file-xxxx/setDetails] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Details-and-Links#API-method%3A-%2Fclass-xxxx%2FsetDetails > DNAnexus API Specification : /file-xxxx/setDetails *)
  val file_set_details : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/file-xxxx/setProperties] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Properties#API-method%3A-%2Fclass-xxxx%2FsetProperties > DNAnexus API Specification : /file-xxxx/setProperties *)
  val file_set_properties : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/file-xxxx/setVisibility] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Visibility#API-method%3A-%2Fclass-xxxx%2FsetVisibility > DNAnexus API Specification : /file-xxxx/setVisibility *)
  val file_set_visibility : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/file-xxxx/upload] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Files#API-method%3A-%2Ffile-xxxx%2Fupload > DNAnexus API Specification : /file-xxxx/upload *)
  val file_upload : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/file/new] API method with the given JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Files#API-method%3A-%2Ffile%2Fnew > DNAnexus API Specification : /file/new *)
  val file_new : ?always_retry:bool -> JSON.t -> JSON.t

  (** Invokes the [/gtable-xxxx/addRows] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/GenomicTables#API-method%3A-%2Fgtable-xxxx%2FaddRows > DNAnexus API Specification : /gtable-xxxx/addRows *)
  val gtable_add_rows : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/gtable-xxxx/addTags] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Tags#API-method%3A-%2Fclass-xxxx%2FaddTags > DNAnexus API Specification : /gtable-xxxx/addTags *)
  val gtable_add_tags : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/gtable-xxxx/addTypes] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Types#API-method%3A-%2Fclass-xxxx%2FaddTypes > DNAnexus API Specification : /gtable-xxxx/addTypes *)
  val gtable_add_types : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/gtable-xxxx/close] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/GenomicTables#API-method%3A-%2Fgtable-xxxx%2Fclose > DNAnexus API Specification : /gtable-xxxx/close *)
  val gtable_close : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/gtable-xxxx/describe] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/GenomicTables#API-method%3A-%2Fgtable-xxxx%2Fdescribe > DNAnexus API Specification : /gtable-xxxx/describe *)
  val gtable_describe : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/gtable-xxxx/get] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/GenomicTables#API-method%3A-%2Fgtable-xxxx%2Fget > DNAnexus API Specification : /gtable-xxxx/get *)
  val gtable_get : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/gtable-xxxx/getDetails] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Details-and-Links#API-method%3A-%2Fclass-xxxx%2FgetDetails > DNAnexus API Specification : /gtable-xxxx/getDetails *)
  val gtable_get_details : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/gtable-xxxx/listProjects] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Cloning#API-method%3A-%2Fclass-xxxx%2FlistProjects > DNAnexus API Specification : /gtable-xxxx/listProjects *)
  val gtable_list_projects : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/gtable-xxxx/nextPart] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/GenomicTables#API-method%3A-%2Fgtable-xxxx%2FnextPart > DNAnexus API Specification : /gtable-xxxx/nextPart *)
  val gtable_next_part : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/gtable-xxxx/removeTags] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Tags#API-method%3A-%2Fclass-xxxx%2FremoveTags > DNAnexus API Specification : /gtable-xxxx/removeTags *)
  val gtable_remove_tags : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/gtable-xxxx/removeTypes] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Types#API-method%3A-%2Fclass-xxxx%2FremoveTypes > DNAnexus API Specification : /gtable-xxxx/removeTypes *)
  val gtable_remove_types : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/gtable-xxxx/rename] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Name#API-method%3A-%2Fclass-xxxx%2Frename > DNAnexus API Specification : /gtable-xxxx/rename *)
  val gtable_rename : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/gtable-xxxx/setDetails] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Details-and-Links#API-method%3A-%2Fclass-xxxx%2FsetDetails > DNAnexus API Specification : /gtable-xxxx/setDetails *)
  val gtable_set_details : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/gtable-xxxx/setProperties] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Properties#API-method%3A-%2Fclass-xxxx%2FsetProperties > DNAnexus API Specification : /gtable-xxxx/setProperties *)
  val gtable_set_properties : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/gtable-xxxx/setVisibility] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Visibility#API-method%3A-%2Fclass-xxxx%2FsetVisibility > DNAnexus API Specification : /gtable-xxxx/setVisibility *)
  val gtable_set_visibility : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/gtable/new] API method with the given JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/GenomicTables#API-method%3A-%2Fgtable%2Fnew > DNAnexus API Specification : /gtable/new *)
  val gtable_new : ?always_retry:bool -> JSON.t -> JSON.t

  (** Invokes the [/job-xxxx/addTags] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Applets-and-Entry-Points#API-method%3A-%2Fjob-xxxx%2FaddTags > DNAnexus API Specification : /job-xxxx/addTags *)
  val job_add_tags : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/job-xxxx/describe] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Applets-and-Entry-Points#API-method%3A-%2Fjob-xxxx%2Fdescribe > DNAnexus API Specification : /job-xxxx/describe *)
  val job_describe : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/job-xxxx/getLog] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Applets-and-Entry-Points#API-method%3A-%2Fjob-xxxx%2FgetLog > DNAnexus API Specification : /job-xxxx/getLog *)
  val job_get_log : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/job-xxxx/removeTags] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Applets-and-Entry-Points#API-method%3A-%2Fjob-xxxx%2FremoveTags > DNAnexus API Specification : /job-xxxx/removeTags *)
  val job_remove_tags : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/job-xxxx/setProperties] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Applets-and-Entry-Points#API-method%3A-%2Fjob-xxxx%2FsetProperties > DNAnexus API Specification : /job-xxxx/setProperties *)
  val job_set_properties : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/job-xxxx/terminate] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Applets-and-Entry-Points#API-method%3A-%2Fjob-xxxx%2Fterminate > DNAnexus API Specification : /job-xxxx/terminate *)
  val job_terminate : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/job/new] API method with the given JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Applets-and-Entry-Points#API-method%3A-%2Fjob%2Fnew > DNAnexus API Specification : /job/new *)
  val job_new : ?always_retry:bool -> JSON.t -> JSON.t

  (** Invokes the [/notifications/get] API method with the given JSON input, returning the JSON output.
   *)
  val notifications_get : ?always_retry:bool -> JSON.t -> JSON.t

  (** Invokes the [/notifications/markRead] API method with the given JSON input, returning the JSON output.
   *)
  val notifications_mark_read : ?always_retry:bool -> JSON.t -> JSON.t

  (** Invokes the [/org-xxxx/describe] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Organizations#API-method%3A-%2Forg-xxxx%2Fdescribe > DNAnexus API Specification : /org-xxxx/describe *)
  val org_describe : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/org-xxxx/findProjects] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Organizations#API-method%3A-%2Forg-xxxx%2FfindProjects > DNAnexus API Specification : /org-xxxx/findProjects *)
  val org_find_projects : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/org-xxxx/getMemberAccess] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Organizations#API-method%3A-%2Forg-xxxx%2FgetMemberAccess > DNAnexus API Specification : /org-xxxx/getMemberAccess *)
  val org_get_member_access : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/org-xxxx/invite] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Organizations#API-method%3A-%2Forg-xxxx%2Finvite > DNAnexus API Specification : /org-xxxx/invite *)
  val org_invite : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/org-xxxx/removeMember] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Organizations#API-method%3A-%2Forg-xxxx%2FremoveMember > DNAnexus API Specification : /org-xxxx/removeMember *)
  val org_remove_member : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/org-xxxx/setMemberAccess] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Organizations#API-method%3A-%2Forg-xxxx%2FsetMemberAccess > DNAnexus API Specification : /org-xxxx/setMemberAccess *)
  val org_set_member_access : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/org-xxxx/update] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Organizations#API-method%3A-%2Forg-xxxx%2Fupdate > DNAnexus API Specification : /org-xxxx/update *)
  val org_update : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/org/new] API method with the given JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Organizations#API-method%3A-%2Forg%2Fnew > DNAnexus API Specification : /org/new *)
  val org_new : ?always_retry:bool -> JSON.t -> JSON.t

  (** Invokes the [/project-xxxx/addTags] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Projects#API-method%3A-%2Fproject-xxxx%2FaddTags > DNAnexus API Specification : /project-xxxx/addTags *)
  val project_add_tags : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/project-xxxx/clone] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Cloning#API-method%3A-%2Fclass-xxxx%2Fclone > DNAnexus API Specification : /project-xxxx/clone *)
  val project_clone : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/project-xxxx/decreasePermissions] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Project-Permissions-and-Sharing#API-method%3A-%2Fproject-xxxx%2FdecreasePermissions > DNAnexus API Specification : /project-xxxx/decreasePermissions *)
  val project_decrease_permissions : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/project-xxxx/describe] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Projects#API-method%3A-%2Fproject-xxxx%2Fdescribe > DNAnexus API Specification : /project-xxxx/describe *)
  val project_describe : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/project-xxxx/destroy] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Projects#API-method%3A-%2Fproject-xxxx%2Fdestroy > DNAnexus API Specification : /project-xxxx/destroy *)
  val project_destroy : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/project-xxxx/invite] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Project-Permissions-and-Sharing#API-method%3A-%2Fproject-xxxx%2Finvite > DNAnexus API Specification : /project-xxxx/invite *)
  val project_invite : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/project-xxxx/leave] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Project-Permissions-and-Sharing#API-method%3A-%2Fproject-xxxx%2Fleave > DNAnexus API Specification : /project-xxxx/leave *)
  val project_leave : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/project-xxxx/listFolder] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Folders-and-Deletion#API-method%3A-%2Fclass-xxxx%2FlistFolder > DNAnexus API Specification : /project-xxxx/listFolder *)
  val project_list_folder : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/project-xxxx/move] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Folders-and-Deletion#API-method%3A-%2Fclass-xxxx%2Fmove > DNAnexus API Specification : /project-xxxx/move *)
  val project_move : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/project-xxxx/newFolder] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Folders-and-Deletion#API-method%3A-%2Fclass-xxxx%2FnewFolder > DNAnexus API Specification : /project-xxxx/newFolder *)
  val project_new_folder : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/project-xxxx/removeFolder] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Folders-and-Deletion#API-method%3A-%2Fclass-xxxx%2FremoveFolder > DNAnexus API Specification : /project-xxxx/removeFolder *)
  val project_remove_folder : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/project-xxxx/removeObjects] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Folders-and-Deletion#API-method%3A-%2Fclass-xxxx%2FremoveObjects > DNAnexus API Specification : /project-xxxx/removeObjects *)
  val project_remove_objects : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/project-xxxx/removeTags] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Projects#API-method%3A-%2Fproject-xxxx%2FremoveTags > DNAnexus API Specification : /project-xxxx/removeTags *)
  val project_remove_tags : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/project-xxxx/renameFolder] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Folders-and-Deletion#API-method%3A-%2Fclass-xxxx%2FrenameFolder > DNAnexus API Specification : /project-xxxx/renameFolder *)
  val project_rename_folder : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/project-xxxx/setProperties] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Projects#API-method%3A-%2Fproject-xxxx%2FsetProperties > DNAnexus API Specification : /project-xxxx/setProperties *)
  val project_set_properties : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/project-xxxx/transfer] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Project-Permissions-and-Sharing#API-method%3A-%2Fproject-xxxx%2Ftransfer > DNAnexus API Specification : /project-xxxx/transfer *)
  val project_transfer : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/project-xxxx/update] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Projects#API-method%3A-%2Fproject-xxxx%2Fupdate > DNAnexus API Specification : /project-xxxx/update *)
  val project_update : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/project-xxxx/updateSponsorship] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Projects#API-method%3A-%2Fproject-xxxx%2FupdateSponsorship > DNAnexus API Specification : /project-xxxx/updateSponsorship *)
  val project_update_sponsorship : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/project/new] API method with the given JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Projects#API-method%3A-%2Fproject%2Fnew > DNAnexus API Specification : /project/new *)
  val project_new : ?always_retry:bool -> JSON.t -> JSON.t

  (** Invokes the [/record-xxxx/addTags] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Tags#API-method%3A-%2Fclass-xxxx%2FaddTags > DNAnexus API Specification : /record-xxxx/addTags *)
  val record_add_tags : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/record-xxxx/addTypes] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Types#API-method%3A-%2Fclass-xxxx%2FaddTypes > DNAnexus API Specification : /record-xxxx/addTypes *)
  val record_add_types : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/record-xxxx/close] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Data-Object-Lifecycle#API-method%3A-%2Fclass-xxxx%2Fclose > DNAnexus API Specification : /record-xxxx/close *)
  val record_close : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/record-xxxx/describe] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Records#API-method%3A-%2Frecord-xxxx%2Fdescribe > DNAnexus API Specification : /record-xxxx/describe *)
  val record_describe : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/record-xxxx/getDetails] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Details-and-Links#API-method%3A-%2Fclass-xxxx%2FgetDetails > DNAnexus API Specification : /record-xxxx/getDetails *)
  val record_get_details : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/record-xxxx/listProjects] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Cloning#API-method%3A-%2Fclass-xxxx%2FlistProjects > DNAnexus API Specification : /record-xxxx/listProjects *)
  val record_list_projects : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/record-xxxx/removeTags] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Tags#API-method%3A-%2Fclass-xxxx%2FremoveTags > DNAnexus API Specification : /record-xxxx/removeTags *)
  val record_remove_tags : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/record-xxxx/removeTypes] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Types#API-method%3A-%2Fclass-xxxx%2FremoveTypes > DNAnexus API Specification : /record-xxxx/removeTypes *)
  val record_remove_types : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/record-xxxx/rename] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Name#API-method%3A-%2Fclass-xxxx%2Frename > DNAnexus API Specification : /record-xxxx/rename *)
  val record_rename : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/record-xxxx/setDetails] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Details-and-Links#API-method%3A-%2Fclass-xxxx%2FsetDetails > DNAnexus API Specification : /record-xxxx/setDetails *)
  val record_set_details : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/record-xxxx/setProperties] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Properties#API-method%3A-%2Fclass-xxxx%2FsetProperties > DNAnexus API Specification : /record-xxxx/setProperties *)
  val record_set_properties : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/record-xxxx/setVisibility] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Visibility#API-method%3A-%2Fclass-xxxx%2FsetVisibility > DNAnexus API Specification : /record-xxxx/setVisibility *)
  val record_set_visibility : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/record/new] API method with the given JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Records#API-method%3A-%2Frecord%2Fnew > DNAnexus API Specification : /record/new *)
  val record_new : ?always_retry:bool -> JSON.t -> JSON.t

  (** Invokes the [/system/findAffiliates] API method with the given JSON input, returning the JSON output.
   *)
  val system_find_affiliates : ?always_retry:bool -> JSON.t -> JSON.t

  (** Invokes the [/system/findApps] API method with the given JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Search#API-method%3A-%2Fsystem%2FfindApps > DNAnexus API Specification : /system/findApps *)
  val system_find_apps : ?always_retry:bool -> JSON.t -> JSON.t

  (** Invokes the [/system/findDataObjects] API method with the given JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Search#API-method%3A-%2Fsystem%2FfindDataObjects > DNAnexus API Specification : /system/findDataObjects *)
  val system_find_data_objects : ?always_retry:bool -> JSON.t -> JSON.t

  (** Invokes the [/system/resolveDataObjects] API method with the given JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/System-Methods#API-method:-/system/resolveDataObjects > DNAnexus API Specification : /system/resolveDataObjects *)
  val system_resolve_data_objects : ?always_retry:bool -> JSON.t -> JSON.t

  (** Invokes the [/system/findExecutions] API method with the given JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Search#API-method%3A-%2Fsystem%2FfindExecutions > DNAnexus API Specification : /system/findExecutions *)
  val system_find_executions : ?always_retry:bool -> JSON.t -> JSON.t

  (** Invokes the [/system/findAnalyses] API method with the given JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Search#API-method%3A-%2Fsystem%2FfindAnalyses > DNAnexus API Specification : /system/findAnalyses *)
  val system_find_analyses : ?always_retry:bool -> JSON.t -> JSON.t

  (** Invokes the [/system/findJobs] API method with the given JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Search#API-method%3A-%2Fsystem%2FfindJobs > DNAnexus API Specification : /system/findJobs *)
  val system_find_jobs : ?always_retry:bool -> JSON.t -> JSON.t

  (** Invokes the [/system/findProjects] API method with the given JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Search#API-method%3A-%2Fsystem%2FfindProjects > DNAnexus API Specification : /system/findProjects *)
  val system_find_projects : ?always_retry:bool -> JSON.t -> JSON.t

  (** Invokes the [/system/findUsers] API method with the given JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Search#API-method%3A-%2Fsystem%2FfindUsers > DNAnexus API Specification : /system/findUsers *)
  val system_find_users : ?always_retry:bool -> JSON.t -> JSON.t

  (** Invokes the [/system/findProjectMembers] API method with the given JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Search#API-method:-/system/findProjectMembers > DNAnexus API Specification : /system/findProjectMembers *)
  val system_find_project_members : ?always_retry:bool -> JSON.t -> JSON.t

  (** Invokes the [/system/globalSearch] API method with the given JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Search#API-method:-/system/globalSearch > DNAnexus API Specification : /system/globalSearch *)
  val system_global_search : ?always_retry:bool -> JSON.t -> JSON.t

  (** Invokes the [/system/greet] API method with the given JSON input, returning the JSON output.
   *)
  val system_greet : ?always_retry:bool -> JSON.t -> JSON.t

  (** Invokes the [/system/shortenURL] API method with the given JSON input, returning the JSON output.
   *)
  val system_shorten_url : ?always_retry:bool -> JSON.t -> JSON.t

  (** Invokes the [/system/whoami] API method with the given JSON input, returning the JSON output.
   *)
  val system_whoami : ?always_retry:bool -> JSON.t -> JSON.t

  (** Invokes the [/user-xxxx/describe] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Users#API-method%3A-%2Fuser-xxxx%2Fdescribe > DNAnexus API Specification : /user-xxxx/describe *)
  val user_describe : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/user-xxxx/update] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Users#API-method%3A-%2Fuser-xxxx%2Fupdate > DNAnexus API Specification : /user-xxxx/update *)
  val user_update : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/workflow-xxxx/addStage] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Workflows-and-Analyses#API-method%3A-%2Fworkflow-xxxx%2FaddStage > DNAnexus API Specification : /workflow-xxxx/addStage *)
  val workflow_add_stage : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/workflow-xxxx/addTags] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Tags#API-method%3A-%2Fclass-xxxx%2FaddTags > DNAnexus API Specification : /workflow-xxxx/addTags *)
  val workflow_add_tags : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/workflow-xxxx/addTypes] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Types#API-method%3A-%2Fclass-xxxx%2FaddTypes > DNAnexus API Specification : /workflow-xxxx/addTypes *)
  val workflow_add_types : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/workflow-xxxx/close] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Data-Object-Lifecycle#API-method%3A-%2Fclass-xxxx%2Fclose > DNAnexus API Specification : /workflow-xxxx/close *)
  val workflow_close : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/workflow-xxxx/describe] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Workflows-and-Analyses#API-method%3A-%2Fworkflow-xxxx%2Fdescribe > DNAnexus API Specification : /workflow-xxxx/describe *)
  val workflow_describe : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/workflow-xxxx/dryRun] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Workflows-and-Analyses#API-method%3A-%2Fworkflow-xxxx%2FdryRun > DNAnexus API Specification : /workflow-xxxx/dryRun *)
  val workflow_dry_run : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/workflow-xxxx/getDetails] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Details-and-Links#API-method%3A-%2Fclass-xxxx%2FgetDetails > DNAnexus API Specification : /workflow-xxxx/getDetails *)
  val workflow_get_details : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/workflow-xxxx/isStageCompatible] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Workflows-and-Analyses#API-method%3A-%2Fworkflow-xxxx%2FisStageCompatible > DNAnexus API Specification : /workflow-xxxx/isStageCompatible *)
  val workflow_is_stage_compatible : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/workflow-xxxx/listProjects] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Cloning#API-method%3A-%2Fclass-xxxx%2FlistProjects > DNAnexus API Specification : /workflow-xxxx/listProjects *)
  val workflow_list_projects : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/workflow-xxxx/moveStage] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Workflows-and-Analyses#API-method%3A-%2Fworkflow-xxxx%2FmoveStage > DNAnexus API Specification : /workflow-xxxx/moveStage *)
  val workflow_move_stage : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/workflow-xxxx/overwrite] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Workflows-and-Analyses#API-method%3A-%2Fworkflow-xxxx%2Foverwrite > DNAnexus API Specification : /workflow-xxxx/overwrite *)
  val workflow_overwrite : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/workflow-xxxx/removeStage] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Workflows-and-Analyses#API-method%3A-%2Fworkflow-xxxx%2FremoveStage > DNAnexus API Specification : /workflow-xxxx/removeStage *)
  val workflow_remove_stage : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/workflow-xxxx/removeTags] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Tags#API-method%3A-%2Fclass-xxxx%2FremoveTags > DNAnexus API Specification : /workflow-xxxx/removeTags *)
  val workflow_remove_tags : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/workflow-xxxx/removeTypes] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Types#API-method%3A-%2Fclass-xxxx%2FremoveTypes > DNAnexus API Specification : /workflow-xxxx/removeTypes *)
  val workflow_remove_types : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/workflow-xxxx/rename] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Name#API-method%3A-%2Fclass-xxxx%2Frename > DNAnexus API Specification : /workflow-xxxx/rename *)
  val workflow_rename : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/workflow-xxxx/run] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Workflows-and-Analyses#API-method%3A-%2Fworkflow-xxxx%2Frun > DNAnexus API Specification : /workflow-xxxx/run *)
  val workflow_run : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/workflow-xxxx/setDetails] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Details-and-Links#API-method%3A-%2Fclass-xxxx%2FsetDetails > DNAnexus API Specification : /workflow-xxxx/setDetails *)
  val workflow_set_details : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/workflow-xxxx/setProperties] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Properties#API-method%3A-%2Fclass-xxxx%2FsetProperties > DNAnexus API Specification : /workflow-xxxx/setProperties *)
  val workflow_set_properties : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/workflow-xxxx/setStageInputs] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Workflows-and-Analyses#API-method%3A-%2Fworkflow-xxxx%2FsetStageInputs > DNAnexus API Specification : /workflow-xxxx/setStageInputs *)
  val workflow_set_stage_inputs : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/workflow-xxxx/setVisibility] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Visibility#API-method%3A-%2Fclass-xxxx%2FsetVisibility > DNAnexus API Specification : /workflow-xxxx/setVisibility *)
  val workflow_set_visibility : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/workflow-xxxx/update] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Workflows-and-Analyses#API-method%3A-%2Fworkflow-xxxx%2Fupdate > DNAnexus API Specification : /workflow-xxxx/update *)
  val workflow_update : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/workflow-xxxx/updateStageExecutable] API method with the given object ID and JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Workflows-and-Analyses#API-method%3A-%2Fworkflow-xxxx%2FupdateStageExecutable > DNAnexus API Specification : /workflow-xxxx/updateStageExecutable *)
  val workflow_update_stage_executable : ?always_retry:bool -> string -> JSON.t -> JSON.t

  (** Invokes the [/workflow/new] API method with the given JSON input, returning the JSON output.
  @see < https://wiki.dnanexus.com/API-Specification-v1.0.0/Workflows-and-Analyses#API-method%3A-%2Fworkflow%2Fnew > DNAnexus API Specification : /workflow/new *)
  val workflow_new : ?always_retry:bool -> JSON.t -> JSON.t

(** {2 High-level bindings for records, files, and GTables} *)

(** Signature common to DNAnexus data objects (records, files, and GenomicTables).

@see < http://wiki.dnanexus.com/API-Specification-v1.0.0/Data-Object-Lifecycle > API Specification : Data Object Lifecycle
@see < http://wiki.dnanexus.com/API-Specification-v1.0.0/Introduction-to-Data-Object-Metadata > API Specification : Data Object Metadata
*)
module type DataObject = sig
  type t

  (** [DNAnexus.{Class}.make_new options] invokes the [/{class}-xxxx/new]
      API call with the given JSON input. If the input specifies a [project]
      key, it is passed through to the API server. Otherwise, the [project] key
      is set to the current workspace or project context before being passed to
      the API server. *)
  val make_new : JSON.t -> t

  (** [DNAnexus.{Class}.bind (project,dxid)] returns a wrapper for an existing
      data object with the given project and object IDs.

      If [project] is [None]:
      - Subsequent API calls requiring a project to be specified will be made
        using the workspace or project context.
      - For API calls in which specifying a project is optional, none is passed
        to the API server, which will attempt to resolve the object ID to a
        project containing the object in which the caller has the necessary
        permissions. *)
  val bind : (string option*string) -> t

  (** [DNAnexus.{Class}.bind_link link] returns a wrapper for an existing data
      object specified by a [$dnanexus_link] JSON, as frequently received in
      job input. Composes {! DNAnexus.get_link } and [bind]. *)
  val bind_link : JSON.t -> t

  (** Invokes [/{class}-xxxx/close] on an existing, open data object.
  
      @param wait for the object to reach the [closed] state before returning
                  (default false)
  *)
  val close : ?wait:bool -> t -> unit

  (** [DNAnexus.{Class}.with_new options fn] invokes [/{class}-xxxx/new]
      with the given JSON input, calls your function [fn] with the resulting
      object, and then invokes [/{class}-xxxx/close]. The [close] operation is
      {e not} performed if [fn] raises an exception.

      @param wait for the object to reach the [closed] state before returning
                  (default false)
  *)
  val with_new : ?wait:bool -> JSON.t -> (t -> 'a) -> 'a


  (** Retrieve the DNAnexus ID of the object*)
  val id : t -> string

  (** Invokes [/{class}-xxxx/describe] and returns the JSON results.

      @param options an input JSON passed through to the API server with any
             class-specific options to control the detail level of the results
             (see the API documentation for class describe routes) *)
  val describe : ?options:JSON.t -> t -> JSON.t

  val rename : t -> string -> unit 

  (** Set properties on the object. Values of [None] cause the respective
      property to be removed. *)
  val set_properties : t -> (string*(string option)) list -> unit

  val add_tags : t -> string list -> unit
  val remove_tags : t -> string list -> unit

  val add_types : t -> string list -> unit  
  val remove_types : t -> string list -> unit
  val set_details : t -> JSON.t -> unit
  val get_details : t -> JSON.t
  val set_visibility : t -> hidden:bool -> unit

(** Records

@see < http://wiki.dnanexus.com/API-Specification-v1.0.0/Records > API Specification : Records *)
module Record : sig
  (** Common interface to all data objects *)
  include DataObject

(** Files

@see < http://wiki.dnanexus.com/API-Specification-v1.0.0/Files > API Specification : Files *)
module File : sig
  (** Common interface to all data objects *)
  include DataObject

  (** {3 Transferring files to and from the local file system} *)

  (** [DNAnexus.File.upload_new local_filename] creates a new platform file object,
      uploads the local file to it, and closes it. By default, the file object will
      be placed in the root folder of the current workspace or project, and will be
      given the same name as the local file.

      @param options a JSON object containing inputs passed along to the
      [/file-xxxx/new] API call. By specifying appropriate keys here, the project,
      folder, and name can be overridden, and various other metadata can be set (see
      the API documentation).
      
      @param wait for the file object to become 'closed' before returning (default
             false)
  *)
  val upload_new : ?options:JSON.t -> ?wait:bool -> string -> t

  (** [DNAnexus.File.upload file local_filename] uploads a local file to the
      existing platform file object. The file object must be in the open state,
      generally with no data yet written to it, and is {e {b not}} closed when the
      upload is complete. That is, once the upload is complete, it will still be
      necessary to make the [/file-xxxx/close] API call before the data can be read
      through the API. *)
  val upload : t -> string -> unit

  (** [DNAnexus.File.download_url file] invokes [/file-xxxx/download], returning
      a "preauthenticated" URL from which the file data can be downloaded by any
      HTTP\[S\] client.

      @param duration see {{: http://wiki.dnanexus.com/API-Specification-v1.0.0/Files#API-method%3A-%2Ffile-xxxx%2Fdownload } API Specification : Files : /file-xxxx/download }

      {b Security warning:} since file downloads URLs provide access to the file data,
      they generally should not be printed on the console, logged in error messages,
      or otherwise stored permanently. *)
  val download_url : ?duration:int -> t -> string

  (** [DNAnexus.File.download file local_filename] downloads the file to the local file
      system.

      @param duration see {{: http://wiki.dnanexus.com/API-Specification-v1.0.0/Files#API-method%3A-%2Ffile-xxxx%2Fdownload } API Specification : Files : /file-xxxx/download } *)
  val download : ?duration:int -> t -> string -> unit

  (** {3 Streaming file data}

  {b See also} {{: http://ocaml-batteries-team.github.com/batteries-included/hdoc/BatIO.html } OCaml Batteries Included : IO}
  *)

  (** [DNAnexus.File.open_output file] creates an [output] you can use to write
      bytes into the file. The file must be in the open state. 

      The output stream must be closed using [Batteries.IO.close_out] when you're
      finished, which will ensure the data you write is flushed to the API server.
      However, {e closing the output stream does {b not} close the file object}.
      That is, once you've closed the output stream, it will still be necessary to
      make the [/file-xxxx/close] API call before the data can be read through the
      API. (Consider combining with {! DNAnexus.DataObject.with_new})

      It is generally not permissible to write additional data into a file that has
      already been written to by another process or [output], even if the file is
      still in the open state, or to have multiple output streams open for the same
      file. The bindings will not immediately prevent you from doing this, but the
      attempt to close the resulting file is likely to fail.

      If multiple threads will be writing to the [output], it should be protected
      using [Batteries.IO.synchronize_out]. *)
  val open_output : t -> unit Batteries.IO.output

  (** Create an [output] as in [open_output], call your function on it, and then call
      [Batteries.IO.close_out] on it (even if your function raises an exception). As
      with [open_out], the file object itself is not closed. *)
  val with_output : t -> (unit Batteries.IO.output -> 'a) -> 'a

  (** [DNAnexus.File.open_input file] creates an [input] stream you can use to read
      bytes from the file. The file must be in the closed state.

      The input stream should be closed using [Batteries.IO.close_in] when you're
      finished, which will allow internal buffers to be garbage-collected as soon as
      possible.

      It is possible to have multiple [input] streams open to the same file. If
      multiple threads will be reading from one [input], it should be protected
      using [Batteries.IO.synchronize_in].

      @param pos byte offset at which to begin reading the file (default 0) *)
  val open_input : ?duration:int -> ?pos:int -> t -> Batteries.IO.input

  (** Create an [input] as in [open_in], call your function on it, and then call
      [Batteries.IO.close_in] on it (even if your function raises an exception). *)
  val with_input : ?duration:int -> ?pos:int -> t -> (Batteries.IO.input -> 'a) -> 'a

  (** {3 Controlling parallelism and memory usage} *)

  (** The above operations each use parallel HTTP requests to maximize network
      throughput. For example, files are uploaded in 64MB parts, four parts at a
      time in parallel. This means that the upload of a large file requires at least
      256MB of memory in steady-state (realistically more, due to
      garbage-collection dynamics). Similarly, each open [output] or [input] stream
      uses 256MB of buffers by default.

      The defaults of 4 parallel requests with 67,108,864-byte buffers (64MB) can be
      changed by calling [DNAnexus.File.reconfigure] before beginning the operation
      or opening the stream. Reducing these parameters too far will negatively
      affect the data throughput you can sustain, while raising them excessively
      will cause out-of-memory problems. For uploads, the API imposes a minimum 5MB
      part size. *)
  val reconfigure : ?part_size:int -> ?parallelism:int -> t -> unit

(** GenomicTables

@see < http://wiki.dnanexus.com/API-Specification-v1.0.0/GenomicTables > API Specification : GenomicTables *)
module GTable : sig
  (** Common interface to all data objects *)
  include DataObject

  (** {3 Schema and data representation} *)

  (** {b Column specifications} *)

  (** The storage types of GTable columns *)
  type column_type = [`Bool | `UInt8 | `Int16 | `UInt16 | `Int32 | `UInt32 | `Int64 | `Float | `Double | `String]

  (** A column descriptor (specification), carrying the column name and type *)
  type column_desc = string*column_type

  (** Get an array of column descriptors for the GTable through the [/gtable-xxxx/describe] API call *)
  val columns : t -> column_desc array

  (** Create a JSON array specifying GTable columns, suitable for filling in the
      [columns] field of the JSON input to [make_new] or [with_new]. *)
  val json_of_columns : column_desc array -> JSON.t

  (** {b Index specifications} *)

  (** GTable index specifications:
      - [index_name, `GRI (chr_col_name,lo_col_name,hi_col_name)]
      - [index_name, `Lexicographic [col_name, col_order, case_sensitive; ...]]
  *)
  type index = string*[
      `GRI of string*string*string
    | `Lexicographic of (string*[`Asc|`Desc]*(bool option)) list
  ]

  (** Get a list of the GTable's indices through the [/gtable-xxxx/describe] API call *)
  val indices : t -> index list

  (** Create a JSON array specifying GTable indices, suitable for filling in the
      [indices] field of the JSON input to [make_new] or [with_new]. *)
  val json_of_indices : index list -> JSON.t

  (** {b Row data} *)

  (** GTable row data is produced and consumed as a subtype of [JSON.t] for
  convenience. Using integers or floats outside of the representable range for
  the respective column storage type will cause runtime exceptions. *)
  type datum =  [`Bool of bool | `Int of int | `Float of float | `String of string]

  type row = datum array

  val json_of_row : row -> JSON.t

  (** {3 Adding rows} *)

  (** Add one row to the GTable. The GTable must be in the open state.

      The row is immediately converted to JSON text and buffered. The buffered data
      is sent to the API server when a certain number of rows have been added (see
      below), or when [flush_rows] is called.

      @param typecheck if set to true, first typecheck the given row against the
        GTable's schema, and raise [Invalid_argument] if there's a type mismatch or
        integer out of range. This should be used mainly for development and
        debugging, as it adds significant overhead to the operation. Also, the
        API server will ultimately typecheck the row itself. *)
  val add_row : ?typecheck:bool -> t -> row -> unit

  (** Send all buffered rows to the API server immediately, and wait for them to
      finish uploading. {b Important:} you MUST call [flush_rows] when you're done
      adding rows and before closing the GTable. *)
  val flush_rows : t -> unit

  (** Call your function and then [flush_rows]. Does {e not} call [flush_rows] if
      your function raises an exception. *)
  val with_flush_rows : t -> (t -> 'a) -> 'a

  (** {3 Reading and querying} *)

  (** Get rows from the GTable in their natural order. The GTable must be in the
      closed state.

      @param starting rowid at which to begin reading the table
      @param limit on the total number of rows to return. You can set this to an
             arbitrarily large value; the bindings automatically issue multiple API
             calls as needed to paginate large result sets.
      @param columns array of the names of the columns to return *)
  val iterate_rows : ?starting:int -> ?limit:int -> ?columns:(string array) -> t -> row Batteries.Enum.t

  (** Query parameters:
      - [`GRI (chr,lo,hi,mode)]
      - [`Lexicographic [col_name, predicate, value; ...]] (a list with multiple clauses specifies a compound AND predicate)
   *)
  type query_parameters = [
    | `GRI of string*int*int*[`Overlap|`Enclose]
    | `Lexicographic of (string*[`Eq|`Gt|`Gte|`Lt|`Lte]*string) list
  ]

  (** [DNAnexus.GTable.query_rows gtable index_name parameters] performs a query
      against an index of the GTable. The GTable must be in the closed state. 
      
      @see < http://wiki.dnanexus.com/API-Specification-v1.0.0/GenomicTables#API-method%3A-%2Fgtable-xxxx%2Fget > API Specification : GenomicTables : /gtable-xxxx/get
    *)
  val query_rows : ?limit:int -> ?columns:(string array) -> t -> string -> query_parameters -> row Batteries.Enum.t

  (** {3 Controlling parallelism and memory usage} *)

  (** The above operations use parallel HTTP requests to maximize throughput.
      For example, GTable row data is uploaded in 100,000-row parts, four parts at a
      time in parallel. This means that the upload of a large GTable can require
      substantial amounts of memory. Similarly, [iterate_rows] and [query_rows] issue
      parallel requests for 100,000-row pages.

      The defaults of 4 parallel requests and pagination at 100,000 rows can be
      changed by calling [DNAnexus.GTable.reconfigure] before adding the first row or
      reading any rows. Reducing these parameters too far will negatively
      affect the data throughput you can sustain, while raising them excessively
      will make your program run out of memory. *)
  val reconfigure : ?pagination:int -> ?parallelism:int -> t -> unit

(** {2 Execution environment}

While the API above can be used both inside and outside the platform, this
section is relevant specifically for writing a DNAnexus app/applet to run on
the platform.
*)

(** A wrapper for your application logic to assist with conforming to the
input, output and error handling scheme of the DNAnexus execution environment.
- Reads and parses JSON input in the file job_input.json
- Applies your logic, a function of type [JSON.t -> JSON.t], to the input
- Stringifies and writes the JSON output to job_output.json. Your logic is
  required to provide at least an empty object ([JSON.empty]) as output.
- If your logic raises an exception, writes information to job_error.json and
  exits with non-zero status code.

@see < http://wiki.dnanexus.com/Execution-Environment-Reference#Handling-of-input%252C-output%252C-and-error-values > Execution Environment Reference : Handling of input, output, and error values
*)
val job_main : (JSON.t -> JSON.t) -> unit

(** An exception you can raise to indicate a "Recognized actionable error" *)
exception AppError of string

(** Exceptions other than [AppError] are mapped to [AppInternalError]. *)
exception AppInternalError of string

(** {b Retrieving job configuration} *)

(** Indicates whether the program is running as a job on the DNAnexus platform. *)
val is_job : unit -> bool

(** Get the current job ID.

@raise Failure if [not (is_job ())] *)
val job_id : unit -> string

(** Get the container ID of the job workspace, if available, or the project context
ID otherwise.

@raise Failure if [not (is_job ())] *)
val workspace_id : unit -> string

(** Add the key ["project": DNAnexus.workspace_id()] to the given JSON object.
Convenient for formulating JSON inputs to API calls requiring this field. *)
val with_workspace_id : JSON.t -> JSON.t

(** {b Launching subjobs} *)

(** [DNAnexus.new_job function_name input] launches a subjob using the same app or
    applet as the calling job, and sharing the same workspace. [function_name] is
    the name of a bash function in the wrapper script, which can in turn start the
    appropriate OCaml executable and/or pass command-line arguments. [input] is
    the input JSON that will be provided to the subjob.

    @param options a JSON object with any additional optional keys to set in
           the input to the [/job/new] API call (e.g. name, dependsOn,
           systemRequirements).

    @return the ID of the new job 

    @see < http://wiki.dnanexus.com/API-Specification-v1.0.0/Applets-and-Entry-Points#API-method:-/job/new > API Specification : Applets and Entry Points : /job/new *)
val new_job : ?options:JSON.t -> string -> JSON.t -> string

(** {b Job input/output JSON helpers} *)

(** Given the JSON [{"$dnanexus_link": "record-xxxx"}], extract
[(None, "record-xxxx")]. Given
[{"$dnanexus_link": {"project": "project-yyyy", "id": "record-xxxx"}}],
extract [(Some "project-yyyy", "record-xxxx")].

@see < http://wiki.dnanexus.com/API-Specification-v1.0.0/Jobs#Job-Input > API Specification : Jobs : Job Input
*)
val get_link : JSON.t -> string option*string

(** Formulate the JSON [{"$dnanexus_link": "record-xxxx"}] from ["record-xxxx"].

@param project if specified, formulate
[{"$dnanexus_link": {"project": "project-yyyy", "id": "record-xxxx"}}]

@see < http://wiki.dnanexus.com/API-Specification-v1.0.0/Jobs#Job-output > API Specification : Jobs : Job output
*)
val make_link : ?project:string -> string -> JSON.t

(** [DNAnexus.make_jobref "job-xxxx" "xyz"] formulates the JSON [{"job": "job-xxxx", "field": "xyz"}].

@see < http://wiki.dnanexus.com/API-Specification-v1.0.0/Jobs#Job-based-Object-References > API Specification : Jobs : Job-based Object References
*)
val make_jobref : string -> string -> JSON.t

(**
{b Example}

The skeleton of an app that takes a FASTQ file as input and produces a
mappings GTable as output might look like this:

{[open JSON.Operators;;

let my_app input_json =
  let file_id = DNAnexus.get_link (input_json$"fastq") in
  (* ... process the file ... *)
  let gtable_new_input = DNAnexus.with_workspace_id gtable_spec in
  let gtable_new_output = DNAnexus.api_call ["gtable"; "new"] gtable_new_input in
  let gtable_id = JSON.string (gtable_new_output$"id") in
  (* ... add rows to and close the GTable ... *)
  JSON.of_assoc ["mappings", DNAnexus.make_link gtable_id]
;;

DNAnexus.job_main my_app;;
]}
*)


(**/**)
type overcome_ocamldoc_bug_so_that_the_above_example_appears
