val toss : 'a -> 'b
val id : 'a -> 'b
val debug : 'a -> 'b
val info : 'a -> 'b
val notice : 'a -> 'b
val warning : 'a -> 'b
val error : 'a -> 'b
val fatal : 'a -> 'b
val jquery_on : string -> string -> 'a -> 'b
val option_string : string option -> Js.js_string Js.t Js.opt
val plotPNG : string -> string -> string -> string option -> 'a
val plotSVG : string -> string -> string -> string option -> 'a
val saveFile : data:string -> mime:string -> filename:string -> unit
type meth = [ `DELETE | `GET | `HEAD | `OPTIONS | `PATCH | `POST | `PUT ]
val method_to_string : meth -> string
val ajax_request :
  ?timeout:float ->
  url:string ->
  meth:meth -> ?data:string -> handler:(int -> string -> unit) -> 'a
val async : string -> (unit -> unit Lwt.t) -> unit
val guid : unit -> string
val modal : id:string -> action:string -> unit
val element_data :
  Dom_html.element Js.t -> string -> Js.js_string Js.t Js.opt
val create_sort : string -> (Dom_html.event Js.t -> 'b -> unit) -> unit
val children_value :
  Dom_html.element Js.t ->
  string -> (Dom_html.element Js.t -> 'a) -> 'a list
val hide_codemirror : unit -> unit
val show_codemirror : unit -> unit
