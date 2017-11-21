#include <dlfcn.h>

#include <nvml.h>
#include <nvml_grid.h>

#include <string.h>

#include <caml/alloc.h>
#include <caml/callback.h>
#include <caml/fail.h>
#include <caml/memory.h>
#include <caml/signals.h>

typedef struct nvmlInterface {
    void* handle;
    char* (*errorString)(nvmlReturn_t);
    nvmlReturn_t (*init)(void);
    nvmlReturn_t (*shutdown)(void);
    nvmlReturn_t (*deviceGetCount)(unsigned int*);
    nvmlReturn_t (*deviceGetHandleByIndex)(unsigned int, nvmlDevice_t*);
    nvmlReturn_t (*deviceGetHandleByPciBusId)(const char*, nvmlDevice_t*);
    nvmlReturn_t (*deviceGetMemoryInfo)(nvmlDevice_t, nvmlMemory_t*);
    nvmlReturn_t (*deviceGetPciInfo)(nvmlDevice_t, nvmlPciInfo_t*);
    nvmlReturn_t (*deviceGetTemperature)
        (nvmlDevice_t, nvmlTemperatureSensors_t, unsigned int*);
    nvmlReturn_t (*deviceGetPowerUsage)(nvmlDevice_t, unsigned int*);
    nvmlReturn_t (*deviceGetUtilizationRates)(nvmlDevice_t, nvmlUtilization_t*);

    nvmlReturn_t (*deviceSetPersistenceMode)(nvmlDevice_t, nvmlEnableState_t);
    
    nvmlReturn_t (*deviceGetVgpuMetadata)(nvmlDevice_t, nvmlVgpuPgpuMetadata_t*, unsigned int*);
    nvmlReturn_t (*vgpuInstanceGetMetadata)(nvmlVgpuInstance_t, nvmlVgpuMetadata_t*, unsigned int*);
    nvmlReturn_t (*deviceGetActiveVgpus)(nvmlDevice_t, unsigned int*, nvmlVgpuInstance_t*);
    nvmlReturn_t (*vgpuInstanceGetVmID)(nvmlVgpuInstance_t, char*, unsigned int, nvmlVgpuVmIdType_t*);
    nvmlReturn_t (*getVgpuCompatibility)(nvmlVgpuMetadata_t*, nvmlVgpuPgpuMetadata_t*, nvmlVgpuPgpuCompatibility_t*);
} nvmlInterface;

