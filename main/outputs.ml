(******************************************************************************)
(*  _  __ * The Kappa Language                                                *)
(* | |/ / * Copyright 2010-2017 CNRS - Harvard Medical School - INRIA - IRIF  *)
(* | ' /  *********************************************************************)
(* | . \  * This file is distributed under the terms of the                   *)
(* |_|\_\ * GNU Lesser General Public License Version 3                       *)
(******************************************************************************)

let print_desc : (string,out_channel * Format.formatter) Hashtbl.t =
  Hashtbl.create 2

let species_desc : (string,out_channel * Format.formatter) Hashtbl.t =
  Hashtbl.create 2

let uuid = Random.State.bits (Random.State.make_self_init ())

let get_desc file tbl =
  try snd (Hashtbl.find tbl file)
  with Not_found ->
    let d_chan = Kappa_files.open_out file in
    let d = Format.formatter_of_out_channel d_chan in
    (Hashtbl.add tbl file (d_chan,d) ; d)

let close_desc () =
  Hashtbl.iter (fun _file (d_chan,_d) -> close_out d_chan) print_desc;
  Hashtbl.iter (fun _file (d_chan,_d) -> close_out d_chan) species_desc

let output_flux flux =
  Kappa_files.with_flux
    flux.Data.flux_data.Data.flux_name
    (if Filename.check_suffix flux.Data.flux_data.Data.flux_name ".html"
     then Kappa_files.wrap_formatter (fun f -> Data.print_html_flux_map f flux)
      else if Filename.check_suffix flux.Data.flux_data.Data.flux_name ".json"
      then fun d -> JsonUtil.write_to_channel Data.write_flux_map d flux
      else Kappa_files.wrap_formatter (fun f -> Data.print_dot_flux_map ~uuid f flux))

let actsDescr = ref None
let emptyActs = ref true

let init_activities env = function
  | None -> ()
  | Some s ->
    let desc = Kappa_files.open_out s in
    let form = Format.formatter_of_out_channel desc in
    let nb_r = Model.nb_syntactic_rules env in
    let () = actsDescr := Some (desc,form,nb_r) in
    let () = Format.fprintf form "@[<v>{@,rules:@[[" in
    let () =
      Tools.iteri
        (fun x -> Format.fprintf form "\"%a\",@," (Model.print_ast_rule ~env) x)
        nb_r in
    Format.fprintf form "\"%a\"]@],@,data:[@," (Model.print_ast_rule ~env) nb_r

let close_activities () =
  match !actsDescr with
  | None -> ()
  | Some (c,f,_) ->
    let () = Format.fprintf f "@,]}@]@." in
    close_out c

let output_activities r flux =
  match !actsDescr with
  | None -> ()
  | Some (_,f,last) ->
    let () =
      if !emptyActs then emptyActs := false else Format.fprintf f ",@," in
    let () = Format.fprintf f "@[[%i" r in
    let () =
      for i = 0 to last do
        let k,k' = try List.assoc i flux with Not_found -> 0.,0. in
        Format.fprintf f ",%f" (k'-.k)
      done in
    Format.fprintf f "]@]"

type fd = {
  desc:out_channel;
  form:Format.formatter;
  is_tsv:bool;
}

type format = StandBy of (string * string * string array)
            | Raw of fd | Svg of Pp_svg.store

let plotDescr = ref None

let close_plot () =
  match !plotDescr with
  | (None | Some (StandBy _)) -> ()
  | Some (Raw plot) -> close_out plot.desc
  | Some (Svg s) -> Pp_svg.to_file s

let traceDescr = ref None
let traceNotEmpty = ref false

let close_trace () =
  match !traceDescr with
  | None -> ()
  | Some desc ->
    let () = output_string desc "]\n}\n" in
    let () = close_out desc in
    traceDescr := None

let initialize activities_file trace_file plotPack env =
  let () =
    match trace_file with
    | None -> ()
    | Some s ->
      let desc = Kappa_files.open_out s in
      let () = Trace.init_trace_file ~uuid env desc in
      traceDescr := Some desc in
  let () = init_activities env activities_file in
  match plotPack with
  | None -> ()
  | Some pack -> plotDescr := Some (StandBy pack)

let launch_plot (filename,title,head) =
  let format =
    if Filename.check_suffix filename ".svg" then
      Svg {Pp_svg.file = filename;
           Pp_svg.title = title;
           Pp_svg.descr = "\"uuid\" : \""^string_of_int uuid^"\"";
           Pp_svg.legend = head;
           Pp_svg.points = [];
          }
    else
      let d_chan = Kappa_files.open_out filename in
      let d = Format.formatter_of_out_channel d_chan in
      let is_tsv = Filename.check_suffix filename ".tsv" in
      let () = if not is_tsv then Format.fprintf d "# %s@." title in
      let () = if not is_tsv
        then Format.fprintf d "# \"uuid\" : \"%i\"@." uuid in
      let () = Data.print_plot_legend ~is_tsv d head in
      Raw {desc=d_chan; form=d; is_tsv} in
    plotDescr := Some format

let rec plot_now l =
  match !plotDescr with
  | None -> assert false
  | Some (StandBy p) -> let () = launch_plot p in plot_now l
  | Some (Raw fd) ->
    Data.print_plot_line ~is_tsv:fd.is_tsv Nbr.print_option fd.form l
  | Some (Svg s) -> s.Pp_svg.points <- l :: s.Pp_svg.points

let snapshot s =
  if Filename.check_suffix s.Data.snapshot_file ".dot" then
    Kappa_files.with_snapshot
      s.Data.snapshot_file ".dot" s.Data.snapshot_event
      (Kappa_files.wrap_formatter (fun f -> Data.print_dot_snapshot ~uuid f s))
  else if Filename.check_suffix s.Data.snapshot_file ".json" then
    Kappa_files.with_snapshot
      s.Data.snapshot_file ".json" s.Data.snapshot_event
      (fun d -> JsonUtil.write_to_channel Data.write_snapshot d s)
  else
    Kappa_files.with_snapshot
      s.Data.snapshot_file ".ka" s.Data.snapshot_event
      (Kappa_files.wrap_formatter (fun f -> Data.print_snapshot ~uuid f s))

let print_species time f mixture =
  Format.fprintf f "%g: @[<h>%a@]@." time User_graph.print_cc mixture

let go = function
  | Data.Snapshot s -> snapshot s
  | Data.Flux f -> output_flux f
  | Data.DeltaActivities (r,flux) -> output_activities r flux
  | Data.Plot x -> plot_now x
  | Data.Print p ->
    let desc =
      match p.Data.file_line_name with
        None -> Format.formatter_of_out_channel stdout
      | Some file -> get_desc file print_desc
    in
    Format.fprintf desc "%s@." p.Data.file_line_text
  | Data.Log s -> Format.printf "%s@." s
  | Data.TraceStep step ->
    begin match !traceDescr with
      | None -> ()
      | Some d ->
        let () =
          if !traceNotEmpty then output_char d ',' else traceNotEmpty := true in
        Yojson.Basic.to_channel d (Trace.step_to_yojson step)
    end
  | Data.Species (file,time,mixture) ->
     let desc = get_desc file species_desc in
     print_species time desc mixture

let inputsDesc = ref None

let close_input ?event () =
  match !inputsDesc with
  | None -> ()
  | Some inputs ->
    let () =
      match event with
      | None -> ()
      | Some event -> Format.fprintf
                        (Format.formatter_of_out_channel inputs)
                        "@.%%mod: [E] = %i do $STOP@." event in
    close_out inputs

let close ?event () =
  let () = close_plot () in
  let () = close_trace () in
  let () = close_activities () in
  let () = close_input ?event () in
  close_desc ()

let initial_inputs conf env contact_map init ~filename =
  let inputs = Kappa_files.open_out_fresh filename "" ".ka" in
  let inputs_form = Format.formatter_of_out_channel inputs in
  let () = Format.fprintf inputs_form "# \"uuid\" : \"%i\"@." uuid in
  let () = Format.fprintf inputs_form
      "%a@.%a@." Configuration.print conf
      (Kappa_printer.env_kappa contact_map) env in
  let sigs = Model.signatures env in
  let () = Format.fprintf inputs_form "@.@[<v>%a@]@."
      (Pp.list Pp.space
         (fun f (n,r) ->
            let ins_fresh,_,_ =
              Primitives.Transformation.raw_mixture_of_fresh
                sigs r.Primitives.inserted in
            if ins_fresh = [] then
              Pp.list Pp.space (fun f (nb,tk) ->
                  Format.fprintf f "@[<h>%%init: %a %a@]"
                    (Kappa_printer.alg_expr ~env)
                    (fst (Alg_expr.mult (Locality.dummy_annot n) nb))
                    (Model.print_token ~env) tk)
                f r.Primitives.delta_tokens
              else
                Format.fprintf f "@[<h>%%init: %a %a@]"
                  (Kappa_printer.alg_expr ~env) n
                  (Raw_mixture.print ~created:false ~sigs)
                  (List.map snd ins_fresh))) init in
  inputsDesc := Some inputs

let input_modifications env event mods =
  match !inputsDesc with
  | None -> ()
  | Some inputs ->
    Format.fprintf
      (Format.formatter_of_out_channel inputs)
      "%%mod: [E] = %i do %a@."
      event (Pp.list Pp.colon (Kappa_printer.modification ~env)) mods
