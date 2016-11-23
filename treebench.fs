open System

type tree =
  | Leaf of int
  | Node of tree * tree

// Use one for the leaves: 
let build_tree2 (n : int) : tree =
  let rec go root n =
    if n = 0 then
      Leaf root
    else
      Node (go root (n - 1), go root (n - 1))
  in
  go 1 n

let rec sum_tree = function
  | Leaf i -> i
  | Node (x, y) -> (sum_tree x) + (sum_tree y)

let rec add1_tree = function
  | Leaf i -> Leaf (i + 1)
  | Node (x, y) -> Node (add1_tree x, add1_tree y)

let rec leftmost = function
  | Leaf i -> i
  | Node (x, _) -> leftmost x


type Mode = Par of unit
          | Seq of unit

[<EntryPoint>]
let main(args) =    
    let (m,b,d,i) =
        match args with
        | [| mode; bench; depth; iters |] ->
            (  mode
             , bench
             , int depth
             , int iters)
        | _ -> raise (Exception
                       "bad command line arguments, expected <par|seq> <build|sum|add1> <depth> <iters>")    
    in match (m,b) with
        | "seq","add1" -> let tr = build_tree2 d in
                          let t2 = ref tr in
                          for round in 1 .. 2 do 
                            let stopWatch = System.Diagnostics.Stopwatch.StartNew() in                          
                            for ix in 1 .. i do
                                t2 := add1_tree tr
                            stopWatch.Stop()
                            printfn "leftmost leaf in final tree: %d" (leftmost !t2)
                            if round < 2 
                             then printfn "warm up, time for %d iterations: %f"
                                          i stopWatch.Elapsed.TotalSeconds
                             else printfn "BATCHTIME: %f" stopWatch.Elapsed.TotalSeconds
                          0 
        | _ -> raise (Exception "This mode/bench combo is not implemented yet.")       
