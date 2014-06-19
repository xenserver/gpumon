type ('a, 'b) t = [
	| `Ok of 'a
	| `Error of 'b
]

let return x = `Ok x

let fail x = `Error x

let (>|=) x f =
	match x with
	| `Ok result -> `Ok (f result)
	| `Error _ as error -> error

let (>>=) x f =
	match x with
	| `Ok result -> f result
	| `Error _ as error -> error

(* Like List.map, but will abort if and when f returns an error. *)
let map f items =
	let rec aux acc = function
		| item :: rest -> (f item) >>= (fun result -> aux (result :: acc) rest)
		| [] -> return (List.rev acc)
	in
	aux [] items
