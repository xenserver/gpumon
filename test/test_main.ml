open OUnit

let base_suite =
	"base_suite" >:::
		[
			Test_config.test;
		]

let _ = run_test_tt_main base_suite
