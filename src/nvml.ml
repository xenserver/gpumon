exception Library_not_loaded of string
exception Symbol_not_loaded of string

type interface

type device

type enable_state =
	| Disabled
	| Enabled

type memory_info = {
	total: int64;
	free: int64;
	used: int64;
}

type pci_info = {
	bus_id: string;
	domain: int32;
	bus: int32;
	device: int32;
	pci_device_id: int32;
	pci_subsystem_id: int32;
}

type utilization = {
	gpu: int;
	memory: int;
}

external library_open: unit -> interface = "stub_nvml_open"
let library_open () =
	Callback.register_exception "Library_not_loaded" (Library_not_loaded "");
	Callback.register_exception "Symbol_not_loaded" (Symbol_not_loaded "");
	library_open ();

external library_close: interface -> unit = "stub_nvml_close"

external init: interface -> unit = "stub_nvml_init"
external shutdown: interface -> unit = "stub_nvml_shutdown"

external device_get_count: interface -> int = "stub_nvml_device_get_count"
external device_get_handle_by_index: interface -> int -> device =
	"stub_nvml_device_get_handle_by_index"
external device_get_memory_info: interface -> device -> memory_info =
	"stub_nvml_device_get_memory_info"
external device_get_pci_info: interface -> device -> pci_info =
	"stub_nvml_device_get_pci_info"
external device_get_temperature: interface -> device -> int =
	"stub_nvml_device_get_temperature"
external device_get_power_usage: interface -> device -> int =
	"stub_nvml_device_get_power_usage"
external device_get_utilization_rates: interface -> device -> utilization =
	"stub_nvml_device_get_utilization_rates"

external device_set_persistence_mode: interface -> device -> enable_state ->
	unit =
	"stub_nvml_device_set_persistence_mode"
