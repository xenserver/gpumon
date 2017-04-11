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

module D = Debug.Make(struct let name = Gpumon_interface.service_name end)
open D

type context = unit

let get_pgpu_metadata _ dbg pgpu_address =
        "hello, im some pgpu metadata :D"

let get_pgpu_vm_compatibility _ dbg pgpu_address domid pgpu_metadata =
        Gpumon_interface.(Incompatible [Other])