CAMLprim value stub_nvml_open(value unit) {
    CAMLparam1(unit);
    CAMLlocal1(ml_interface);

    nvmlInterface *interface;
    value *exn;

    interface = malloc(sizeof(nvmlInterface));

    // Open the library.
    interface->handle = dlopen("libnvidia-ml.so.1", RTLD_LAZY);
    if (!interface->handle) {
        free(interface);
        exn = caml_named_value("Library_not_loaded");
        if (exn) {
            caml_raise_with_string(*exn, dlerror());
        }
        else {
            caml_failwith(dlerror());
        }
    }

    // Load nvmlErrorString.
    interface->errorString = dlsym(interface->handle, "nvmlErrorString");
    if (!interface->errorString) {
        goto SymbolError;
    }

    // Load nvmlInit.
    interface->init = dlsym(interface->handle, "nvmlInit");
    if (!interface->init) {
        goto SymbolError;
    }

    // Load nvmlShutdown.
    interface->shutdown = dlsym(interface->handle, "nvmlShutdown");
    if (!interface->shutdown) {
        goto SymbolError;
    }

    // Load nvmlDeviceGetCount.
    interface->deviceGetCount = dlsym(interface->handle, "nvmlDeviceGetCount");
    if (!interface->deviceGetCount) {
        goto SymbolError;
    }

    // Load nvmlDeviceGetHandleByIndex.
    interface->deviceGetHandleByIndex =
        dlsym(interface->handle, "nvmlDeviceGetHandleByIndex");
    if(!interface->deviceGetHandleByIndex) {
        goto SymbolError;
    }

    // Load nvmlDeviceGetHandleByPciBusId
    interface->deviceGetHandleByPciBusId =
        dlsym(interface->handle, "nvmlDeviceGetHandleByPciBusId");
    if(!interface->deviceGetHandleByPciBusId) {
        goto SymbolError;
    }


    // Load nvmlDeviceGetMemoryInfo.
    interface->deviceGetMemoryInfo =
        dlsym(interface->handle, "nvmlDeviceGetMemoryInfo");
    if(!interface->deviceGetMemoryInfo) {
        goto SymbolError;
    }

    // Load nvmlDeviceGetPciInfo.
    interface->deviceGetPciInfo =
        dlsym(interface->handle, "nvmlDeviceGetPciInfo_v2");
    if(!interface->deviceGetPciInfo) {
        goto SymbolError;
    }

    // Load nvmlDeviceGetTemperature.
    interface->deviceGetTemperature =
        dlsym(interface->handle, "nvmlDeviceGetTemperature");
    if(!interface->deviceGetTemperature) {
        goto SymbolError;
    }

    // Load nvmlDeviceGetPowerUsage.
    interface->deviceGetPowerUsage =
        dlsym(interface->handle, "nvmlDeviceGetPowerUsage");
    if(!interface->deviceGetPowerUsage) {
        goto SymbolError;
    }

    // Load nvmlDeviceGetUtilizationRates.
    interface->deviceGetUtilizationRates =
        dlsym(interface->handle, "nvmlDeviceGetUtilizationRates");
    if(!interface->deviceGetUtilizationRates) {
        goto SymbolError;
    }

    // Load nvmlDeviceSetPersistenceMode.
    interface->deviceSetPersistenceMode =
        dlsym(interface->handle, "nvmlDeviceSetPersistenceMode");
    if(!interface->deviceSetPersistenceMode) {
        goto SymbolError;
    }

    // Load nvmlDeviceGetVgpuMetadata.
    interface->deviceGetVgpuMetadata =
        dlsym(interface->handle, "nvmlDeviceGetVgpuMetadata");
    if(!interface->deviceGetVgpuMetadata) {
        goto SymbolError;
    }

    // Load nvmlVgpuInstanceGetMetadata.
    interface->vgpuInstanceGetMetadata =
        dlsym(interface->handle, "nvmlVgpuInstanceGetMetadata");
    if(!interface->vgpuInstanceGetMetadata) {
        goto SymbolError;
    }

    // Load nvmlDeviceGetActiveVgpus.
    interface->deviceGetActiveVgpus =
        dlsym(interface->handle, "nvmlDeviceGetActiveVgpus");
    if(!interface->deviceGetActiveVgpus) {
        goto SymbolError;
    }

    // Load nvmlVgpuInstanceGetVmID.
    interface->vgpuInstanceGetVmID =
        dlsym(interface->handle, "nvmlVgpuInstanceGetVmID");
    if(!interface->vgpuInstanceGetVmID) {
        goto SymbolError;
    }

    // Load nvmlGetVgpuCompatibility.
    interface->getVgpuCompatibility =
        dlsym(interface->handle, "nvmlGetVgpuCompatibility");
    if(!interface->getVgpuCompatibility) {
        goto SymbolError;
    }


    ml_interface = (value)interface;
    CAMLreturn(ml_interface);

SymbolError:
    free(interface);
    exn = caml_named_value("Symbol_not_loaded");
    if (exn) {
        caml_raise_with_string(*exn, dlerror());
    }
    else {
        caml_failwith(dlerror());
    }
}

CAMLprim value stub_nvml_close(value ml_interface) {
    CAMLparam1(ml_interface);
    nvmlInterface* interface;

    interface = (nvmlInterface*)ml_interface;
    dlclose((void*)(interface->handle));
    free(interface);

    CAMLreturn(Val_unit);
}

void check_error(nvmlInterface* interface, nvmlReturn_t error) {
    if (NVML_SUCCESS != error) {
        caml_failwith(interface->errorString(error));
    }
}

