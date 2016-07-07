open Rrdd_plugin

module Process = Process(struct let name = "xcp-rrdd-gpumon" end)

let nvidia_vendor_id = 0x10del

let default_config : (int32 * Config.config) list =
	let open Config in [
		(* NVIDIA Corporation *)
		nvidia_vendor_id,
		{
			device_types = [
				(* GRID K1 *)
				{
					device_id = 0x0ff2l;
					subsystem_device_id = Any;
					metrics = [
						Memory Free;
						Memory Used;
						Other Temperature;
						Other PowerUsage;
						Utilisation Compute;
						Utilisation MemoryIO;
					];
				};
				(* GRID K2 *)
				{
					device_id = 0x11bfl;
					subsystem_device_id = Any;
					metrics = [
						Memory Free;
						Memory Used;
						Other Temperature;
						Other PowerUsage;
						Utilisation Compute;
						Utilisation MemoryIO;
					];
				};
			]
		}
	]

let categorise_metrics =
	List.fold_left
		(fun (memory_metrics, other_metrics, utilisation_metrics) metric ->
			match metric with
			| Config.Memory x ->
				x :: memory_metrics, other_metrics, utilisation_metrics
			| Config.Other x ->
				memory_metrics, x :: other_metrics, utilisation_metrics
			| Config.Utilisation x ->
				memory_metrics, other_metrics, x :: utilisation_metrics)
		([], [], [])

(** NVML returns the PCI ID and PCI subsystem ID as int32s, where the most
 *  significant 16 bits make up the device ID and the least significant 16 bits
 *  make up the vendor ID. This function checks that a device has a supported
 *  combination of vendor ID, device ID and, if applicable, subsystem device ID.
 *
 *  If all these IDs match, the required list of metrics for this device is
 *  returned. *)
let get_required_metrics config pci_info =
	let vendor_id = Int32.logand 0xffffl pci_info.Nvml.pci_device_id in
	let device_id = Int32.shift_right_logical pci_info.Nvml.pci_device_id 16 in
	let subsystem_device_id =
		Int32.shift_right_logical pci_info.Nvml.pci_subsystem_id 16 in
	try
		let open Config in
		let vendor_config = List.assoc vendor_id config in
		let device =
			List.find
				(fun device ->
					(* Check that the device ID matches. *)
					device.device_id = device_id &&
					(* Check that the subsystem device ID matches, if necessary. *)
					(match device.subsystem_device_id with
					| Match id -> id = subsystem_device_id
					| Any -> true))
				vendor_config.device_types
		in
		Some (categorise_metrics device.metrics)
	with Not_found -> None

let nvidia_config_path = "/usr/share/nvidia/monitoring.conf"

(** Try to load the config file; if this fails fall back to default_config.
 *  See perf-tools.hg/scripts/monitoring.conf.example for an example of the
 *  expected config file format. *)
