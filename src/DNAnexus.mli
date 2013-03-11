(** Bindings to the DNAnexus API, using libcurl for HTTP operations and
{{: https://github.com/mlin/yajl-ocaml} yajl-ocaml} for JSON processing.

Note on parallelism: some parts of the bindings (especially File and GTable
operations) use multiple threads to perform parallel HTTP requests. If your
program will use [fork()], it's inadvisable to do so while such operations are
in progress.

@see < http://wiki.dnanexus.com/ > DNAnexus Documentation Wiki
@see < http://mlin.github.com/yajl-ocaml/extra/JSON.html > yajl-ocaml JSON API
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

@param retry (default: true) Retry the request should it fail due to
potentially intermittent errors. If retry is enabled, then by default:

- The request will be retried up to 5 times
- There is a delay of one second before the first retry
- The delay increases by a factor of two on each subsequent retry
- Each retry attempt, and the eventual success, is logged to standard error

These defaults can be changed using [reconfigure] (above). If all retry
attempts fail, then the exception raised on the {e last} attempt is
re-raised.

@raise APIError for error responses returned by the DNAnexus API server; also,
various other exceptions that can arise in the course of attempting an HTTP
request (especially [CurlException]).
*)
val api_call : ?retry:bool -> string list -> JSON.t -> JSON.t

(** Exception representing errors returned by the DNAnexus API server. Carries
the error type, message, and "details" JSON (which can be [`Null])

@see < http://wiki.dnanexus.com/API-Specification-v1.0.0/Protocols#Errors > API Specification : Protocols : Errors
*)
exception APIError of string*string*JSON.t

(** {2 Records, files, and GTables} *)

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
      - [index_name, `Lexicographic [col_name, col_order; ...]]
  *)
  type index = string*[
      `GRI of string*string*string
    | `Lexicographic of (string*[`Asc|`Desc]) list
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
