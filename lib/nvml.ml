exception Library_not_loaded of string

exception Symbol_not_loaded of string

type interface

type device

type enable_state = Disabled | Enabled

type memory_info = {total: int64; free: int64; used: int64}

type pci_info = {
    bus_id: string  (** domain:bus:device.function PCI identifier *)
  ; domain: int32
  ; bus: int32
  ; device: int32
  ; pci_device_id: int32
  ; pci_subsystem_id: int32
}

type utilization = {gpu: int; memory: int}

type pgpu_metadata = string

type vgpu_metadata = string

type vgpu_instance = int

type vm_domid = string

type vgpu_uuid = string

type vgpu_compatibility_t

type vm_compat = None | Cold | Hybernate | Sleep | Live

type pgpu_compat_limit = None | HostDriver | GuestDriver | GPU | Other

external library_open : unit -> interface = "stub_nvml_open"

let library_open () =
  Callback.register_exception "Library_not_loaded" (Library_not_loaded "") ;
  Callback.register_exception "Symbol_not_loaded" (Symbol_not_loaded "") ;
  library_open ()

external library_close : interface -> unit = "stub_nvml_close"

external init : interface -> unit = "stub_nvml_init"

external shutdown : interface -> unit = "stub_nvml_shutdown"

external device_get_count : interface -> int = "stub_nvml_device_get_count"

external device_get_handle_by_index : interface -> int -> device
  = "stub_nvml_device_get_handle_by_index"

external device_get_handle_by_pci_bus_id : interface -> string -> device
  = "stub_nvml_device_get_handle_by_pci_bus_id"

external device_get_memory_info : interface -> device -> memory_info
  = "stub_nvml_device_get_memory_info"

external device_get_pci_info : interface -> device -> pci_info
  = "stub_nvml_device_get_pci_info"

external device_get_temperature : interface -> device -> int
  = "stub_nvml_device_get_temperature"

external device_get_power_usage : interface -> device -> int
  = "stub_nvml_device_get_power_usage"

external device_get_utilization_rates : interface -> device -> utilization
  = "stub_nvml_device_get_utilization_rates"

external device_set_persistence_mode :
  interface -> device -> enable_state -> unit
  = "stub_nvml_device_set_persistence_mode"

external device_get_pgpu_metadata : interface -> device -> pgpu_metadata
  = "stub_nvml_device_get_pgpu_metadata"

external pgpu_metadata_get_pgpu_version : pgpu_metadata -> int
  = "stub_pgpu_metadata_get_pgpu_version"

external pgpu_metadata_get_pgpu_revision : pgpu_metadata -> int
  = "stub_pgpu_metadata_get_pgpu_revision"

external pgpu_metadata_get_pgpu_host_driver_version : pgpu_metadata -> string
  = "stub_pgpu_metadata_get_pgpu_host_driver_version"

external device_get_active_vgpus : interface -> device -> vgpu_instance list
  = "stub_nvml_device_get_active_vgpus"

external vgpu_instance_get_vm_domid : interface -> vgpu_instance -> vm_domid
  = "stub_nvml_vgpu_instance_get_vm_id"

external vgpu_instance_get_vgpu_uuid : interface -> vgpu_instance -> vgpu_uuid
  = "stub_nvml_vgpu_instance_get_vgpu_uuid"

external get_vgpu_metadata : interface -> vgpu_instance -> vgpu_metadata
  = "stub_nvml_get_vgpu_metadata"

external get_pgpu_vgpu_compatibility :
  interface -> vgpu_metadata -> pgpu_metadata -> vgpu_compatibility_t
  = "stub_nvml_get_pgpu_vgpu_compatibility"

external vgpu_compat_get_vm_compat : vgpu_compatibility_t -> vm_compat list
  = "stub_vgpu_compat_get_vm_compat"

external vgpu_compat_get_pgpu_compat_limit :
  vgpu_compatibility_t -> pgpu_compat_limit list
  = "stub_vgpu_compat_get_pgpu_compat_limit"

(* The functions below could raise any of the nvml errors raised from the stubs *)
let get_vgpus_for_vm iface device vm_domid =
  let vgpus = device_get_active_vgpus iface device in
  List.filter_map
    (fun vgpu ->
      match vgpu_instance_get_vm_domid iface vgpu with
      | domid when domid = vm_domid ->
          Some vgpu
      | _ ->
          None
    )
    vgpus

let get_vgpu_for_uuid iface vgpu_uuid vgpus =
  List.filter_map
    (fun vgpu ->
      match vgpu_instance_get_vgpu_uuid iface vgpu with
      | uuid when uuid = vgpu_uuid ->
          Some vgpu
      | _ ->
          None
    )
    vgpus

(* mock implementation *)
module NVML = struct
  let attach () = ()

  let detach () = ()

  let is_attached () = true

  let get () : interface option = None
end
