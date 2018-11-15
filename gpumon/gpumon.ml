
open Rrdd_plugin

let plugin_name = "xcp-rrdd-gpumon"

module Process = Process(struct let name = plugin_name end)

let nvidia_vendor_id = 0x10del

let default_config : (int32 * Gpumon_config.config) list =
  let open Gpumon_config in [
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
       | Gpumon_config.Memory x ->
         x :: memory_metrics, other_metrics, utilisation_metrics
       | Gpumon_config.Other x ->
         memory_metrics, x :: other_metrics, utilisation_metrics
       | Gpumon_config.Utilisation x ->
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
    let open Gpumon_config in
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
  let open Rresult in
  match Gpumon_config.of_file nvidia_config_path with
  | Ok config -> [nvidia_vendor_id, config]
  | Error `Does_not_exist ->
    Process.D.error "Config file %s not found" nvidia_config_path;
    Process.D.warn "Using default config";
    default_config
  | Error (`Parse_failure msg) ->
    Process.D.error "Caught exception parsing config file: %s" msg;
    Process.D.warn "Using default config";
    default_config
  | Error (`Unknown_version version) ->
    Process.D.error "Unknown config file version: %s" version;
    Process.D.warn "Using default config";
    default_config

type gpu = {
  device: Nvml.device;
  bus_id: string;
  bus_id_escaped: string;
  memory_metrics: Gpumon_config.memory_metric list;
  utilisation_metrics: Gpumon_config.utilisation_metric list;
  other_metrics: Gpumon_config.other_metric list;
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
          let bus_id = String.lowercase_ascii pci_info.Nvml.bus_id in
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
          | Gpumon_config.Free ->
            Rrd.Host,
            Ds.ds_make
              ~name:("gpu_memory_free_" ^ gpu.bus_id_escaped)
              ~description:"Unallocated framebuffer memory"
              ~value:(Rrd.VT_Int64 memory_info.Nvml.free)
              ~ty:Rrd.Gauge
              ~default:false
              ~units:"B" ()
          | Gpumon_config.Used ->
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
        | Gpumon_config.PowerUsage ->
          let power_usage = Nvml.device_get_power_usage interface gpu.device in
          Rrd.Host,
          Ds.ds_make
            ~name:("gpu_power_usage_" ^ gpu.bus_id_escaped)
            ~description:"Power usage of this GPU"
            ~value:(Rrd.VT_Int64 (Int64.of_int power_usage))
            ~ty:Rrd.Gauge
            ~default:false
            ~units:"mW" ()
        | Gpumon_config.Temperature ->
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
          | Gpumon_config.Compute ->
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
          | Gpumon_config.MemoryIO ->
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

let start server =
  let (_: Thread.t) = Thread.create (fun () ->
      Xcp_service.serve_forever server
    ) () in
  ()

let handle_shutdown handler () =
  Sys.set_signal Sys.sigterm (Sys.Signal_handle handler);
  Sys.set_signal Sys.sigint  (Sys.Signal_handle handler);
  Sys.set_signal Sys.sigpipe Sys.Signal_ignore


(* PPX-based server generation *)
module Server = Gpumon_interface.RPC_API(Idl.Exn.GenServer ())

(* Provide server API calls *)
module Make(Impl : Gpumon_server.IMPLEMENTATION) = struct

  (* bind server method declarations to implementations *)
  let bind () =
    Server.Nvidia.get_pgpu_metadata           Impl.Nvidia.get_pgpu_metadata           ;
    Server.Nvidia.get_vgpu_metadata           Impl.Nvidia.get_vgpu_metadata           ;
    Server.Nvidia.get_pgpu_vgpu_compatibility Impl.Nvidia.get_pgpu_vgpu_compatibility ;
    Server.Nvidia.get_pgpu_vm_compatibility   Impl.Nvidia.get_pgpu_vm_compatibility
end

let () =
  Process.initialise ();
  let maybe_interface = open_nvml_interface_noexn () in

  (* Define the new signal handler *)
  let stop_handler signal =
    let _ = match maybe_interface with
      | Some interface -> close_nvml_interface interface
      | None -> ()
    in
    Process.D.info "Received signal %d: deregistering plugin %s..." signal plugin_name;
    exit 0
  in
  let module Gpumon_server = Gpumon_server.Make(struct
      let interface = maybe_interface
    end) in
  (* create daemon module to bind server call declarations to implementations *)
  let module Daemon = Make(Gpumon_server) in
  Daemon.bind ();

  let server = Xcp_service.make
      ~path:Gpumon_interface.xml_path
      ~queue_name:Gpumon_interface.queue_name
      ~rpc_fn:(Idl.Exn.server Server.implementation)
      ()
  in
  let _ = (handle_shutdown stop_handler (); start server) in

  (* gpumon rrdd interface *)
  let rec rrdd_loop interface =
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
    with e -> begin
        Process.D.error "Unexpected exception: %s" (Printexc.to_string e);
        Thread.delay 5.0;
        rrdd_loop interface
      end
  in

  match maybe_interface with
  | Some interface -> begin
      Process.D.info "Opened NVML interface";
      rrdd_loop interface
    end
  | None ->
    Process.D.info "Could not open NVML interface - sleeping forever";
    while true do
      Thread.delay 3600.0
    done
