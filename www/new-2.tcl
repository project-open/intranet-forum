# /packages/intranet-forum/www/intranet-forum/forum/new-2.tcl
#
# Copyright (C) 2003-2004 Project/Open
#
# All rights reserved. Please check
# http://www.project-open.com/license/ for details.

ad_page_contract {
    process a new topic form submission
    @param receive_updates: 
        all, none, major (=issue resolved, task done)
    @param actions: 
        accept, reject, clarify, close

    @action_type: 
        new_message, edit_message, undefined, reply_message

    @author frank.bergmann@project-open.com
} {
    topic_id:integer
    {actions ""}
    return_url
    { action_type ""}
    {comments:trim ""}
    {owner_id:integer 0}
    {old_asignee_id:integer 0}
    {object_id:integer 0}
    {parent_id:integer 0}
    {topic_type_id 0}
    {topic_status_id 0}
    {old_topic_status_id 0}
    {scope "pm"}
    {subject:trim ""}
    {message:trim,html ""}
    {priority "5"}
    {asignee_id:integer 0}
    {due_date:array,date ""}
    {receive_updates "major"}
    {read_p "f"}
    {folder_id "0"}
}

# ------------------------------------------------------------------
# Security, Parameters & Default
# ------------------------------------------------------------------

set user_id [ad_maybe_redirect_for_registration]

set exception_text ""
set exception_count 0

