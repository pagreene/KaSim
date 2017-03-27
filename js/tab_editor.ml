(******************************************************************************)
(*  _  __ * The Kappa Language                                                *)
(* | |/ / * Copyright 2010-2017 CNRS - Harvard Medical School - INRIA - IRIF  *)
(* | ' /  *********************************************************************)
(* | . \  * This file is distributed under the terms of the                   *)
(* |_|\_\ * GNU Lesser General Public License Version 3                       *)
(******************************************************************************)

module Html = Tyxml_js.Html5

let navli () = []
let rightsubpanel_id : string = "rightsubpanel"
let rightsubpanel () =
  Html.div
    ~a:[ Tyxml_js.R.Html.a_class
           (React.S.bind
              Subpanel_editor.editor_full
              (fun editor_full ->
                 React.S.const
                   (if editor_full then
                      ["hidden"]
                    else
                      ["col-md-6"; "hidden-xs"; "hidden-sm"])
              )
           )
       ]
    [Ui_common.navtabs "subnavtab"
       [ "contact", (Tab_contact.navli ())
       ; "log",     (Tab_log.navli ()) ];
     Ui_common.navcontent
       ~id:rightsubpanel_id
       []
       [ "contact", (Tab_contact.content ())
       ; "log",     (Tab_log.content ()) ]]

let content () =
  [Html.div ~a:[Html.a_class ["row"]]
     [Html.div
        ~a:[ Tyxml_js.R.Html.a_class
               (React.S.bind
                  Subpanel_editor.editor_full
                  (fun editor_full ->
                     React.S.const
                       (if editor_full then
                          ["col-md-12"]
                        else
                          ["col-md-6"])
                  )
               )
           ]
        [Subpanel_editor.content ()];
      (rightsubpanel ()) ]]

let childs_hide b =
  if b then
    let () = Tab_contact.parent_hide () in
    Tab_log.parent_hide ()
  else
    let () = Tab_contact.parent_shown () in
    Tab_log.parent_shown ()

let onload () =
  let () = Subpanel_editor.onload () in
  let () = Tab_contact.onload () in
  let () = Tab_log.onload () in
  let _ = React.S.map childs_hide Subpanel_editor.editor_full in
  let () = Common.jquery_on
      "#naveditor" "hide.bs.tab" (fun _ -> childs_hide true) in
  let () = Common.jquery_on
      "#naveditor" "shown.bs.tab" (fun _ -> childs_hide false) in
  ()

let onresize () : unit =
  let () = Tab_log.onresize () in
  ()