CAMLprim value stub_nvml_init(value ml_interface) {
    CAMLparam1(ml_interface);
    nvmlReturn_t error;
    nvmlInterface* interface;

    interface = (nvmlInterface*)ml_interface;
    error = interface->init();
    check_error(interface, error);

    CAMLreturn(Val_unit);
}

CAMLprim value stub_nvml_shutdown(value ml_interface) {
    CAMLparam1(ml_interface);
    nvmlReturn_t error;
    nvmlInterface* interface;

    interface = (nvmlInterface*)ml_interface;
    error = interface->shutdown();
    check_error(interface, error);

    CAMLreturn(Val_unit);
}

CAMLprim value stub_nvml_device_get_count(value ml_interface) {
    CAMLparam1(ml_interface);
    nvmlReturn_t error;
    nvmlInterface* interface;
    unsigned int count;

    interface = (nvmlInterface*)ml_interface;
    error = interface->deviceGetCount(&count);
    check_error(interface, error);

    CAMLreturn(Val_int(count));
}

CAMLprim value stub_nvml_device_get_handle_by_index(
        value ml_interface,
        value ml_index) {
    CAMLparam2(ml_interface, ml_index);
    CAMLlocal1(ml_device);

    nvmlReturn_t error;
    nvmlInterface* interface;
    unsigned int index;
    nvmlDevice_t device;

    interface = (nvmlInterface*)ml_interface;
    index = Int_val(ml_index);
    error = interface->deviceGetHandleByIndex(index, &device);
    check_error(interface, error);

    unsigned int deviceSize = sizeof(nvmlDevice_t);
    ml_device = caml_alloc_string(deviceSize);
    memcpy(String_val(ml_device),
        &device, deviceSize);

    CAMLreturn(ml_device);
}

CAMLprim value stub_nvml_device_get_handle_by_pci_bus_id(
        value ml_interface,
        value ml_pci_bus_id) {
    CAMLparam2(ml_interface, ml_pci_bus_id);
    CAMLlocal1(ml_device);

    nvmlReturn_t error;
    nvmlInterface* interface;
    char* pciBusId;
    nvmlDevice_t device;

    interface = (nvmlInterface*)ml_interface;
    pciBusId = String_val(ml_pci_bus_id);
    error = interface->deviceGetHandleByPciBusId(pciBusId, &device);
    check_error(interface, error);
    
    unsigned int deviceSize = sizeof(nvmlDevice_t);
    ml_device = caml_alloc_string(deviceSize);
    memcpy(String_val(ml_device),
        &device, deviceSize);

    CAMLreturn(ml_device);
}


CAMLprim value stub_nvml_device_get_memory_info(
        value ml_interface,
        value ml_device) {
    CAMLparam2(ml_interface, ml_device);
    CAMLlocal1(ml_memory_info);
    nvmlReturn_t error;
    nvmlInterface* interface;
    nvmlMemory_t memory_info;
    nvmlDevice_t device;

    interface = (nvmlInterface*)ml_interface;
    device = *(nvmlDevice_t*)ml_device;
    error =
        interface->deviceGetMemoryInfo(device, &memory_info);
    check_error(interface, error);

    ml_memory_info = caml_alloc(3, 0);
    Store_field(ml_memory_info, 0, caml_copy_int64(memory_info.total));
    Store_field(ml_memory_info, 1, caml_copy_int64(memory_info.free));
    Store_field(ml_memory_info, 2, caml_copy_int64(memory_info.used));

    CAMLreturn(ml_memory_info);
}

CAMLprim value stub_nvml_device_get_pci_info(
        value ml_interface,
        value ml_device) {
    CAMLparam2(ml_interface, ml_device);
    CAMLlocal1(ml_pci_info);
    nvmlReturn_t error;
    nvmlInterface* interface;
    nvmlPciInfo_t pci_info;
    nvmlDevice_t device;

    interface = (nvmlInterface*)ml_interface;
    device = *(nvmlDevice_t*)ml_device;
    error =
        interface->deviceGetPciInfo(device, &pci_info);
    check_error(interface, error);

    ml_pci_info = caml_alloc(6, 0);
    Store_field(ml_pci_info, 0, caml_copy_string(pci_info.busId));
    Store_field(ml_pci_info, 1, caml_copy_int32(pci_info.domain));
    Store_field(ml_pci_info, 2, caml_copy_int32(pci_info.bus));
    Store_field(ml_pci_info, 3, caml_copy_int32(pci_info.device));
    Store_field(ml_pci_info, 4, caml_copy_int32(pci_info.pciDeviceId));
    Store_field(ml_pci_info, 5, caml_copy_int32(pci_info.pciSubSystemId));

    CAMLreturn(ml_pci_info);
}