if { [info exists subject] && [string match {*\"*} $subject] } { 
    append exception_text "<li>Your topic name cannot include string quotes.  It makes life too difficult for this collection of software."
    incr exception_count
}

# check for not null start date
if { [info exists due_date(date) ] } {
   set due $due_date(date)
} else {
    set due ""
}

if { $exception_count> 0 } {
    ad_return_complaint $exception_count $exception_text
    return 0
}

# Only incidents and tasks have priority, status, asignees and 
# due_dates
#
set task_or_incident_p [im_forum_is_task_or_incident $topic_type_id]


# Optional comments are added to the message
if {"" != $comments} {
    set user_name [db_string get_user_name "select im_name_from_user_id(:user_id) from dual"]
    set today_date [db_string get_today_date "select sysdate from dual"]
    append message "\n\n\[Comment from $user_name on $today_date\]:\n$comments"
}


# ---------------------------------------------------------------------
# "Reply" to this topic
# ---------------------------------------------------------------------

# Forward to create a new reply topic...
if {[string equal $actions "reply"]} {
    set parent_id $topic_id
    ad_returnredirect "/intranet-forum/new?[export_url_vars parent_id return_url]"
    return
}


# ---------------------------------------------------------------------
# "Edit" the topic
# ---------------------------------------------------------------------

# Forward to "new"
if {[string equal $actions "edit"]} {
    ad_returnredirect "/intranet-forum/new?&[export_url_vars topic_id return_url]"
    return
}

# ------------------------------------------------------------------
# Save the im_forum_topics record
# ------------------------------------------------------------------

if {[string equal $actions "save"]} {

    # expect commands such as: "im_project_permissions" ...
    #
    set object_view 0
    set object_read 0
    set object_write 0
    set object_admin 0
    if {$object_id != 0} {
	set object_type [db_string acs_object_type "select object_type from acs_objects where object_id=:object_id" -default ""]
	if {"" != $object_type} {
	    set perm_cmd "${object_type}_permissions \$user_id \$object_id object_view object_read object_write object_admin"
	    eval $perm_cmd
	}
	if {!$object_read} {
	    ad_return_complaint 1 "You have no rights to add members to this object."
	    return
	}
    }

    if { ![info exists subject] || $subject == "" } {
	ad_return_complaint 1 "<li>You must enter a subject line"
	return
    }

    if {!$object_admin && $user_id != $owner_id } {
	ad_return_complaint 1 "<li>You have insufficient privileges to modify this topic"
	return
    }

    set exists_p [db_string exists "select count(*) from im_forum_topics where topic_id=:topic_id"]
    if {!$exists_p} {
	# Create an empty entry - 
	# Details are added at the insert below

	db_transaction {
	    db_dml topic_insert {
		insert into im_forum_topics (
			topic_id, object_id, topic_type_id, 
			topic_status_id, owner_id, subject
		) values (
			:topic_id, :object_id, :topic_type_id, 
			:topic_status_id, :owner_id, :subject
		)
	    }

	} on_error {
            ad_return_error "Error adding a new topic" "
	The database rejected the addition of discussion topic 
	\"$subject\". Here the error message: <pre>$errmsg\n</pre>\n"
            return
	}
    }

    # update the information
    db_transaction {
	db_dml topic_update "
update im_forum_topics set 
	object_id=:object_id, 
	parent_id=:parent_id,
	topic_type_id=:topic_type_id,
	topic_status_id=:topic_status_id,
	posting_date=sysdate,
	owner_id=:owner_id,
	scope=:scope, 
	subject=:subject,
	message=:message,
	priority=:priority, 
	asignee_id=:asignee_id, 
	due_date=:due
where topic_id=:topic_id"
    } on_error {
        ad_return_error "Error modifying a topic" "
	The database rejected the modification of a of discussion topic 
	'$subject'. Here the error message: <pre>$errmsg\n</pre>\n"
        return
    }

    # im_forum_topics_user_map may or may not exist for every user.
    # So we create a record just in case, even if the SQL fails.
    db_transaction {
        db_dml im_forum_topic_user_map_insert "
	insert into im_forum_topic_user_map 
	(topic_id, user_id, read_p, folder_id, receive_updates) values 
	(:topic_id, :user_id, :read_p, :folder_id, :receive_updates)"
    } on_error {
        # nothing - may already exist...
    }


    # Now let's update the existing entry
    db_transaction {
	db_dml im_forum_topic_user_map_update "
update im_forum_topic_user_map set 
	read_p=:read_p,
	folder_id=:folder_id, 
	receive_updates=:receive_updates
where 
	topic_id=:topic_id
	and user_id=:user_id"
    } on_error {
        ad_return_error "Error modifying a im_forum_topic_user_map" "
	The database rejected the modification of a of discussion topic 
	\"$subject\". Here the error message: <pre>$errmsg\n</pre>\n"
        return
    }
}


# ---------------------------------------------------------------------
# New Message: Subscribe all current project members
# ---------------------------------------------------------------------

# Only if we are creating a new message...
if {[string equal $action_type "new_message"]} {

    # .. and only if the parameter is enabled...
    if {[ad_parameter -package_id [im_package_forum_id] SubscribeAllMembersToNewItemsP "" "0"]} {

	# Select the list of all project members allowed to see
	# see the new TIND.
	#
	set object_member_sql "
select
	p.party_id as user_id
from
	acs_rels r,
	parties p,
	(select	m.member_id as user_id,
		1 as p
	 from group_distinct_member_map m
	 where	m.group_id = [im_customer_group_id]
	) customers,
	(select	m.member_id as user_id,
		1 as p
	 from group_distinct_member_map m
	 where	m.group_id = [im_employee_group_id]
	) employees
where
	r.object_id_one = 3273
	and r.object_id_two = p.party_id
	and p.party_id = customers.user_id(+)
	and p.party_id = employees.user_id(+)
        and 1 = im_forum_permission(
                p.party_id,
                :user_id,
                :asignee_id,
                :object_id,
                :scope,
		1,
		0,
                employees.p,
		customers.p
        )"

	db_foreach subscribe_object_members $object_member_sql {

	    ns_log Notice "intranet-forum/new-2: subscribe user\#$user_id to message\#$topic_id in object\#$object_id"

	    # im_forum_topics_user_map may or may not exist for every user.
	    # So we create a record just in case, even if the SQL fails.
	    db_transaction {
		db_dml im_forum_topic_user_map_insert "
	            insert into im_forum_topic_user_map
	            (topic_id, user_id, read_p, folder_id, receive_updates) values
	            (:topic_id, :user_id, :read_p, :folder_id, 'all')
	    "
	    } on_error {
		# nothing - may already exist...
	    }
	}
    }
}


# ---------------------------------------------------------------------
# Assign the ticket to a new user
# ---------------------------------------------------------------------

if {[string equal $actions "assign"]} {

    set topic_status_id [im_topic_status_id_assigned]

    # update the information
    db_transaction {
	db_dml topic_update "
update im_forum_topics set
        asignee_id = :asignee_id,
        topic_status_id = :topic_status_id
where topic_id=:topic_id"
    } on_error {
	ad_return_error "Error modifying a topic" "
        The database rejected the modification of a of discussion topic
        \"$subject\". Here the error message: <pre>$errmsg\n</pre>\n"
        return
    }
}


# ---------------------------------------------------------------------
# Close the ticket
# ---------------------------------------------------------------------

if {[string equal $actions "close"]} {
    # ToDo: Security Check
    
    # Close the existing ticket.
    set topic_status_id [im_topic_status_id_closed]
    db_transaction {
	db_dml topic_close "
update im_forum_topics set topic_status_id = :topic_status_id
where topic_id=:topic_id"
    } on_error {
        ad_return_error "Error modifying a topic" "
	Error closing \"$subject\": <pre>$errmsg\n</pre>\n"
	return
    }
}


# ---------------------------------------------------------------------
# "Clarify" the ticket
# ---------------------------------------------------------------------

if {[string equal $actions "clarify"]} {
    # ToDo: Security Check
    
    # Close the existing ticket.
    set topic_status_id [im_topic_status_id_needs_clarify]
    db_transaction {
	db_dml topic_close "
update im_forum_topics set topic_status_id = :topic_status_id
where topic_id=:topic_id"
    } on_error {
        ad_return_error "Error modifying a topic" "
	Error closing \"$subject\": <pre>$errmsg\n</pre>\n"
	return
    }
}


# ---------------------------------------------------------------------
# Reject the ticket
# ---------------------------------------------------------------------

if {[string equal $actions "reject"]} {
    # ToDo: Security Check
    
    # Mark ticket as rejected
    set topic_status_id [im_topic_status_id_rejected]
    db_transaction {
	db_dml topic_close "
update im_forum_topics set topic_status_id = :topic_status_id
where topic_id=:topic_id"
    } on_error {
        ad_return_error "Error modifying a topic" "
	Error closing \"$subject\": <pre>$errmsg\n</pre>\n"
	return
    }

}


# ---------------------------------------------------------------------
# Accept the ticket
# ---------------------------------------------------------------------

if {[string equal $actions "accept"]} {
    # ToDo: Security Check
    
    # Set the status to "accepted"
    set topic_status_id [im_topic_status_id_accepted]
    db_transaction {
	db_dml topic_close "
update im_forum_topics set topic_status_id = :topic_status_id
where topic_id=:topic_id"
    } on_error {
        ad_return_error "Error modifying a topic" "
	Error closing \"$subject\": <pre>$errmsg\n</pre>\n"
	return
    }
}


# ---------------------------------------------------------------------
# Alert about changes
# ---------------------------------------------------------------------

set msg_url "[ad_parameter -package_id [ad_acs_kernel_id] SystemURL "" ""]intranet-forum/view?topic_id=$topic_id"
set importance 0

db_1row subject_message "
select
	t.subject,
	t.message,
	t.parent_id,
	im_category_from_id(t.topic_type_id) as topic_type
from 
	im_forum_topics t
where
	t.topic_id = :topic_id
"

# Check for the root-parent message in order to determine
# whethter the user has subscribed to it or not.
set ctr 0
while {"" != $parent_id && 0 != $parent_id && $ctr < 10} {
    ns_log Notice "intranet-forum/new-2: looking up parent $parent_id of topic $topic_id"

    # avoid infinite loops...
    incr ctr

    set lookup_parent_sql "
	select
		t.topic_id,
		t.parent_id
	from
		im_forum_topics t
	where
		t.topic_id = :parent_id
    "
    db_0or1row lookup_parent $lookup_parent_sql
}


# Determine whether the update was "important" or not
# 0=none, 1=non-important, 2=important
#

switch $action_type {
    "new_message" { 
	set importance 2
	set subject "New $topic_type: $subject"
	set message "
A new $topic_type has been created.
Please visit the link above for details.\n"
    }

    "edit_message" { 
	set importance 1
	set subject "Changed $topic_type: $subject"
	set message "
A $topic_type has been modified.
Please visit the link above for details.\n"
    }

    "reply_message" { 
	set importance 1
	set subject "Reply to $topic_type: $subject"
	set message "
A $topic_type reply has been created.
Please visit the link above for details.\n"
    }
}



switch $actions {
    "accept" { 
	set importance 1
	set subject "Accepted $topic_type: $subject"
	set message "
The $topic_type has been accepted by the asignee.
Please visit the link above for details.
"
    }
    "reject" { 
	set importance 2
	set subject "Rejected $topic_type: $subject"
	set message "
The $topic_type has been rejected by the asignee.
Please visit the link above for details.
"
    }
    "clarify" { 
	set importance 2
	set subject "$topic_type needs clarification: $subject"
	set message "
The asignee of the $topic_type needs clarification.
Please visit the link above for details.
"
    }
    "save" { 
	set importance 1
	set subject "Modified $topic_type: $subject"
	set message "
The $topic_type has been modified or replied to.
Please visit the link above for details.
"
    }
    "close" { 
	set importance 2
	set subject "Closed $topic_type: $subject"
	set message "
The $topic_type has been closed.
Please visit the link above for details.
"
    }
    "assign" { 
	set importance 1
	set subject "Assigned $topic_type: $subject"
	set message "
The $topic_type has been assigned to a new asignee.
Please visit the link above for details.
"
    }
}

# Send a mail to all subscribed users
#
set stakeholder_sql "
select	user_id as stakeholder_id
from	im_forum_topic_user_map m
where	m.topic_id=:topic_id
	and receive_updates <> 'none'"

db_foreach update_stakeholders $stakeholder_sql {

#    if {$importance == 0} { continue }
#    if {[string compare $receive_updates "none"]} { continue }
#    if {$importance < 2 && [string compare $receive_updates "major"]} { continue }

    im_send_alert $stakeholder_id "hourly" $subject "$msg_url\n\n$message"
}

db_release_unused_handles 
ad_returnredirect $return_url

