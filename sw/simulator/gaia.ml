(*
 *  $Id$
 *
 * World environment (time, wind, ...) for multi-AC simulation
 *  
 * Copyright (C) 2004 Pascal Brisset, Antoine Drouin
 *
 * This file is part of paparazzi.
 *
 * paparazzi is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2, or (at your option)
 * any later version.
 *
 * paparazzi is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with paparazzi; see the file COPYING.  If not, write to
 * the Free Software Foundation, 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA. 
 *
 *)

open Printf
open Latlong

let my_id = "gaia"

module Ground_Pprz = Pprz.Protocol(struct let name = "ground" end)

let ivy_bus = ref "127.255.255.255:2010"

let parse_args = fun () ->
  let options =
    [ "-b", Arg.String (fun x -> ivy_bus := x), (sprintf "Bus\tDefault is %s" !ivy_bus)] in
  Arg.parse (options)
    (fun x -> Printf.fprintf stderr "Warning: Don't do anythig with %s\n" x)
    "Usage: "

let _ =
  parse_args ();
  let window = GWindow.window ~title:"Gaia" () in
  let quit = fun () -> GMain.Main.quit (); exit 0 in
  ignore (window#connect#destroy ~callback:quit);

  let time_scale = GData.adjustment ~value:1. ~lower:(0.) ~upper:10. ~step_incr:1. () in
  let wind_dir_adj = GData.adjustment ~value:0. ~lower:(0.) ~upper:370. ~step_incr:1.0 () in
  let wind_speed_adj = GData.adjustment ~value:0. ~lower:(0.) ~upper:20. ~step_incr:0.1 () in
  let gust_norm_max_adj = GData.adjustment ~value:0. ~lower:(0.) ~upper:20. ~step_incr:0.1 () in
  let infrared_contrast_adj = GData.adjustment ~value:500. ~lower:(0.) ~upper:1010. ~step_incr:10. () in

  let world_values = fun () ->
    let wind_dir_rad = Latlong.pi /. 2. -. (Deg>>Rad) wind_dir_adj#value in
    let wind_east = wind_speed_adj#value *. cos wind_dir_rad
    and wind_north = wind_speed_adj#value *. sin wind_dir_rad in
    [ "wind_east", Pprz.Float wind_east;
	       "wind_north", Pprz.Float wind_north;
	       "ir_contrast", Pprz.Float infrared_contrast_adj#value;
	       "time_scale", Pprz.Float time_scale#value ] in
  let world_send = fun () ->
    Ground_Pprz.message_send my_id "WORLD_ENV" (world_values ()) in

  List.iter 
    (fun (a:GData.adjustment) -> ignore (a#connect#value_changed world_send))
    [time_scale; wind_dir_adj; wind_speed_adj; gust_norm_max_adj; 
     infrared_contrast_adj];
    

  let vbox = GPack.vbox ~packing:window#add () in

  let hbox = GPack.hbox ~packing:vbox#pack () in
  let _ =  GMisc.label ~text:"time scale:" ~packing:hbox#pack () in
  let ts = GEdit.spin_button ~adjustment:time_scale ~packing:hbox#add () in
        
  let hbox = GPack.hbox ~packing:vbox#pack () in
  ignore (GMisc.label ~text:"wind dir:" ~packing:hbox#pack ());
  ignore (GRange.scale `HORIZONTAL ~adjustment:wind_dir_adj ~packing:hbox#add ());

  let hbox = GPack.hbox ~packing:vbox#pack () in
  ignore (GMisc.label ~text:"wind speed:" ~packing:hbox#pack ());
  ignore (GRange.scale `HORIZONTAL ~adjustment:wind_speed_adj ~packing:hbox#add ());
  
  let hbox = GPack.hbox ~packing:vbox#pack () in
  ignore (GMisc.label ~text:"gust max speed:" ~packing:hbox#pack ());
  ignore (GRange.scale `HORIZONTAL ~adjustment:gust_norm_max_adj ~packing:hbox#add ());


  let hbox = GPack.hbox ~packing:vbox#pack () in
  ignore (GMisc.label ~text:"infrared:" ~packing:hbox#pack ());
  ignore (GRange.scale `HORIZONTAL ~adjustment:infrared_contrast_adj ~packing:hbox#add ());

  Ivy.init "Paparazzi gaia" "READY" (fun _ _ -> ());
  Ivy.start !ivy_bus;

  ignore (Ground_Pprz.message_answerer my_id "WORLD_ENV" (fun _ _ -> world_values ()));

  window#show ();
  Unix.handle_unix_error GMain.Main.main ()
