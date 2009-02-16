# /packages/intranet-forum//www/new.tcl
#
# Copyright (C) 2003 - 2009 ]project-open[
#
# All rights reserved. Please check
# http://www.project-open.com/license/ for details.

ad_page_contract {
    Create a new Task, Incident, News or Discussion (TIND)
    @param object_id: Project or Client to refer to
    @topic_type: "news", "disussion", "incident" or "task"
    @param display_style: 
	topic		= full topic (subject+message), no subtopics
	thread		= complete tree of subjects
	topic_thread	= full topic plus subtopics subjects
	full		= topic+all subtopics

    <ul>
    <li>In order to reply to an existing message you have to specify parent_id!=0
    </ul>
    @author frank.bergmann@project-open.com
} {
    {topic_id:integer 0}
    {parent_id:integer 0}
    {object_id:integer 0}
    {display_style "all"}
    {submit ""}
    {subject ""}
    {message ""}
    {topic_type_id 0}
    {asignee_id 0}
    {return_url ""}
} 

# ------------------------------------------------------------------
# Default
# ------------------------------------------------------------------

set user_id [ad_maybe_redirect_for_registration]
set object_name ""

set todays_date [lindex [split [ns_localsqltimestamp] " "] 0]
set bgcolor(0) " class=roweven"
set bgcolor(1) " class=rowodd"

# Get a suitable object_id if not defined
if {$object_id == 0} {
    if {$topic_id != 0} {
	set object_id [db_string topic_object "select object_id from im_forum_topics where topic_id=:topic_id"]
    }
    if {$parent_id != 0} {
	set object_id [db_string topic_object "select object_id from im_forum_topics where topic_id=:parent_id"]
    }
}

# Return to this page for edit actions, if not being called
# from another page.
if {"" == $return_url} {
    set return_url [im_biz_object_url $object_id]
}

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
    ad_return_complaint 1 "You have no rights to add members to this object."
    return
}

# ------------------------------------------------------------------
# New Message or Reply
# ------------------------------------------------------------------

set asignee_name ""
set action_type "undefined"
set topic_status_id ""
set done 0

# -------------- We are creating a reply message -----------------

if {!$done && $parent_id != 0} {
    set action_type "reply_message"

    # Get some information about the parent topic:
    set org_parent_id $parent_id
    db_1row get_topic_for_reply "
select
	t.*,
	acs_object.name(t.object_id) as object_name
from
	im_forum_topics t
where
	topic_id=:parent_id"
    set parent_id $org_parent_id

    # Overwrite the owner for the reply: the current user
    set owner_id $user_id

    # Replies are not assigned to anybody...
    set asignee_id ""
    set read_p "f"
    set folder_id 0

    # No updates on the _reply_, please
    set receive_updates "none"

    # Doubleclick protection: Create the new topic_id here
    set topic_id [db_nextval "im_forum_topics_seq"]

    set due_date $todays_date

    # This is a "Reply" message
    set topic_type_id [im_topic_type_id_reply]
    set topic_type "[_ intranet-forum.Reply]"
    set topic_status_id [im_topic_status_id_open]
    set topic_status "[_ intranet-forum.Open]"

    set submit_action "[_ intranet-forum.Create_topic_type]"
    set page_title "[_ intranet-forum.New_topic_type]"
    set context_bar [im_context_bar [list /intranet-forum/ "[_ intranet-forum.Forum]"] $page_title]
    set subject "[_ intranet-forum.Re_subject]"
    set message "[_ intranet-forum.Enter_message_body]"
    set done 1
}


# -------------- We are creating a new message -----------------