CAMLprim value stub_nvml_device_get_temperature(
        value ml_interface,
        value ml_device) {
    CAMLparam2(ml_interface, ml_device);
    nvmlReturn_t error;
    nvmlInterface* interface;
    unsigned int temp;
    nvmlDevice_t device;

    interface = (nvmlInterface*)ml_interface;
    device = *(nvmlDevice_t*)ml_device;
    error =
        interface->deviceGetTemperature(device, NVML_TEMPERATURE_GPU, &temp);
    check_error(interface, error);

    CAMLreturn(Val_int(temp));
}

CAMLprim value stub_nvml_device_get_power_usage(
        value ml_interface,
        value ml_device) {
    CAMLparam2(ml_interface, ml_device);
    nvmlReturn_t error;
    nvmlInterface* interface;
    nvmlDevice_t device;
    unsigned int power_usage;

    interface = (nvmlInterface*)ml_interface;
    device = *(nvmlDevice_t*)ml_device;
    error = interface->deviceGetPowerUsage(device, &power_usage);
    check_error(interface, error);

    CAMLreturn(Val_int(power_usage));
}

CAMLprim value stub_nvml_device_get_utilization_rates(
        value ml_interface,
        value ml_device) {
    CAMLparam2(ml_interface, ml_device);
    CAMLlocal1(ml_utilization);
    nvmlReturn_t error;
    nvmlInterface* interface;
    nvmlDevice_t device;
    nvmlUtilization_t utilization;

    interface = (nvmlInterface*)ml_interface;
    device = *(nvmlDevice_t*)ml_device;
    error = interface->deviceGetUtilizationRates(device, &utilization);
    check_error(interface, error);

    ml_utilization = caml_alloc(2, 0);
    Store_field(ml_utilization, 0, Val_int(utilization.gpu));
    Store_field(ml_utilization, 1, Val_int(utilization.memory));

    CAMLreturn(ml_utilization);
}

CAMLprim value stub_nvml_device_set_persistence_mode(
        value ml_interface,
        value ml_device,
        value ml_mode) {
    CAMLparam3(ml_interface, ml_device, ml_mode);
    nvmlReturn_t error;
    nvmlInterface* interface;
    nvmlDevice_t device;
    nvmlEnableState_t mode;

    interface = (nvmlInterface*)ml_interface;
    device = *(nvmlDevice_t*)ml_device;
    mode = (nvmlEnableState_t)(Int_val(ml_mode));
    error = interface->deviceSetPersistenceMode(device, mode);
    check_error(interface, error);

    CAMLreturn(Val_unit);
}


CAMLprim value stub_nvml_device_get_pgpu_metadata(
        value ml_interface, 
        value ml_device) {
    CAMLparam2(ml_interface, ml_device);
    CAMLlocal1(ml_pgpu_metadata);
    nvmlReturn_t error;
    nvmlInterface* interface;
    nvmlDevice_t device;
    unsigned int pgpuMetadataSize = 0;
    nvmlVgpuPgpuMetadata_t* pgpuMetadata = NULL;

    interface = (nvmlInterface*)ml_interface;
    device = *(nvmlDevice_t*)ml_device;

    // Get metadata dynamically increasing the buffer size
    int dummy;
    do {
        error = interface->deviceGetVgpuMetadata(
            device,
            (pgpuMetadata)?pgpuMetadata:(nvmlVgpuPgpuMetadata_t*) &dummy,
            &pgpuMetadataSize);
        if ((error == NVML_ERROR_INSUFFICIENT_SIZE) && (pgpuMetadataSize > 0)) {
            if (pgpuMetadata) { free(pgpuMetadata); }
            pgpuMetadata = (nvmlVgpuPgpuMetadata_t*) malloc(pgpuMetadataSize);
            if (!pgpuMetadata) { check_error(interface, NVML_ERROR_MEMORY); }
        }
    } while ((error == NVML_ERROR_INSUFFICIENT_SIZE) && (pgpuMetadataSize > 0));
    if (error != NVML_SUCCESS) {
        free(pgpuMetadata);
        check_error(interface, error);
    }

    ml_pgpu_metadata = caml_alloc_string(pgpuMetadataSize);
    memcpy(String_val(ml_pgpu_metadata), pgpuMetadata, pgpuMetadataSize);
    free(pgpuMetadata);

    CAMLreturn(ml_pgpu_metadata);
}

