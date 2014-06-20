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

val of_string : string ->
	(config, [
		| `Parse_failure of string
		| `Unknown_version of string
	]) Result.t

val of_file : string ->
	(config, [
		| `Parse_failure of string
		| `Unknown_version of string
		| `Does_not_exist
	]) Result.t

val to_string : config -> string
