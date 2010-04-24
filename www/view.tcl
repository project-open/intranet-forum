# /packages/intranet-forum//www/view.tcl
#
# Copyright (C) 2003 - 2009 ]project-open[
#
# All rights reserved. Please check
# http://www.project-open.com/license/ for details.

ad_page_contract {
    View a Task, Incident, News or Discussion (TIND)
    @param object_id: Project or Client to refer to
    @topic_type: "news", "disussion", "incident" or "task"
    @param display_style: 
	topic		= full topic (subject+message), no subtopics
	thread		= complete tree of subjects
	topic_thread	= full topic plus subtopics subjects
	full		= topic+all subtopics

    @author fraber@project-open.com
    @author juanjoruizx@gmail.com
} {
    {topic_id:integer 0}
    {object_id:integer 0}
    {display_style "all"}
    {submit ""}
    {subject ""}
    {message ""}
    {topic_type_id 0}
    {asignee_id 0}
    {return_url ""}
    {edit_message_p 0}
} 

# ------------------------------------------------------------------
# Defaults
# ------------------------------------------------------------------


set user_id [ad_maybe_redirect_for_registration]
set object_name ""

set todays_date [lindex [split [ns_localsqltimestamp] " "] 0]
set bgcolor(0) " class=roweven"
set bgcolor(1) " class=rowodd"

set date_format "YYYY-MM-DD"

# Return to this page for edit actions, if not being called
# from another page.
if {"" == $return_url} {
    set return_url [im_url_with_query]
}



# ------------------------------------------------------------------
# Get the message details
# ------------------------------------------------------------------



set action_type "edit_message"
set topic_sql "

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

db_0or1row get_topic $topic_sql
if {![info exists topic_id]} {
    ad_return_complaint 1 "
	[lang::message::lookup "" intranet-forum.Topic_doesnt_exist "
		<b>This forum topic doesn't exist</b>:<br>
		Maybe somebody has deleted the topic?
    "]"
}

if {$due_date == ""} { set due_date $todays_date }
set old_asignee_id $asignee_id
set page_title "[_ intranet-forum.View_Topic]"
set context_bar [im_context_bar [list /intranet-forum/ "[_ intranet-forum.Forum]"] $page_title]



# ------------------------------------------------------------------
# Permissions
# ------------------------------------------------------------------

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

ns_log Notice "view: object_id=$object_id"
ns_log Notice "view: object_view=$object_view"
ns_log Notice "view: object_read=$object_read"
ns_log Notice "view: object_write=$object_write"
ns_log Notice "view: object_admin=$object_admin"


# Permission for forums:
# A user can create messages for basically every object
# he/she can read.
# However, the choice of receipients of the topics depend
# on the relatioinship between the user and the object.
if {!$object_read} {

    ad_return_complaint 1 "[_ intranet-forum.lt_You_have_no_rights_to]"
    return
}





# Only incidents and tasks have priority, status, asignees and 
# due_dates
#
set task_or_incident_p [im_forum_is_task_or_incident $topic_type_id]

set ctr 1

# ------------------------------------------------------------------
# Render the message
# ------------------------------------------------------------------

append table_body [im_forum_render_tind $topic_id $parent_id $topic_type_id $topic_type $topic_status_id $topic_status $owner_id $asignee_id $owner_name $asignee_name $user_id $object_id $object_name $object_admin $subject $message $posting_date $due_date $priority $scope $receive_updates $return_url]


# -------------- Action Area -----------------------------
# Possible editing actions include:(new.tcl)
# - Save Changes
# - Create new topic

# Possible view actions include (view.tcl)
# - Reply
# - Assign to (the owner and PM of an incident)
# - Accept or Reject ("pending" task or incident, the assignee)
# - Close the ticket (the owner and PM of an incident and the assignee)
# - Needs Clarify (the assignee)

set actions ""

if {$task_or_incident_p && $user_id == $asignee_id} {
    # Add Accept/Reject for "assigned" tasks
    if {$topic_status_id == [im_topic_status_id_assigned]} {
	# Asignee has not "accepted" yet
	append actions "<option value=accept>[_ intranet-forum.Accept_topic_type]</option>\n"
	append actions "<option value=reject>[_ intranet-forum.Reject_topic_type]</option>\n"
    }

    # Allow to mark task as "closed" only after accepted
    # 061114 fraber: Not anymore - really a hassle
    if {![string equal $topic_status_id [im_topic_status_id_closed]]} {
	append actions "<option value=close>[_ intranet-forum.Close_topic_type]</option>\n"
    }

    # Always allow to ask for clarification from owner if not already in clarify
    if {![string equal $topic_status_id [im_topic_status_id_needs_clarify]] && ![string equal $topic_status_id [im_topic_status_id_closed]]} {
    	append actions "<option value=clarify>[_ intranet-forum.lt_topic_type_needs_clar]</option>\n"
    }
}


append actions "<option value=reply selected>[_ intranet-forum.lt_Reply_to_this_topic_t]</option>\n"

# Only admins can edit the message
set assign_hidden ""
if {$object_admin || $user_id==$owner_id} {
    append actions "<option value=edit>[_ intranet-forum.Edit_topic_type]</option>\n"
    if {$task_or_incident_p && $topic_status_id == [im_topic_status_id_needs_clarify]} {
    	append actions "<option value=assign>[_ intranet-forum.Re_assign_topic]</option>\n"
    	#assignee does not change
    	set assign_hidden "<input type=hidden name=asignee_id value=$asignee_id>"
    }
    # owner can also close topic
    if {$user_id != $asignee_id && ![string equal $topic_status_id [im_topic_status_id_closed]]} {
    	append actions "<option value=close>[_ intranet-forum.Close_topic_type]</option>\n"
    }
}



append table_body "
	<tr $bgcolor([expr $ctr % 2])>
	  <td>[_ intranet-forum.Actions]</td>
	  <td>
	    <select name=actions>
	    $actions
	    </select>
	    <input type=submit value=\"[_ intranet-forum.Apply]\">
	  </td>
	</tr> $assign_hidden \n"
incr ctr

# -------------- Table and Form Start -----------------------------

set thread_html [im_forum_render_thread $topic_id $user_id $object_id $object_name $object_admin $return_url]

set page_body "
<form action=new-2 method=POST>
[export_form_vars action_type owner_id old_asignee_id object_id topic_id parent_id subject message return_url topic_status_id topic_type_id]

<table cellspacing=1 border=0 cellpadding=1>
$table_body
</table>
</form>

$thread_html
"