CAMLprim value stub_nvml_get_vgpu_metadata(
        value ml_interface,
        value ml_vgpu_instance)
{
    CAMLparam2(ml_interface, ml_vgpu_instance);
    CAMLlocal1(ml_vgpu_metadata);
    nvmlReturn_t error;
    nvmlInterface* interface;
    nvmlVgpuInstance_t vgpu;
    unsigned int vgpuMetadataSize = 0;
    nvmlVgpuMetadata_t* vgpuMetadata = NULL;

    interface = (nvmlInterface*)ml_interface;
    vgpu = (nvmlVgpuInstance_t)(Int_val(ml_vgpu_instance));

    // Get metadata dynamically increasing the buffer size
    int dummy;
    do {
        error = interface->vgpuInstanceGetMetadata(
            vgpu,
            vgpuMetadata ? vgpuMetadata : (nvmlVgpuMetadata_t*) &dummy,
            &vgpuMetadataSize);
        if ((error == NVML_ERROR_INSUFFICIENT_SIZE) && (vgpuMetadataSize > 0)) {
            if (vgpuMetadata) { free(vgpuMetadata); }
            vgpuMetadata = (nvmlVgpuMetadata_t*) malloc(vgpuMetadataSize);
            if (!vgpuMetadata) { check_error(interface, NVML_ERROR_MEMORY); }
        }
    } while ((error == NVML_ERROR_INSUFFICIENT_SIZE) && (vgpuMetadataSize > 0));
    if (error != NVML_SUCCESS) {
        free(vgpuMetadata);
        check_error(interface, error);
    }

    ml_vgpu_metadata = caml_alloc_string(vgpuMetadataSize);
    memcpy(String_val(ml_vgpu_metadata), vgpuMetadata, vgpuMetadataSize);
    free(vgpuMetadata);

    CAMLreturn(ml_vgpu_metadata);
}




CAMLprim value stub_pgpu_metadata_get_pgpu_version(value ml_pgpu_metadata) {
    CAMLparam1(ml_pgpu_metadata);
    nvmlVgpuPgpuMetadata_t pgpuMetadata;
    pgpuMetadata = *(nvmlVgpuPgpuMetadata_t*)ml_pgpu_metadata;
    CAMLreturn(Val_int(pgpuMetadata.version));
}

CAMLprim value stub_pgpu_metadata_get_pgpu_revision(value ml_pgpu_metadata) {
    CAMLparam1(ml_pgpu_metadata);
    nvmlVgpuPgpuMetadata_t pgpuMetadata;
    pgpuMetadata = *(nvmlVgpuPgpuMetadata_t*)ml_pgpu_metadata;
    CAMLreturn(Val_int(pgpuMetadata.revision));
}

CAMLprim value stub_pgpu_metadata_get_pgpu_host_driver_version(value ml_pgpu_metadata) {
    CAMLparam1(ml_pgpu_metadata);
    nvmlVgpuPgpuMetadata_t pgpuMetadata;
    pgpuMetadata = *(nvmlVgpuPgpuMetadata_t*)ml_pgpu_metadata;
    CAMLreturn(caml_copy_string(pgpuMetadata.hostDriverVersion));
}


