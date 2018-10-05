exception Library_not_loaded of string

exception Symbol_not_loaded of string

type interface = unit

type device = unit

type enable_state = Disabled | Enabled

type memory_info = {total: int64; free: int64; used: int64}

type pci_info =
  { bus_id: string
  ; domain: int32
  ; bus: int32
  ; device: int32
  ; pci_device_id: int32
  ; pci_subsystem_id: int32 }

type utilization = {gpu: int; memory: int}

let memory_info = {total= 0L; free= 0L; used= 0L}

let pci_info =
  { bus_id= ""
  ; domain= 0l
  ; bus= 0l
  ; device= 0l
  ; pci_device_id= 0l
  ; pci_subsystem_id= 0l }

let utilization = {gpu= 0; memory= 0}

type pgpu_metadata = string

type vgpu_metadata = string

type vgpu_instance = int

type vm_domid = string

type vgpu_compatibility_t = unit

type vm_compat = None | Cold | Hybernate | Sleep | Live

type pgpu_compat_limit = None | HostDriver | GuestDriver | GPU | Other

let library_open () = ()

let library_close () = ()

let init () = ()

let shutdown () = ()

let device_get_count _interface = 0

let device_get_handle_by_index _interface _int = ()

let device_get_handle_by_pci_bus_id _interface _string = ()

let device_get_memory_info _interface _device = memory_info

let device_get_pci_info _interface _device = pci_info

let device_get_temperature _interface _device = 0

let device_get_power_usage _interface _device = 0

let device_get_utilization_rates _interface _device = utilization

let device_set_persistence_mode _interface _device _enable_state = ()

let device_get_pgpu_metadata _interface _device = ""

let pgpu_metadata_get_pgpu_version _pgpu_metadata = 0

let pgpu_metadata_get_pgpu_revision _pgpu_metadata = 0

let pgpu_metadata_get_pgpu_host_driver_version _pgpu_metadata = ""

let device_get_active_vgpus _interface _device = []

let vgpu_instance_get_vm_domid _interface _vgpu_instance = ""

let get_vgpu_metadata _interface _vgpu_instance = ""

let get_pgpu_vgpu_compatibility _interface _vgpu_metadata _pgpu_metadata = ()

let vgpu_compat_get_vm_compat _vgpu_compatibility_t = []

let vgpu_compat_get_pgpu_compat_limit _vgpu_compatibility_t = []

let get_vgpus_for_vm _iface _device _vm_domid = []
