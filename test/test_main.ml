open OUnit

let base_suite =
	"base_suite" >:::
		[
			Test_config.test;
		]

let () =
	OUnit2.run_test_tt_main (OUnit.ounit2_of_ounit1 base_suite)
