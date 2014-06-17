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

type config = ((int32 * metric list) list)

val of_string : string -> [`Ok of config | `Parse_failure of string]

val of_file : string ->
	[`Ok of config | `Parse_failure of string | `Does_not_exist]

val to_string : config -> string