if {!$done && $topic_id == 0} {
    set action_type "new_message"

    # doubleclick protection: get the topic ID right now.
    set topic_id [db_nextval "im_forum_topics_seq"]

    # We can create new messages either within a project (object_id != 0)
    # or at the HomePage or the ForumPage (object_id == 0).
    # Let's get the object_name if object_id != 0:
    if {$object_id > 0} {
        set object_name [db_exec_plsql get_object_name "begin :1 := acs_object.name(object_id => :object_id); end;"]
    }
    
    set parent_id ""
    set read_p "f"
    set scope "pm"
    set folder_id 0
    set receive_updates "major"
    set topic_status_id [im_topic_status_id_open]
    set topic_status "[_ intranet-forum.Open]"
    set owner_id $user_id
    set asignee_id ""
    set due_date $todays_date
    set topic_type [lang::util::suggest_key [db_string topic_sql "select category from im_categories where category_id=:topic_type_id" -default ""]]
    set topic_type [_ intranet-forum.$topic_type]

    set submit_action "[_ intranet-forum.Create_topic_type]"
    set page_title "[_ intranet-forum.New_topic_type]"
    set context_bar [im_context_bar [list /intranet-forum/ "[_ intranet-forum.Forum]"] $page_title]

    set subject "[_ intranet-forum.Enter_subject]"
    #set message "[_ intranet-forum.Enter_message_body]"
    set  message ""
    set done 1
}


# -------------- We are editing an already existing message-------------

if {!$done && $topic_id != 0} {
    set action_type "edit_message"
    set topic_sql "
select
	t.*,
	m.read_p,
	m.folder_id,
	m.receive_updates,
	im_name_from_user_id(t.owner_id) as user_name,
	im_name_from_user_id(t.asignee_id) as asignee_name,
	acs_object.name(t.object_id) as object_name,
	ftc.category as topic_type,
	sc.category as topic_status
from
	im_forum_topics t,
        (select * from im_forum_topic_user_map where user_id=:user_id) m,
	im_categories ftc,
	im_categories sc
where
	t.topic_id=:topic_id
	and t.topic_id=m.topic_id(+)
	and t.topic_status_id=sc.category_id(+)
	and t.topic_type_id=ftc.category_id(+)
"

     db_1row get_topic $topic_sql
     if {$due_date == ""} { set due_date $todays_date }
     set submit_action "[_ intranet-forum.Save_Changes]"
     set page_title "[_ intranet-forum.Edit_Topic]"
     set context_bar [im_context_bar [list /intranet-forum/ "[_ intranet-forum.Forum]"] $page_title]
     set done 1
}


# Only incidents and tasks have priority, status, asignees and 
# due_dates
#
set task_or_incident_p 0
if {$topic_type_id == 1102 || $topic_type_id == 1104} {
    set task_or_incident_p 1
}

# Save the old value for asingee_id and status_id to allow 
# new-2.tcl to alert owners and asignee about these changes.
set old_asignee_id $asignee_id
set old_topic_status_id $topic_status_id

ns_log Notice "new: action_type=$action_type"
ns_log Notice "new: topic_status_id=$topic_status_id, old_topic_status_id=$old_topic_status_id"


# ------------------------------------------------------------------
# Format the page body
# ------------------------------------------------------------------

# During the course of the formatting, we will find that several
# variables are already specified, for example due to URL parameters
# or due to access restrictions of the user. These variables just
# have to be passed on to the next page, using hidden input fields.
# However, we only know at the end of the "body formatting" what
# variables to pass on, so that we will format the table and form
# headers at the end.

set ctr 1
set table_body ""
set export_var_list [list owner_id old_asignee_id parent_id topic_id return_url action_type read_p folder_id topic_status_id]

# -------------- Topic Type -----------------------------

# We have to render a select box for it 
# if it hasn't been specified in the URL.

if {!$topic_type_id} {
     append table_body "
	 <tr $bgcolor([expr $ctr % 2])>
	   <td>[_ intranet-forum.Topic_Type]</td>
	   <td>
	     [im_forum_topic_type_select topic_type_id]
	   </td>
	 </tr>"
} else {
     lappend export_var_list "topic_type_id"
     append table_body "
	 <tr $bgcolor([expr $ctr % 2])>
	   <td>[_ intranet-forum.Topic_Type]</td>
	   <td valign=center>
	     [im_gif $topic_type_id "$topic_type"] 
	     $topic_type
	   </td>
	 </tr>\n"
 }
incr ctr


# -------------- Subject Line -----------------------------

# Show editing widgets when we are editing a new page
# and for the owner (to make changes to his text).
#
append table_body "
	 <tr $bgcolor([expr $ctr % 2])>
	   <td>[_ intranet-forum.topic_type_Subject]</td>
	   <td>
	     <input type=text size=50 name=subject value=\"$subject\">
	   </td>
	 </tr>\n"
