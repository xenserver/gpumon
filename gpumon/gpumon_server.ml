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

module type IMPLEMENTATION = sig
  open Gpumon_interface

  module Nvidia : sig
    val get_pgpu_metadata : debug_info -> pgpu_address -> nvidia_pgpu_metadata

    val get_vgpu_metadata :
         debug_info
      -> domid
      -> pgpu_address
      -> vgpu_uuid
      -> nvidia_vgpu_metadata list

    val get_pgpu_vm_compatibility :
         debug_info
      -> pgpu_address
      -> domid
      -> nvidia_pgpu_metadata
      -> compatibility

    val get_pgpu_vgpu_compatibility :
         debug_info
      -> nvidia_pgpu_metadata
      -> nvidia_vgpu_metadata list
      -> compatibility

    val attach : debug_info -> unit

    val detach : debug_info -> unit

    val is_attached : debug_info -> bool
  end
end

module type Interface = sig
  val interface : Nvml.interface option
end

module Make (I : Interface) : IMPLEMENTATION = struct
  module D = Debug.Make (struct let name = Gpumon_interface.service_name end)

  open D

  module Nvidia = struct
    (** Smallest major version of the host driver that supports migration *)
    let host_driver_supporting_migration = 390

    let get_interface_exn () =
      match I.interface with
      | Some interface ->
          interface
      | None ->
          raise Gpumon_interface.(Gpumon_error NvmlInterfaceNotAvailable)

    let get_pgpu_metadata _dbg pgpu_address =
      let this = "get_pgpu_metadata" in
      let interface = get_interface_exn () in
      try
        let device =
          Nvml.device_get_handle_by_pci_bus_id interface pgpu_address
        in
        let compat = Nvml.device_get_pgpu_metadata interface device in
        let version, revision, driver =
          ( Nvml.pgpu_metadata_get_pgpu_version compat
          , Nvml.pgpu_metadata_get_pgpu_revision compat
          , Nvml.pgpu_metadata_get_pgpu_host_driver_version compat
          )
        in
        let major = Scanf.sscanf driver "%d." (fun x -> x) in
        info "%s: pGPU version=%d revision=%d driver='%s' (%d)" this version
          revision driver major ;
        if major >= host_driver_supporting_migration then
          compat
        else
          let msg =
            Printf.sprintf
              "%s: pGPU host driver version %d < %d does not support migration"
              this major host_driver_supporting_migration
          in
          raise Gpumon_interface.(Gpumon_error (NvmlFailure msg))
      with
      | Gpumon_interface.(Gpumon_error (NvmlFailure _)) as err ->
          raise err
      | err ->
          raise
            Gpumon_interface.(
              Gpumon_error (NvmlFailure (Printexc.to_string err))
            )

    let get_vgpu_metadata _dbg domid pgpu_address vgpu_uuid =
      let interface = get_interface_exn () in
      let domid' = string_of_int domid in
      let filter_instances =
        match vgpu_uuid with
        | "" ->
            List.map (fun vgpu -> vgpu)
        | _ ->
            Nvml.get_vgpu_for_uuid interface vgpu_uuid
      in
      try
        Nvml.device_get_handle_by_pci_bus_id interface pgpu_address
        |> (fun device -> Nvml.get_vgpus_for_vm interface device domid')
        |> filter_instances
        |> List.map (Nvml.get_vgpu_metadata interface)
      with err ->
        raise
          Gpumon_interface.(Gpumon_error (NvmlFailure (Printexc.to_string err)))

    let get_pgpu_vgpu_compatibility _dbg pgpu_metadata vgpu_metadata =
      let interface = get_interface_exn () in
      let compatibility =
        try
          (* Return a tuple vm_compat, pgpu_compat_limit for convenience:
           * we have List helpers that later help to split the list *)
          let vgpu_to_compat vgpu_metadata =
            let vgpu_compat =
              Nvml.get_pgpu_vgpu_compatibility interface vgpu_metadata
                pgpu_metadata
            in
            ( Nvml.vgpu_compat_get_vm_compat vgpu_compat
            , Nvml.vgpu_compat_get_pgpu_compat_limit vgpu_compat
            )
          in
          List.map vgpu_to_compat vgpu_metadata
        with err ->
          raise
            Gpumon_interface.(
              Gpumon_error (NvmlFailure (Printexc.to_string err))
            )
      in
      match compatibility with
      | [] ->
          (* We call this function when we expect the VM to have a vGPU,
           * if this is not the case we consider it an internal error *)
          failwith (Printf.sprintf "No vGPU available")
      | compatibility -> (
          let vm_compat, limits = List.split compatibility in
          let support_live_migration =
            List.for_all (List.mem Nvml.Live) vm_compat
          in
          let failures =
            limits
            |> List.concat
            |> List.filter_map (function
                 | Nvml.HostDriver ->
                     Some Gpumon_interface.Host_driver
                 | Nvml.GuestDriver ->
                     Some Gpumon_interface.Guest_driver
                 | Nvml.GPU ->
                     Some Gpumon_interface.GPU
                 | Nvml.Other ->
                     Some Gpumon_interface.Other
                 | Nvml.None ->
                     None
                 )
          in
          match (support_live_migration, failures) with
          | true, [] ->
              Gpumon_interface.Compatible
          | _, _ ->
              Gpumon_interface.(
                Incompatible (List.sort_uniq Stdlib.compare failures)
              )
        )

    let get_pgpu_vm_compatibility dbg pgpu_address domid pgpu_metadata =
      get_pgpu_vgpu_compatibility dbg pgpu_metadata
        (get_vgpu_metadata dbg domid pgpu_address "")

    let fail exn =
      raise
        Gpumon_interface.(Gpumon_error (NvmlFailure (Printexc.to_string exn)))

    let attach _dbg = try Nvml.NVML.attach () with exn -> fail exn

    let detach _dbg = try Nvml.NVML.detach () with exn -> fail exn

    let is_attached _dbg = try Nvml.NVML.is_attached () with exn -> fail exn
  end
end
