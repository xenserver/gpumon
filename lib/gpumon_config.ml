open Stdext
open Rresult

(** Like List.map, but will return an Error if and when f returns an Error. *)
let bind_map f items =
  let rec aux acc = function
    | item :: rest -> (f item) >>= (fun result -> aux (result :: acc) rest)
    | [] -> Ok (List.rev acc)
  in
  aux [] items

(* Metrics which require calling nvmlDeviceGetMemoryInfo *)
type memory_metric =
  | Free
  | Used

(* Metrics which have their own NVML calls. *)
type other_metric =
  | PowerUsage
  | Temperature

(* Metrics which require calling nvmlDeviceGetUtilizationRates *)
type utilisation_metric =
  | Compute
  | MemoryIO

type metric =
  | Memory of memory_metric
  | Utilisation of utilisation_metric
  | Other of other_metric

let metric_of_string str =
  match String.lowercase_ascii str with
  | "memoryfree" -> Ok (Memory Free)
  | "memoryused" -> Ok (Memory Used)
  | "temperature" -> Ok (Other Temperature)
  | "powerusage" -> Ok (Other PowerUsage)
  | "compute" -> Ok (Utilisation Compute)
  | "memoryio" -> Ok (Utilisation MemoryIO)
  | _ -> Error (`Parse_failure str)

let string_of_metric = function
  | Memory Free -> "memoryfree"
  | Memory Used -> "memoryused"
  | Other Temperature -> "temperature"
  | Other PowerUsage -> "powerusage"
  | Utilisation Compute -> "compute"
  | Utilisation MemoryIO -> "memoryio"

let metric_of_rpc = function
  | Rpc.String str -> metric_of_string str
  | rpc -> Error (`Parse_failure (Rpc.to_string rpc))

let metrics_of_rpc = function
  | Rpc.Enum metrics_rpc -> bind_map metric_of_rpc metrics_rpc
  | rpc -> Error (`Parse_failure (Rpc.to_string rpc))

let rpc_of_metric metric = Rpc.String (string_of_metric metric)

let rpc_of_metrics metrics = Rpc.Enum (List.map rpc_of_metric metrics)

type 'a requirement =
  | Match of 'a
  | Any

type device_type = {
  device_id: int32;
  subsystem_device_id: int32 requirement;
  metrics: metric list;
}

type config = {
  device_types: device_type list;
}

type config_version =
  | V1
  | V2

let version_of_dict dict =
  let version_key = "version" in
  if List.mem_assoc version_key dict then begin
    match List.assoc version_key dict with
    | Rpc.String "2" -> Ok V2
    | rpc -> Error (`Unknown_version (Jsonrpc.to_string rpc))
  end else
    Ok V1

let unbox_string = function
  | Rpc.String str -> Ok str
  | rpc -> Error (`Parse_failure (Jsonrpc.to_string rpc))

let _unbox_enum = function
  | Rpc.Enum enum -> Ok enum
  | rpc -> Error (`Parse_failure (Jsonrpc.to_string rpc))

let lookup key dict =
  try Ok (List.assoc key dict)
  with Not_found -> Error (`Parse_failure (Rpc.Dict dict |> Jsonrpc.to_string))

let id_of_string str =
  try Ok (Scanf.sscanf str "%lx" (fun x -> x))
  with Scanf.Scan_failure _ -> Error (`Parse_failure str)

let of_v1_format dict =
  bind_map
    (fun (device_id_string, metrics_rpc) ->
       (* Try to read the device ID. *)
       (id_of_string device_id_string)
       (* Try to read the list of metrics. *)
       >>= (fun device_id ->
           metrics_of_rpc metrics_rpc
           (* Return the constructed device type.
              			 * n.b. The V1 format doesn't support specifying a subsystem device ID. *)
           >>= (fun metrics ->
               Ok {
                 device_id;
                 subsystem_device_id = Any;
                 metrics;
               })))
    dict
  >>| (fun device_types -> {device_types})

let device_type_of_v2_format = function
  | Rpc.Dict dict -> begin
      (* Try to read the device ID. *)
      (lookup "device_id" dict >>= unbox_string >>= id_of_string)
      (* Try to read the subsystem device ID. If it's not in the dictionary then
         		 * assume we don't need to match it. *)
      >>= (fun device_id ->
          (if List.mem_assoc "subsystem_device_id" dict
           then
             (List.assoc "subsystem_device_id" dict |> unbox_string >>= id_of_string)
             >>= (fun id -> Ok (Match id))
           else Ok Any)
          (* Try to read the list of metrics. *)
          >>= (fun subsystem_device_id ->
              (lookup "metrics" dict >>= metrics_of_rpc)
              (* Return the constructed device type. *)
              >>= (fun metrics ->
                  Ok {
                    device_id;
                    subsystem_device_id;
                    metrics;
                  })))
    end
  | rpc -> Error (`Parse_failure (Jsonrpc.to_string rpc))

let device_types_of_v2_format = function
  | Rpc.Enum items -> bind_map device_type_of_v2_format items
  | rpc -> Error (`Parse_failure (Jsonrpc.to_string rpc))

let of_v2_format dict =
  lookup "device_types" dict
  >>= device_types_of_v2_format
  >>= (fun device_types -> Ok {device_types})

let of_rpc = function
  | Rpc.Dict dict ->
    version_of_dict dict
    >>= (function
        | V1 -> of_v1_format dict
        | V2 -> of_v2_format dict)
  | _ -> Error (`Parse_failure "No top-level dictionary")

let of_string data =
  (try Ok (Jsonrpc.of_string data)
   with e -> Error (`Parse_failure (Printexc.to_string e)))
  >>= of_rpc

let of_file path =
  if Sys.file_exists path then Unixext.string_of_file path |> of_string
  else Error `Does_not_exist

let to_string config =
  Rpc.Dict
    (List.map
       (fun {device_id; metrics; _} ->
          Printf.sprintf "%04lx" device_id,
          rpc_of_metrics metrics)
       config.device_types)
  |> Jsonrpc.to_string