incr ctr


# -------------- Object -----------------------------

# New messages created from HomePage or ForumIndexPage 
# don't have a group (project) assigned. So we have to do
# that here:

if {$object_id == 0} {
    append table_body "
	<tr $bgcolor([expr $ctr % 2])>
	  <td>[_ intranet-forum.In_Project]</td>
	  <td>[im_project_select -exclude_subprojects_p 0 object_id $object_id]</td>
	</tr>\n"
    incr ctr
} else {
    append table_body "
	<tr $bgcolor([expr $ctr % 2])>
	  <td>[_ intranet-forum.Posted_in]</td>
          <td><A href=[im_biz_object_url $object_id]>$object_name</td>
	</tr>\n"
    incr ctr
    lappend export_var_list "object_id"
}


# -------------- Priority -----------------------------
# Only incidents and tasks have priority, status, asignees 
# and due_dates

if {$task_or_incident_p} {
    append table_body "
	<tr $bgcolor([expr $ctr % 2])>
	  <td>[_ intranet-forum.Priority]</td>
	  <td>
		<select name=priority>
		<option value=1>1 - [_ intranet-forum.Emergency]</option>
		<option value=2>2 - [lang::message::lookup "" intranet-forum.Very_Urgent "Very Urgent"]</option>
		<option value=3>3 - [_ intranet-forum.Urgent]</option>
		<option value=4>4 - [_ intranet-forum.High_Normal]</option>
		<option value=5 selected>5 - [_ intranet-forum.Normal]</option>
		<option value=6>6 - [_ intranet-forum.Low_Normal]</option>
		<option value=7>7 - [_ intranet-forum.Not_that_urgent]</option>
		<option value=8>8 - [_ intranet-forum.Needs_to_be_done]</option>
		<option value=9>9 - [_ intranet-forum.Optional]</option>
		</select>
	  </td></tr>"
    incr ctr
}


# -------------- Asignee -----------------------------
# For Incidents and Tasks and only.

if {$task_or_incident_p} {

    # calculate the list of potential asignees ( id-name pairs ) 
    # based on user permissions, the project members and the PM.
    set asignee_list [im_forum_potential_asignees $user_id $object_id]
    ns_log Notice "intranet-forum/new: asignee_list=$asignee_list"

    if {2 == [llength $asignee_list]} {
	# only the PM is available: pass the variable on
	set asignee_id [lindex $asignee_list 0]
	lappend export_var_list "asignee_id"

	append table_body "
	<tr $bgcolor([expr $ctr % 2])>
	  <td>[_ intranet-forum.Assign_to]</td>
	  <td>[lindex $asignee_list 1]</td>
	</tr>\n"
	incr ctr

    } else {
	# Build a select box to let the user chose
	append table_body "
	<tr $bgcolor([expr $ctr % 2])>
	  <td>[_ intranet-forum.Assign_to]</td>
	  <td>
	    [im_select -translate_p 0 asignee_id $asignee_list $asignee_id]
	  </td>
	</tr>\n"
	incr ctr
    }
}


# -------------- Due Date -----------------------------
# Only for tasks and Incidents

if {$task_or_incident_p} {

    append table_body "
	<tr $bgcolor([expr $ctr % 2])>
	  <td>[_ intranet-forum.Due_Date]</td>
	  <td>[philg_dateentrywidget due_date $due_date]</td>
	</tr>\n"
    incr ctr
}

# -------------- Status -----------------------------

# If this is a new message, then the status is either "Open"
# for discussions and news or "Assigned" for tasks & incidents.
#
# In general, status changes are introduced by action buttons,
# so we don't show a status select box here.

if {[string equal $action_type "new_message"]} {
    if {$task_or_incident_p} {
	# A new taks/incident is in status "Assigned"
	set topic_status_id [im_topic_status_id_assigned]
    } else {
	# It's a discussion or news item without attached workflow,
	# So the status is "open".
	set topic_status_id [im_topic_status_id_open]
    }
}


# -------------- Message Body -----------------------------

set html_p "f"

append table_body "
	<tr $bgcolor([expr $ctr % 2])>
	  <td>$topic_type [_ intranet-forum.Body]</td>
	  <td>
	    <textarea name=message rows=5 cols=50 wrap=[im_html_textarea_wrap]>$message</textarea>
	  </td>
	</tr>\n"

