open Fun

module Common = Rrdp_common.Common(struct let name = "xcp-rrdd-gpumon" end)

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

let nvidia_vendor_id = 0x10del

let default_config : (int32 * ((int32 * metric list) list)) list = [
	(* NVIDIA Corporation *)
	nvidia_vendor_id, [
		(* GRID K1 *)
		0x0ff2l, [
			Memory Free;
			Memory Used;
			Other Temperature;
			Other PowerUsage;
			Utilisation Compute;
			Utilisation MemoryIO;
		];
		(* GRID K2 *)
		0x11bfl, [
			Memory Free;
			Memory Used;
			Other Temperature;
			Other PowerUsage;
			Utilisation Compute;
			Utilisation MemoryIO;
		];
	]
]

let categorise_metrics =
	List.fold_left
		(fun (memory_metrics, other_metrics, utilisation_metrics) metric ->
			match metric with
			| Memory x ->
				x :: memory_metrics, other_metrics, utilisation_metrics
			| Other x ->
				memory_metrics, x :: other_metrics, utilisation_metrics
			| Utilisation x ->
				memory_metrics, other_metrics, x :: utilisation_metrics)
		([], [], [])

(** NVML returns the PCI ID as an int32, where the most significant 16 bits make
 *  up the device ID and the least significant 16 bits make up the vendor ID.
 *  This function checks that a PCI ID represents a supported combination of
 *  device and vendor. *)
let get_required_metrics config pci_id =
	let vendor_id = Int32.logand 0xffffl pci_id in
	let device_id = Int32.shift_right_logical pci_id 16 in
	try
		let vendor_config = List.assoc vendor_id config in
		Some (List.assoc device_id vendor_config |> categorise_metrics)
	with Not_found -> None

let nvidia_config_path = "/usr/share/nvidia/monitoring.conf"

let metric_of_rpc = function
	| Rpc.String str -> metric_of_string str
	| rpc -> raise (Invalid_argument (Rpc.to_string rpc))

let metrics_of_rpc = function
	| Rpc.Enum metrics -> List.map metric_of_rpc metrics
	| rpc -> raise (Invalid_argument (Rpc.to_string rpc))

let read_config data =
	try
		match Jsonrpc.of_string data with
		| Rpc.Dict gpu_configs -> begin
			let config = List.fold_left
				(fun acc (device_id_string, metrics_rpc) ->
					try
						let device_id = Scanf.sscanf device_id_string "%lx" (fun x -> x) in
						let metrics =
							metrics_of_rpc metrics_rpc
							|> Listext.List.setify
						in
						(device_id, metrics) :: acc
					with e ->
						acc)
				[] gpu_configs
			in
			`Ok config
		end
		| rpc -> raise (Invalid_argument (Rpc.to_string rpc))
	with e ->
		`Parse_failure (Printexc.to_string e)

let read_config_file path =
	if Sys.file_exists path then Unixext.string_of_file path |> read_config
	else `Does_not_exist

(** Try to load the config file; if this fails fall back to default_config.
 *  See perf-tools.hg/scripts/monitoring.conf.example for an example of the
 *  expected config file format. *)
let load_config () =
	match read_config_file nvidia_config_path with
	| `Ok config -> [nvidia_vendor_id, config]
	| `Does_not_exist ->
		Common.D.error "Config file %s not found" nvidia_config_path;
		Common.D.warn "Using default config";
		default_config
	| `Parse_failure msg ->
		Common.D.error "Caught exception parsing config file: %s" msg;
		Common.D.warn "Using default config";
		default_config

type gpu = {
	device: Nvml.device;
	bus_id: string;
	bus_id_escaped: string;
	memory_metrics: memory_metric list;
	utilisation_metrics: utilisation_metric list;
	other_metrics: other_metric list;
}

(* Adding colons to datasource names confuses RRD parsers, so replace all
 * colons with "/" *)
let escape_bus_id bus_id =
	String.concat "/" (Stringext.String.split ':' bus_id)

(** Get the list of devices recognised by NVML. *)
let get_gpus interface =
	let config = load_config () in
	let device_count = Nvml.device_get_count interface in
	let rec make_gpu_list acc index =
		if index >= 0 then begin
			let device = Nvml.device_get_handle_by_index interface index in
			let pci_info = Nvml.device_get_pci_info interface device in
			match get_required_metrics config pci_info.Nvml.pci_device_id with
			| Some (memory_metrics, other_metrics, utilisation_metrics) -> begin
				Nvml.device_set_persistence_mode interface device Nvml.Enabled;
				let bus_id = String.lowercase pci_info.Nvml.bus_id in
				let gpu = {
					device;
					bus_id;
					bus_id_escaped = escape_bus_id bus_id;
					memory_metrics;
					other_metrics;
					utilisation_metrics;
				} in
				make_gpu_list
					(gpu :: acc)
					(index - 1)
			end
			| None -> make_gpu_list acc (index - 1)
		end else acc
	in
	make_gpu_list [] (device_count - 1)

