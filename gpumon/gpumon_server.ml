(*
 * Copyright (C) Citrix Systems Inc.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published
 * by the Free Software Foundation; version 2.1 only. with the special
 * exception on linking described in file LICENSE.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *)
module type Interface = sig
  val interface: Nvml.interface option
end

module Make(I: Interface) = struct
  module D = Debug.Make(struct let name = Gpumon_interface.service_name end)
  open D

  let get_interface_exn () = 
    match I.interface with
    | Some interface -> interface
    | None -> raise Gpumon_interface.NvmlInterfaceNotAvailable

  type context = unit

  let get_pgpu_metadata _ dbg pgpu_address =
    let interface = get_interface_exn () in
    try
      let device = Nvml.device_get_handle_by_pci_bus_id interface pgpu_address in
      Nvml.device_get_pgpu_metadata interface device
    with err -> raise (Gpumon_interface.NvmlFailure (Printexc.to_string err))

  let get_pgpu_vm_compatibility _ dbg pgpu_address domid pgpu_metadata =
    let interface = get_interface_exn () in
    let compatibility = 
      try
        (* Return a tuple vm_compat, pgpu_compat_limit for convenience:
         * we have List helpers that later help to split the list *)
        let vgpu_to_compat vgpu =
          let vgpu_compat =
            Nvml.get_pgpu_vgpu_compatibility interface vgpu pgpu_metadata 
          in 
          ( Nvml.vgpu_compat_get_vm_compat vgpu_compat
          , Nvml.vgpu_compat_get_pgpu_compat_limit vgpu_compat) 
        in
        let current_device = 
          Nvml.device_get_handle_by_pci_bus_id interface pgpu_address
        in
        let vgpus =
          Nvml.get_vgpus_for_vm interface current_device (string_of_int domid)
        in
        List.map vgpu_to_compat vgpus
      with err -> 
        raise (Gpumon_interface.NvmlFailure (Printexc.to_string err))
    in
    match compatibility with
    | [] ->
      (* We call this function when we expect the VM to have a vGPU, 
       * if this is not the case we consider it an internal error *)
      failwith (Printf.sprintf "No vGPU available for the VM with domid %d" domid)
    | compatiblity ->
      let open Stdext.Listext in
      let vm_compat, limits = List.split compatibility in
      let support_live_migration =
        vm_compat
        |> List.map (List.mem Nvml.Live)
        |> List.fold_left (&&) true
      in
      let failures =
        limits
        |> List.filter ((<>) [Nvml.None])
        |> List.concat
        |> List.setify
        |> List.map (function
            | Nvml.HostDriver  -> Gpumon_interface.Host_driver
            | Nvml.GuestDriver -> Gpumon_interface.Guest_driver
            | Nvml.GPU         -> Gpumon_interface.GPU
            | Nvml.Other       -> Gpumon_interface.Other
            (* NOTE: replace this failwith with `-> .` 
             * after we upgrade the compiler *)
            | Nvml.None        -> failwith "This should never happen"
          ) in
      match support_live_migration, failures with
      | true, [] -> Gpumon_interface.Compatible
      | _, _ -> Gpumon_interface.(Incompatible failures)
end
