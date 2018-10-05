open OUnit

let string_of_result =
  let open Rresult in
  function
  | Error (`Parse_failure msg) -> Printf.sprintf "Parse_failure %s" msg
  | Error (`Unknown_version version) ->
    Printf.sprintf "Unknown_version %s" version
  | Error `Does_not_exist -> "Does_not_exist"
  | Ok config -> Printf.sprintf "Ok %s" (Gpumon_config.to_string config)

let test_file config_file expected_result =
  let config_file_path = Filename.concat "data" config_file in
  let actual_result = Gpumon_config.of_file config_file_path in
  assert_equal ~msg:"Unexpected result from read_config_file"
    ~printer:string_of_result
    expected_result actual_result

let default_config =
  let open Gpumon_config in
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
    ];
  }

let default_with_match_config =
  let open Gpumon_config in
  {
    device_types = [
      (* GRID K1 *)
      {
        device_id = 0x0ff2l;
        subsystem_device_id = Match 0x1012l;
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
        subsystem_device_id = Match 0x100al;
        metrics = [
          Memory Free;
          Memory Used;
          Other Temperature;
          Other PowerUsage;
          Utilisation Compute;
          Utilisation MemoryIO;
        ];
      };
    ];
  }

let subsystem_device_id_config =
  let open Gpumon_config in
  {
    device_types = [
      {
        device_id = 0x1234l;
        subsystem_device_id = Match 0x5687l;
        metrics = [
          Memory Free;
          Memory Used;
        ];
      };
    ];
  }

let v2_mixed_config =
  let open Gpumon_config in
  {
    device_types = [
      {
        device_id = 0x1234l;
        subsystem_device_id = Any;
        metrics = [
          Other Temperature;
          Other PowerUsage;
        ];
      };
      {
        device_id = 0x5678l;
        subsystem_device_id = Match 0x9abcl;
        metrics = [
          Utilisation Compute;
          Utilisation MemoryIO;
        ];
      };
    ];
  }

let tests =
  let open Gpumon_config in
  let open Rresult in
  [
    "test_does_not_exist.conf", Error `Does_not_exist;
    "test_unknown_version.conf", Error (`Unknown_version "\"4\"");
    "test_v1_minimal.conf", Ok {device_types = []};
    "test_v2_minimal.conf", Ok {device_types = []};
    "test_v1_default.conf", Ok default_config;
    "test_v2_default.conf", Ok default_config;
    "test_v2_default_with_match.conf", Ok default_with_match_config;
    "test_v2_with_subsystem_device_id.conf", Ok subsystem_device_id_config;
    "test_v2_mixed.conf", Ok v2_mixed_config;
  ]

let test =
  "test_config" >:::
  (List.map
     (fun (config_file, expected_result) ->
        config_file >:: (fun () ->  test_file config_file expected_result))
     tests)