incr ctr


# -------------- Scope -----------------------------

# Default is "group", if the user can do it...
if {[im_permission $user_id add_topic_group]} {set scope "group"}

if {$topic_type_id != [im_topic_type_id_reply]} {

    if {$object_admin || $user_id == $owner_id} {
	append table_body "
		<tr $bgcolor([expr $ctr % 2])>
		  <td>[_ intranet-forum.Access_permissions]</td>
		  <td>
                    [im_forum_scope_select "scope" $user_id $scope]
		  </td>
		</tr>"
	incr ctr
    } else {
	append table_body "
		<tr $bgcolor([expr $ctr % 2])>
		  <td>[_ intranet-forum.Access_permissions]</td>
		  <td>[im_forum_scope_html $scope]
		  </td>
		</tr>"
	incr ctr

    }
}

# -------------- Receive Notifications -----------------------------

if {$topic_type_id != [im_topic_type_id_reply]} {
    append table_body "
	<tr $bgcolor([expr $ctr % 2])>
	  <td>[_ intranet-forum.lt_Do_you_want_to_receiv]</td>
	 <td>[im_forum_notification_select "receive_updates" $receive_updates]</td>
	</tr>"
    incr ctr
}


# -------------- Action Area -----------------------------
# Possible editing actions include:
# - Save Changes
# - Create new topic

# Possible view actions include
# - Reply
# - Accept or Reject ("pending" task or incident)
# - Close the ticket (the owner and PM of an incident)


# Apart from just saving changes we allow the user to reply
# to the topic, depending on role and topic status.

set actions ""
append actions "<option value=save selected>$submit_action</option>\n"

append table_body "
	<tr $bgcolor([expr $ctr % 2])>
	  <td>[_ intranet-forum.Actions]</td>
	  <td>
	    <select name=actions>
	    $actions
	    </select>
	    <input type=submit value=\"Apply\">
	  </td>
	</tr>\n"
incr ctr


# -------------- Render Parent Message -----------------------------
# Render parent in case of a reply message

set rendered_parent_html ""
if {$topic_type_id == [im_topic_type_id_reply]} {

    set parent_topic_sql "
	select
	        t.topic_id as parents_topic_id,
		t.topic_status_id as parents_topic_status_id,
		t.topic_type_id as parents_topic_type_id,
	        im_category_from_id(t.topic_status_id) as parents_topic_status,
	        im_category_from_id(t.topic_type_id) as parents_topic_type,
	        im_name_from_user_id(t.owner_id) as parents_owner_name,
	        im_name_from_user_id(t.asignee_id) as parents_asignee_name,
	        acs_object__name(t.object_id) as parents_object_name,
		t.parent_id as parents_parent_id,
		t.owner_id as parents_owner_id,
		t.asignee_id as parents_asignee_id,
		t.object_id as parents_object_id,
		t.subject as parents_subject,
		t.message as parents_message,
		t.posting_date as parents_posting_date,
		t.due_date as parents_due_date,
		t.priority as parents_priority,
		t.scope as parents_scope,
		m.receive_updates as parents_receive_updates
	from
	        im_forum_topics t
		LEFT OUTER JOIN (
			select * 
			from im_forum_topic_user_map 
			where user_id = :user_id
		) m ON t.topic_id = m.topic_id
	where
	        t.topic_id = :parent_id
    "
    db_1row get_parent_topic $parent_topic_sql

    set parents_object_admin $object_admin

    set rendered_parent [im_forum_render_tind $parent_id $parents_parent_id $parents_topic_type_id $parents_topic_type $parents_topic_status_id $parents_topic_status $parents_owner_id $parents_asignee_id $parents_owner_name $parents_asignee_name $user_id $parents_object_id $parents_object_name $parents_object_admin $parents_subject $parents_message $parents_posting_date $parents_due_date $parents_priority $parents_scope $parents_receive_updates $return_url]

    set rendered_parent_html "
	<h2>[lang::message::lookup "" intranet-forum.Original_Message "Original Message"]</h2>
	<blockquote>
	<table>
	$rendered_parent
	</table>
	</blockquote>
    "
}


