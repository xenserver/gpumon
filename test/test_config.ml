open OUnit

let string_of_result = function
	| `Parse_failure msg -> Printf.sprintf "Parse_failure %s" msg
	| `Does_not_exist -> "Does_not_exist"
	| `Ok config -> Printf.sprintf "Ok %s" (Config.to_string config)

let test_file config_file expected_result =
	let config_file_path = Filename.concat "test/data" config_file in
	let actual_result = Config.of_file config_file_path in
	assert_equal ~msg:"Unexpected result from read_config_file"
		~printer:string_of_result
		expected_result actual_result

let tests =
	let open Config in
	[
		"test_does_not_exist.conf", `Does_not_exist;
		"test_default.conf", `Ok {
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
		};
		"test_minimal.conf", `Ok {device_types = []};
	]

let test =
	"test_config" >:::
		(List.map
			(fun (config_file, expected_result) ->
				config_file >:: (fun () ->  test_file config_file expected_result))
			tests)
