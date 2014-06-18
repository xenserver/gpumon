open Fun

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
	match String.lowercase str with
	| "memoryfree" -> Memory Free
	| "memoryused" -> Memory Used
	| "temperature" -> Other Temperature
	| "powerusage" -> Other PowerUsage
	| "compute" -> Utilisation Compute
	| "memoryio" -> Utilisation MemoryIO
	| _ -> raise (Invalid_argument str)

let string_of_metric = function
	| Memory Free -> "memoryfree"
	| Memory Used -> "memoryused"
	| Other Temperature -> "temperature"
	| Other PowerUsage -> "powerusage"
	| Utilisation Compute -> "compute"
	| Utilisation MemoryIO -> "memoryio"

let metric_of_rpc = function
	| Rpc.String str -> metric_of_string str
	| rpc -> raise (Invalid_argument (Rpc.to_string rpc))

let metrics_of_rpc = function
	| Rpc.Enum metrics -> List.map metric_of_rpc metrics
	| rpc -> raise (Invalid_argument (Rpc.to_string rpc))

let rpc_of_metric metric = Rpc.String (string_of_metric metric)

let rpc_of_metrics metrics = Rpc.Enum (List.map rpc_of_metric metrics)

type device_type = {
	device_id: int32;
	metrics: metric list;
}

type config = {
	device_types: device_type list;
}

let of_rpc = function
	| Rpc.Dict gpu_configs -> begin
		let config = List.fold_left
			(fun acc (device_id_string, metrics_rpc) ->
				try
					let device_id = Scanf.sscanf device_id_string "%lx" (fun x -> x) in
					let metrics =
						metrics_of_rpc metrics_rpc
						|> Listext.List.setify
					in
					{device_id; metrics} :: acc
				with e ->
					acc)
			[] gpu_configs
		in
		`Ok {device_types = (List.rev config)}
	end
	| _ -> `Parse_failure "No top-level dictionary"

let of_string data =
	try Jsonrpc.of_string data |> of_rpc
	with e -> `Parse_failure (Printexc.to_string e)

let of_file path =
	if Sys.file_exists path then Unixext.string_of_file path |> of_string
	else `Does_not_exist

let to_string config =
	Rpc.Dict
		(List.map
			(fun {device_id; metrics} ->
				Printf.sprintf "%04lx" device_id,
				rpc_of_metrics metrics)
			config.device_types)
	|> Jsonrpc.to_string
