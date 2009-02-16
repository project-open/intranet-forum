# /packages/intranet-forum//www/assign.tcl
#
# Copyright (C) 2003 - 2009 ]project-open[
#
# All rights reserved. Please check
# http://www.project-open.com/license/ for details.

ad_page_contract {
    Assign the task or incident to a different user.

    @author frank.bergmann@project-open.com
} {
    {topic_id:integer 0}
    return_url
} 

# ------------------------------------------------------------------
# Default
# ------------------------------------------------------------------

set user_id [ad_maybe_redirect_for_registration]

set bgcolor(0) " class=roweven"
set bgcolor(1) " class=rowodd"

db_1row get_topic "
select
	t.*,
	m.read_p,
	m.folder_id,
	m.receive_updates,
	im_category_from_id(t.topic_status_id) as topic_status,
	im_category_from_id(t.topic_type_id) as topic_type,
	im_name_from_user_id(t.owner_id) as owner_name,
	im_name_from_user_id(t.asignee_id) as asignee_name,
	acs_object.name(t.object_id) as object_name
from
	im_forum_topics t,
        (select * from im_forum_topic_user_map where user_id=:user_id) m
where
	t.topic_id=:topic_id
	and t.topic_id=m.topic_id(+)
"

# expect commands such as: "im_project_permissions" ...
#
if {$object_id != 0} {
    # We are adding the topic to a "real" object
    set object_type [db_string acs_object_type "select object_type from acs_objects where object_id=:object_id"]
    set perm_cmd "${object_type}_permissions \$user_id \$object_id object_view object_read object_write object_admin"
    eval $perm_cmd
} else {
    # We've been called from /intranet/home without 
    # an object => Yes, we are allowed to create topics.
    set object_view 1
    set object_read 1
    set object_write 0
    set object_admin 0
}

# Permission for forums:
# A user can create messages for basically every object
# he/she can read.
# However, the choice of receipients of the topics depend
# on the relatioinship between the user and the object.
if {!$object_read} {
    ad_return_complaint 1 "You have insufficient reights to see this page."
    return
}

# Only incidents and tasks have priority, status, asignees and
# due_dates
#
set task_or_incident_p [im_forum_is_task_or_incident $topic_type_id]
if {!$task_or_incident_p} {
    ad_return_complaint 1 "[_ intranet-forum.lt_This_topic_is_not_a_t]"
    return
}


# ------------------------------------------------------------------
# Render Form
# ------------------------------------------------------------------

# Save the old value for asingee_id and status_id to allow 
# new-2.tcl to alert owners and asignee about these changes.
set old_asignee_id $asignee_id

# ------------------------------------------------------------------
# Format the page body
# ------------------------------------------------------------------

set ctr 1
set table_body ""


# -------------- Asignee -----------------------------
# For Incidents and Tasks and only.


# calculate the list of potential asignees ( id-name pairs ) 
# based on user permissions, the project members and the PM.
set asignee_list [im_forum_potential_asignees $user_id $object_id]

# Build a select box to let the user chose
append table_body "
	<tr $bgcolor([expr $ctr % 2])>
	  <td>[_ intranet-forum.Assign_to]:</td>
	  <td>
	    [im_select -translate_p 0 asignee_id $asignee_list $asignee_id]
	  </td>
	</tr>\n"
incr ctr

append table_body "
	<tr $bgcolor([expr $ctr % 2])>
	  <td></td>
	  <td>
	    <input type=submit value=\"[_ intranet-forum.Assign]\">
	  </td>
	</tr>\n"
incr ctr





# -------------- Table and Form Start -----------------------------

set actions "assign"

set page_body "
<form action=new-2 method=POST>
[export_form_vars topic_id old_asignee_id actions return_url]

<table cellspacing=1 border=0 cellpadding=1>

[im_forum_render_tind $topic_id $parent_id $topic_type_id $topic_type $topic_status_id $topic_status $owner_id $asignee_id $owner_name $asignee_name $user_id $object_id $object_name $object_admin $subject $message $posting_date $due_date $priority $scope $receive_updates $return_url]

<tr><td colspan=2>&nbsp;</td></tr>
$table_body
</table>
</form>

"

ad_return_template