let load_config () =
	match Config.of_file nvidia_config_path with
	| `Ok config -> [nvidia_vendor_id, config]
	| `Error `Does_not_exist ->
		Process.D.error "Config file %s not found" nvidia_config_path;
		Process.D.warn "Using default config";
		default_config
	| `Error (`Parse_failure msg) ->
		Process.D.error "Caught exception parsing config file: %s" msg;
		Process.D.warn "Using default config";
		default_config
	| `Error (`Unknown_version version) ->
		Process.D.error "Unknown config file version: %s" version;
		Process.D.warn "Using default config";
		default_config

type gpu = {
	device: Nvml.device;
	bus_id: string;
	bus_id_escaped: string;
	memory_metrics: Config.memory_metric list;
	utilisation_metrics: Config.utilisation_metric list;
	other_metrics: Config.other_metric list;
}

(* Adding colons to datasource names confuses RRD parsers, so replace all
 * colons with "/" *)
let escape_bus_id bus_id =
	String.concat "/" (Stdext.Xstringext.String.split ':' bus_id)

(** Get the list of devices recognised by NVML. *)
let get_gpus interface =
	let config = load_config () in
	let device_count = Nvml.device_get_count interface in
	let rec make_gpu_list acc index =
		if index >= 0 then begin
			let device = Nvml.device_get_handle_by_index interface index in
			let pci_info = Nvml.device_get_pci_info interface device in
			match get_required_metrics config pci_info with
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
					| Config.Free ->
						Rrd.Host,
						Ds.ds_make
							~name:("gpu_memory_free_" ^ gpu.bus_id_escaped)
							~description:"Unallocated framebuffer memory"
							~value:(Rrd.VT_Int64 memory_info.Nvml.free)
							~ty:Rrd.Gauge
							~default:false
							~units:"B" ()
					| Config.Used ->
						Rrd.Host,
						Ds.ds_make
							~name:("gpu_memory_used_" ^ gpu.bus_id_escaped)
							~description:"Allocated framebuffer memory"
							~value:(Rrd.VT_Int64 memory_info.Nvml.used)
							~ty:Rrd.Gauge
							~default:false
							~units:"B" ())
				metrics
	in
	let other_dss =
		List.map
			(function
				| Config.PowerUsage ->
					let power_usage = Nvml.device_get_power_usage interface gpu.device in
					Rrd.Host,
					Ds.ds_make
						~name:("gpu_power_usage_" ^ gpu.bus_id_escaped)
						~description:"Power usage of this GPU"
						~value:(Rrd.VT_Int64 (Int64.of_int power_usage))
						~ty:Rrd.Gauge
						~default:false
						~units:"mW" ()
				| Config.Temperature ->
					let temperature = Nvml.device_get_temperature interface gpu.device in
					Rrd.Host,
					Ds.ds_make
						~name:("gpu_temperature_" ^ gpu.bus_id_escaped)
						~description:"Temperature of this GPU"
						~value:(Rrd.VT_Int64 (Int64.of_int temperature))
						~ty:Rrd.Gauge
						~default:false
						~units:"°C" ())
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
					| Config.Compute ->
						Rrd.Host,
						Ds.ds_make
							~name:("gpu_utilisation_compute_" ^ gpu.bus_id_escaped)
							~description:("Proportion of time over the past sample period during"^
								" which one or more kernels was executing on this GPU")
							~value:(Rrd.VT_Float ((float_of_int utilization.Nvml.gpu) /. 100.0))
							~ty:Rrd.Gauge
							~default:false
							~min:0.0
							~max:1.0
							~units:"(fraction)" ()
					| Config.MemoryIO ->
						Rrd.Host,
						Ds.ds_make
							~name:("gpu_utilisation_memory_io_" ^ gpu.bus_id_escaped)
							~description:("Proportion of time over the past sample period during"^
								" which global (device) memory was being read or written on this GPU")
							~value:(Rrd.VT_Float ((float_of_int utilization.Nvml.memory) /. 100.0))
							~ty:Rrd.Gauge
							~default:false
							~min:0.0
							~max:1.0
							~units:"(fraction)" ())
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

let open_nvml_interface_noexn () =
	try Some (open_nvml_interface ())
	with e ->
		begin match e with
			| Nvml.Library_not_loaded msg ->
				Process.D.error "NVML interface not loaded: %s" msg
			| Nvml.Symbol_not_loaded msg ->
				Process.D.error "NVML missing expected symbol: %s" msg
			| e ->
				Process.D.error
					"Caught unexpected error initialising NVML: %s"
					(Printexc.to_string e)
		end;
		None

(** Shutdown and close an interface to the NVML library. *)
let close_nvml_interface interface =
	Stdext.Pervasiveext.finally
		(fun () -> Nvml.shutdown interface)
		(fun () -> Nvml.library_close interface)

let () =
	Process.initialise ();
	match open_nvml_interface_noexn () with
	| Some interface -> begin
		Process.D.info "Opened NVML interface";
		try
			let gpus = get_gpus interface in
			(* Share one page per GPU - this is plenty for the six datasources per GPU
			 * which we currently report. *)
			let shared_page_count = List.length gpus in
			Process.main_loop
				~neg_shift:0.5
				~target:(Reporter.Local shared_page_count)
				~protocol:Rrd_interface.V2
				~dss_f:(fun () -> generate_all_gpu_dss interface gpus)
		with _ ->
			close_nvml_interface interface
	end
	| None ->
		Process.D.info "Could not open NVML interface - sleeping forever";
		while true do
			Thread.delay 3600.0
		done