CAMLprim value stub_nvml_device_get_active_vgpus(
        value ml_interface,
        value ml_device) {
    CAMLparam2(ml_interface, ml_device);
    CAMLlocal2(tail, cons);

    nvmlReturn_t error;
    nvmlInterface* interface;
    nvmlDevice_t device;
    
    unsigned int vgpuCount = 0;
    nvmlVgpuInstance_t* vgpuInstances = NULL;
    
    interface = (nvmlInterface*)ml_interface;
    device = *(nvmlDevice_t*)ml_device;

    // Get instances dynamically increasing the buffer size
    int dummy;
    do {
        error = interface->deviceGetActiveVgpus(
            device,
            &vgpuCount, 
            (vgpuInstances)?vgpuInstances:(nvmlVgpuInstance_t*) &dummy);
        if ((error == NVML_ERROR_INSUFFICIENT_SIZE) && (vgpuCount > 0)) {
            if (vgpuInstances) { free(vgpuInstances); }
            vgpuInstances = (nvmlVgpuInstance_t*) malloc(sizeof(nvmlVgpuInstance_t)*vgpuCount);
            if (!vgpuInstances) { check_error(interface, NVML_ERROR_MEMORY); }
        }
    } while ((error == NVML_ERROR_INSUFFICIENT_SIZE) && (vgpuCount > 0));
    if (error != NVML_SUCCESS) {
        free(vgpuInstances);
        check_error(interface, error);
    }
    // Pack the vgpu instances in an OCaml list
    tail = Val_emptylist;

    int i;
    for (i = vgpuCount-1; i >= 0; i--) {
        cons = caml_alloc(2, 0);
        Store_field(cons, 0, Val_int(vgpuInstances[i]));
        Store_field(cons, 1, tail);
        tail = cons;
    }

    free(vgpuInstances);
    CAMLreturn(tail);
}

CAMLprim value stub_nvml_vgpu_instance_get_vm_id(
        value ml_interface,
        value ml_vgpu_instance) {
    CAMLparam2(ml_interface, ml_vgpu_instance);
    CAMLlocal1(ml_vm_id);

    nvmlReturn_t error;
    nvmlInterface* interface;
    nvmlVgpuInstance_t vgpuInstance;
    
    // The VM ID is returned as a string,
    // not exceeding 80 characters in length (including the NUL terminator).
    char vmID[80];
    nvmlVgpuVmIdType_t *vmIdType;

    interface = (nvmlInterface*)ml_interface;
    vgpuInstance = (nvmlVgpuInstance_t)Int_val(ml_vgpu_instance);
    
    vmIdType = (nvmlVgpuVmIdType_t*) malloc(sizeof(nvmlVgpuVmIdType_t));
    if (!vmIdType) {
        check_error(interface, NVML_ERROR_MEMORY);
    }

    error = interface->vgpuInstanceGetVmID(
        vgpuInstance, vmID, 80, vmIdType);
    if (error != NVML_SUCCESS) {
        free(vmIdType);
        check_error(interface, error);
    }

    ml_vm_id = caml_copy_string(vmID);

    free(vmIdType);

    CAMLreturn(ml_vm_id);
}

CAMLprim value stub_nvml_get_pgpu_vgpu_compatibility(
        value ml_interface,
        value ml_vgpu_metadata,
        value ml_pgpu_metadata)
{
    CAMLparam3(ml_interface, ml_vgpu_metadata, ml_pgpu_metadata);
    CAMLlocal1(ml_vgpu_pgpu_compat_meta);
    nvmlReturn_t                error;
    nvmlInterface*              interface;
    nvmlVgpuPgpuMetadata_t*     pgpuMetadata;
    nvmlVgpuMetadata_t*         vgpuMetadata;
    nvmlVgpuPgpuCompatibility_t vgpuCompatibility;

    interface    = (nvmlInterface*)           ml_interface;
    vgpuMetadata = (nvmlVgpuMetadata_t*)      ml_vgpu_metadata;
    pgpuMetadata = (nvmlVgpuPgpuMetadata_t*)  ml_pgpu_metadata;

    error = interface->getVgpuCompatibility(
        vgpuMetadata,
        pgpuMetadata,
        &vgpuCompatibility);
    check_error(interface, error);

    size_t compatSize = sizeof(nvmlVgpuPgpuCompatibility_t);
    ml_vgpu_pgpu_compat_meta = caml_alloc_string(compatSize);
    memcpy(String_val(ml_vgpu_pgpu_compat_meta),
        &vgpuCompatibility, compatSize);

    CAMLreturn(ml_vgpu_pgpu_compat_meta);
}