(** Generate datasources for one GPU. *)
let generate_gpu_dss interface gpu =
	let memory_dss =
		match gpu.memory_metrics with
		| [] -> []
		| metrics ->
			let memory_info = Nvml.device_get_memory_info interface gpu.device in
			List.map
				(function
					| Free ->
						Ds.ds_make
							~name:("gpu_memory_free_" ^ gpu.bus_id_escaped)
							~description:"Unallocated framebuffer memory"
							~value:(Rrd.VT_Int64 memory_info.Nvml.free)
							~ty:Rrd.Gauge
							~default:false
							~units:"B" (),
						Rrd.Host
					| Used ->
						Ds.ds_make
							~name:("gpu_memory_used_" ^ gpu.bus_id_escaped)
							~description:"Allocated framebuffer memory"
							~value:(Rrd.VT_Int64 memory_info.Nvml.used)
							~ty:Rrd.Gauge
							~default:false
							~units:"B" (),
						Rrd.Host)
				metrics
	in
	let other_dss =
		List.map
			(function
				| PowerUsage ->
					let power_usage = Nvml.device_get_power_usage interface gpu.device in
					Ds.ds_make
						~name:("gpu_power_usage_" ^ gpu.bus_id_escaped)
						~description:"Power usage of this GPU"
						~value:(Rrd.VT_Int64 (Int64.of_int power_usage))
						~ty:Rrd.Gauge
						~default:false
						~units:"mW" (),
					Rrd.Host
				| Temperature ->
					let temperature = Nvml.device_get_temperature interface gpu.device in
					Ds.ds_make
						~name:("gpu_temperature_" ^ gpu.bus_id_escaped)
						~description:"Temperature of this GPU"
						~value:(Rrd.VT_Int64 (Int64.of_int temperature))
						~ty:Rrd.Gauge
						~default:false
						~units:"°C" (),
					Rrd.Host)
			gpu.other_metrics
	in
	let utilisation_dss =
		match gpu.utilisation_metrics with
		| [] -> []
		| metrics ->
			let utilization =
				Nvml.device_get_utilization_rates interface gpu.device in
			List.map
				(function
					| Compute ->
						Ds.ds_make
							~name:("gpu_utilisation_compute_" ^ gpu.bus_id_escaped)
							~description:("Proportion of time over the past sample period during"^
								" which one or more kernels was executing on this GPU")
							~value:(Rrd.VT_Float ((float_of_int utilization.Nvml.gpu) /. 100.0))
							~ty:Rrd.Gauge
							~default:false
							~min:0.0
							~max:1.0
							~units:"(fraction)" (),
						Rrd.Host
					| MemoryIO ->
						Ds.ds_make
							~name:("gpu_utilisation_memory_io_" ^ gpu.bus_id_escaped)
							~description:("Proportion of time over the past sample period during"^
								" which global (device) memory was being read or written on this GPU")
							~value:(Rrd.VT_Float ((float_of_int utilization.Nvml.memory) /. 100.0))
							~ty:Rrd.Gauge
							~default:false
							~min:0.0
							~max:1.0
							~units:"(fraction)" (),
						Rrd.Host)
				metrics
	in
	List.fold_left
		(fun acc metrics -> List.rev_append metrics acc)
		[] [memory_dss; other_dss; utilisation_dss]

(** Generate datasources for all GPUs. *)
let generate_all_gpu_dss interface gpus =
	List.fold_left
		(fun acc gpu ->
			let dss = generate_gpu_dss interface gpu in
			List.rev_append dss acc)
		[] gpus

(** Open and initialise an interface to the NVML library. Close the library if
 *  initialisation fails. *)
let open_nvml_interface () =
	let interface = Nvml.library_open () in
	try
		Nvml.init interface;
		interface
	with e ->
		Nvml.library_close interface;
		raise e

(** Shutdown and close an interface to the NVML library. *)
let close_nvml_interface interface =
	Pervasiveext.finally
		(fun () -> Nvml.shutdown interface)
		(fun () -> Nvml.library_close interface)

let () =
	Common.initialise ();
	(* Try to open an interface to NVML. If this fails for an expected reason,
	 * log the error, wait 5 minutes, then try again. *)
	let interface =
		let rec open_if () =
			try open_nvml_interface ()
			with e ->
				begin match e with
					| Nvml.Library_not_loaded msg ->
						Common.D.warn "NVML interface not loaded: %s" msg
					| Nvml.Symbol_not_loaded msg ->
						Common.D.warn "NVML missing expected symbol: %s" msg
					| e ->
						(* This could just be that the NVIDIA driver is not running on
						 * any devices; in this case NVML throws NVML_ERROR_UNKNOWN. *)
						Common.D.warn
							"Caught unexpected error initialising NVML: %s"
							(Printexc.to_string e);
				end;
				Common.D.info "Sleeping for 5 minutes";
				Thread.delay 300.0;
				open_if ()
		in
		open_if ()
	in
	Common.D.info "Opened NVML interface";
	try
		let gpus = get_gpus interface in
		Common.main_loop
			~dss_f:(fun () -> generate_all_gpu_dss interface gpus)
			~neg_shift:0.5
	with _ ->
		close_nvml_interface interface
