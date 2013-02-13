(* Simple thread pool for long-running, probably I/O-bound operations.
    Used by File and GTable for parallel API/HTTP requests *)

open Batteries

let fresh_id =
  let id = ref 0
  BatteriesThread.Mutex.synchronize
    fun () ->
      id := !id + 1
      !id


type 'a iou = int
type 'a result = [`Ans of 'a | `Exn of exn]

type 'a t = {
  maxthreads : int;
  mutable pending : ('a iou) Set.t;
  mutable results : (('a iou),('a result)) Map.t;
  thread_finished : Condition.t;
  lock : Mutex.t;
  with_lock : 'b 'c . ('b -> 'c) -> 'b -> 'c
}

(* Make a new thread pool, with the specified maximum number of concurrent threads *)
let make ?(maxthreads=4) () =
  let lock = Mutex.create ()
  {
    maxthreads;
    pending = Set.empty;
    results = Map.empty;
    thread_finished = Condition.create ();
    lock;
    with_lock = (fun f x -> BatteriesThread.Mutex.synchronize ~lock:lock f x)
  }

(* Launch a thread in the pool to evaulate (f x). Returns an [iou] that can be
    used to retrieve the result later. If the thread pool is full ([maxthreads]
    operations in progress), the calling thread is blocked until the new job
    can be launched. 

    Warning: [ThreadPool] was not designed to accommodate the possibility of
    worker threads themselves launching jobs or retrieving reults from the
    thread pool. *)
let launch p f x =
  let iou = fresh_id ()

  let executor () =
    let y = try `Ans (f x) with exn -> `Exn exn
    () |> p.with_lock
      fun () ->
        p.pending <- Set.remove iou p.pending
        p.results <- Map.add iou y p.results
        Condition.broadcast p.thread_finished

  () |> p.with_lock
    fun () ->      
      while Set.cardinal p.pending >= p.maxthreads do
        Condition.wait p.thread_finished p.lock
      p.pending <- Set.add iou p.pending
      ignore (Thread.create executor ())
      iou


let result_impl ?(rm=false) p iou =
  if Set.mem iou p.pending then None
  else
    let ans = Map.find iou p.results
    if rm then p.results <- Map.remove iou p.results
    Some ans

(* Query for the result of a thread from an [iou].

    @return [None] if the thread is still running, [Some (`Ans y)] with a
            successful result, or [Some (`Exn exn)] if the thread raised an
            exception.
    @param rm if true, 'forget' the result before returning it. Future calls
           with the same [iou] would raise [Not_found]. If the result is
           never removed then it can never be garbage-collected. No effect if
           the result is not yet available. Default: false
    @raise Not_found if [iou] is unknown
*)
let result ?rm p iou = p.with_lock (fun () -> result_impl ?rm p iou) ()

(* Get the result of a thread from an [iou], blocking the calling thread until
    the thread is complete.

    @return [`Ans y] with a successful result, or [`Exn exn] if the thread
            raised an exception.
    @param rm if true, 'forget' the result before returning it. Future calls
           with the same [iou] would raise [Not_found]. If the result is
           never removed then it can never be garbage-collected. Default: false
*)
let await_result ?rm p iou =
  let rec loop () =
    match result_impl ?rm p iou with
      | Some ans -> ans
      | None ->
        Condition.wait p.thread_finished p.lock
        loop ()
  p.with_lock loop ()

let any_result_impl ?(rm=false) p =
  try
    let ((iou,_) as ans) = Map.choose p.results
    if rm then p.results <- Map.remove iou p.results
    Some ans
  with Not_found -> None

(* Query for any available result from the thread pool. If [rm] is false,
    repeated calls may return the same result. *)
let any_result ?rm p = p.with_lock (fun () -> any_result_impl ?rm p) ()

(* Get any result from the thread pool, blocking the calling thread until
    one is available.

    @raise Failure if no results are available and no threads are running,
           unless [really = true] *)
let await_any_result ?rm ?(really=false) p =
  let rec loop () =
    match any_result_impl ?rm p with
      | Some ans -> ans
      | None ->
        if Set.cardinal p.pending = 0 && not really then failwith "ThreadPool.await_any_result: pool is idle"
        Condition.wait p.thread_finished p.lock
        loop ()
  p.with_lock loop ()

(* Block the calling thread until all worker threads are done. *)
let drain p =
  () |> p.with_lock
    fun () ->
      while Set.cardinal p.pending > 0 do
        Condition.wait p.thread_finished p.lock