CAMLprim value stub_vgpu_compat_get_vm_compat(value ml_vgpu_compat) {
    CAMLparam1(ml_vgpu_compat);
    CAMLlocal2(tail, cons);
    nvmlVgpuPgpuCompatibility_t* vgpuCompatibility;
    int mask;

    vgpuCompatibility = (nvmlVgpuPgpuCompatibility_t*)ml_vgpu_compat;
    mask = vgpuCompatibility->vgpuVmCompatibility;

    tail = Val_emptylist;

    if (mask == NVML_VGPU_VM_COMPATIBILITY_NONE) {
        cons = caml_alloc(2, 0);
        Store_field(cons, 0, Val_int(0));
        Store_field(cons, 1, tail);
        tail = cons;
    }
    if (mask & NVML_VGPU_VM_COMPATIBILITY_COLD) {
        cons = caml_alloc(2, 0);
        Store_field(cons, 0, Val_int(1));
        Store_field(cons, 1, tail);
        tail = cons;
    }
    if (mask & NVML_VGPU_VM_COMPATIBILITY_HIBERNATE) {
        cons = caml_alloc(2, 0);
        Store_field(cons, 0, Val_int(2));
        Store_field(cons, 1, tail);
        tail = cons;
    }
    if (mask & NVML_VGPU_VM_COMPATIBILITY_SLEEP) {
        cons = caml_alloc(2, 0);
        Store_field(cons, 0, Val_int(3));
        Store_field(cons, 1, tail);
        tail = cons;
    }
    if (mask & NVML_VGPU_VM_COMPATIBILITY_LIVE) {
        cons = caml_alloc(2, 0);
        Store_field(cons, 0, Val_int(4));
        Store_field(cons, 1, tail);
        tail = cons;
    }

    CAMLreturn(tail);
}

CAMLprim value stub_vgpu_compat_get_pgpu_compat_limit(value ml_vgpu_compat) {
    CAMLparam1(ml_vgpu_compat);
    CAMLlocal2(tail, cons);
    nvmlVgpuPgpuCompatibility_t* vgpuCompatibility;
    int mask;

    vgpuCompatibility = (nvmlVgpuPgpuCompatibility_t*)ml_vgpu_compat;
    mask = vgpuCompatibility->compatibilityLimitCode;

    tail = Val_emptylist;

    if (mask == NVML_VGPU_COMPATIBILITY_LIMIT_NONE) {
        cons = caml_alloc(2, 0);
        Store_field(cons, 0, Val_int(0));
        Store_field(cons, 1, tail);
        tail = cons;
    }
    if (mask & NVML_VGPU_COMPATIBILITY_LIMIT_HOST_DRIVER) {
        cons = caml_alloc(2, 0);
        Store_field(cons, 0, Val_int(1));
        Store_field(cons, 1, tail);
        tail = cons;
    }
    if (mask & NVML_VGPU_COMPATIBILITY_LIMIT_GUEST_DRIVER) {
        cons = caml_alloc(2, 0);
        Store_field(cons, 0, Val_int(2));
        Store_field(cons, 1, tail);
        tail = cons;
    }
    if (mask & NVML_VGPU_COMPATIBILITY_LIMIT_GPU) {
        cons = caml_alloc(2, 0);
        Store_field(cons, 0, Val_int(3));
        Store_field(cons, 1, tail);
        tail = cons;
    }
    if (mask & NVML_VGPU_COMPATIBILITY_LIMIT_OTHER) {
        cons = caml_alloc(2, 0);
        Store_field(cons, 0, Val_int(4));
        Store_field(cons, 1, tail);
        tail = cons;
    }

    CAMLreturn(tail);
}
