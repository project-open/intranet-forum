# /packages/intranet-forum/www/intranet-forum/forum/new-2.tcl
#
# Copyright (C) 2003-2009 ]project-open[
#
# All rights reserved. Please check
# http://www.project-open.com/license/ for details.

ad_page_contract {
    process a new topic form submission
    @param receive_updates: all, none, major (=issue resolved, task done)
    @param actions: accept, reject, clarify, close
    @action_type: new_message, edit_message, undefined, reply_message

    @author frank.bergmann@project-open.com
    @author juanjoruizx@yahoo.es
} {
    topic_id:integer
    {actions ""}
    return_url
    { action_type ""}
    {comments:trim ""}
    {owner_id:integer 0}
    {old_asignee_id:integer 0}
    {object_id:integer 0}
    {parent_id:integer "[db_null]"}
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

set topic_type [db_string topic_type "select im_category_from_id(:topic_type_id)" -default ""]
set object_type [db_string acs_object_type "select object_type from acs_objects where object_id = :object_id" -default ""]
set page_title "[_ intranet-forum.New_topic_type]"
set context_bar [im_context_bar [list /intranet-forum/ "[_ intranet-forum.Forum]"] $page_title]

# ------------------------------------------------------------------
# 
# ------------------------------------------------------------------

set include_topic_message_p [ad_parameter -package_id [im_package_forum_id] "IncludeTopicMessageInNotificationsP" "" 0]
set exception_text ""
set exception_count 0

regsub -all {\"+} $subject "" subject

# if { [info exists subject] && [string match {*\"*} $subject] } { 
#    append exception_text "<li>Your topic name cannot include string quotes.  It makes life too difficult for this collection of software."
#    incr exception_count
# }

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


set forum_folder_count [db_string forum_folder_count "select count(*) from im_forum_folders"]
if {!$forum_folder_count} {
    ad_return_complaint 1 "<b>Forum Folders not Setup</b>:<p>
        Your system has a configuration issue.<br>
        Please notify your system administrator and tell him to execute the update script
        'psql -f \[PATH_TO_PACKAGES\]/packages/intranet-forum/sql/postgresql/upgrade/upgrade-3.2.3.0.0-3.2.4.0.0.sql'.
    "
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
	ad_return_complaint 1 "<li>[_ intranet-forum.lt_You_have_insufficient]"
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
            ad_return_error "[_ intranet-forum.lt_Error_adding_a_new_to]" "
	[_ intranet-forum.lt_The_database_rejected] 
	[_ intranet-forum.lt_Here_the_error_messag]: <pre>$errmsg\n</pre>\n"
            return
	}
    }

    set today [db_string get_sysdate "select sysdate from dual"]

    # update the information
    db_transaction {
	db_dml topic_update "
	update im_forum_topics set 
		object_id=:object_id, 
		parent_id=:parent_id,
		topic_type_id=:topic_type_id,
		topic_status_id=:topic_status_id,
		posting_date=:today,
		owner_id=:owner_id,
		scope=:scope, 
		subject=:subject,
		message=:message,
		priority=:priority, 
		asignee_id=:asignee_id, 
		due_date=:due
	where topic_id=:topic_id
	"
    } on_error {
        ad_return_error "[_ intranet-forum.lt_Error_modifying_a_top]" "
	[_ intranet-forum.lt_The_database_rejected_1] 
	[_ intranet-forum.lt_Here_the_error_messag]: <pre>$errmsg\n</pre>\n"
        return
    }

    # im_forum_topics_user_map may or may not exist for every user.
    # So we create a record just in case.
    set exists_p [db_string topic_map_exists "
	select	count(*)
	from	im_forum_topic_user_map
	where	topic_id = :topic_id
		and user_id = :user_id
    "]
    if {!$exists_p} {
	db_transaction {
	    db_dml im_forum_topic_user_map_insert "
		insert into im_forum_topic_user_map 
		(topic_id, user_id, read_p, folder_id, receive_updates) values 
		(:topic_id, :user_id, :read_p, :folder_id, :receive_updates)
	    "
	} on_error {
	    # nothing - may already exist...
	}
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
		and user_id=:user_id
	"
    } on_error {
        ad_return_error "[_ intranet-forum.lt_Error_modifying_a_im_]" "
	[_ intranet-forum.lt_The_database_rejected_2] 
	[_ intranet-forum.lt_Here_the_error_messag]: <pre>$errmsg\n</pre>\n"
        return
    }
}


# ---------------------------------------------------------------------
# New Message: Subscribe all current project members
# ---------------------------------------------------------------------

# Only if we are creating a new message...
ns_log Notice "/intranet-forum/new-2: action_type=$action_type"
if {[string equal $action_type "new_message"]} {

    # .. and only if the parameter is enabled...
    if {[ad_parameter -package_id [im_package_forum_id] SubscribeAllMembersToNewItemsP "" "0"]} {
	ns_log Notice "/intranet-forum/new-2: subscribing all project members to the new message"

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
		) employees,
		-- get the members and admins of object_id
		(       select  1 as member_p,
				decode (m.object_role_id,
					1301, 1,
					1302, 1,
					1303, 1,
					0
				) as admin_p,
				r.object_id_two as user_id
			from    acs_rels r,
				im_biz_object_members m
			where   r.object_id_one = :object_id
				and r.rel_id = m.rel_id
		) o_mem
	where
		r.object_id_one = :object_id
		and r.object_id_two = p.party_id
		and p.party_id = customers.user_id(+)
		and p.party_id = employees.user_id(+)
		and o_mem.user_id = p.party_id
		and 1 = im_forum_permission(
			p.party_id,
			:user_id,
			:asignee_id,
			:object_id,
			:scope,
			o_mem.member_p,
			o_mem.admin_p,
			employees.p,
			customers.p
	)"

	db_foreach subscribe_object_members $object_member_sql {

	    ns_log Notice "intranet-forum/new-2: subscribe user\#$user_id to message\#$topic_id in object\#$object_id"

	    # im_forum_topics_user_map may or may not exist for every user.
	    # So we create a record just in case, even if the SQL fails.
	    set map_exists_p [db_string map_exists "
	        select  count(*)
	        from    im_forum_topic_user_map
	        where   topic_id = :topic_id
	                and user_id = :user_id
	    "]

	    if {!$map_exists_p} {
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
	ad_return_error "[_ intranet-forum.lt_Error_modifying_a_top]" "
        [_ intranet-forum.lt_The_database_rejected_2] 
	[_ intranet-forum.lt_Here_the_error_messag]: <pre>$errmsg\n</pre>\n"
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
        ad_return_error "[_ intranet-forum.lt_Error_modifying_a_top]" "
	[_ intranet-forum.lt_Error_closing_subject]: <pre>$errmsg\n</pre>\n"
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
        ad_return_error "[_ intranet-forum.lt_Error_modifying_a_top]" "
	[_ intranet-forum.lt_Error_closing_subject]: <pre>$errmsg\n</pre>\n"
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
        ad_return_error "[_ intranet-forum.lt_Error_modifying_a_top]" "
        [_ intranet-forum.lt_Error_closing_subject]: <pre>$errmsg\n</pre>\n"
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
        ad_return_error "[_ intranet-forum.lt_Error_modifying_a_top]" "
        [_ intranet-forum.lt_Error_closing_subject]: <pre>$errmsg\n</pre>\n"
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
	im_category_from_id(t.topic_type_id) as topic_type,
	o.object_type,
	acs_object__name(t.object_id) as object_name
from 
	im_forum_topics t,
	acs_objects o
where
	t.topic_id = :topic_id
	and t.object_id = o.object_id
"

# Check for the root-parent message in order to determine
# whether the user has subscribed to it or not.
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

set org_message ""
if {$include_topic_message_p} { set org_message "$message\n\n" }


set action_type_found 0
switch $action_type {
    "new_message" { 
	set action_type_found 1
	set importance 2
	set subject [lang::message::lookup "" intranet-forum.New_topic_in_object2 "New $topic_type in $object_name: $subject"]
	set message "
$org_message
[_ intranet-forum.lt_A_new_topic_type_has_]\n"
    }

    "reply_message" { 
	set action_type_found 1
	set importance 1
	set subject [lang::message::lookup "" intranet-forum.Reply_to_topic2 "Reply to $topic_type in $object_name: $subject"]
	set message "
$org_message
[_ intranet-forum.lt_A_new_topic_type_has_]\n"
    }
}

if {!$action_type_found} {

    switch $actions {
	"accept" { 
	    set importance 1
	    set subject "[_ intranet-forum.Accepted] $topic_type in $object_name: $subject"
	    set message "
$org_message
[_ intranet-forum.lt_A_new_topic_type_has_]\n"
	}
	"reject" { 
	    set importance 2
	    set subject "[_ intranet-forum.Rejected] $topic_type in $object_name: $subject"
	    set message "
$org_message
[_ intranet-forum.lt_A_new_topic_type_has_]\n"
	}
	"clarify" { 
	    set importance 2
	    set subject "$topic_type [_ intranet-forum.needs_clarification] in $object_name: $subject"
	    set message "
$org_message
[_ intranet-forum.lt_The_asignee_of_the_to]\n"
	}
	"save" { 
	    set importance 1
	    set subject "[_ intranet-forum.Modified] $topic_type in $object_name: $subject"
	    set message "
$org_message
[_ intranet-forum.lt_The_topic_type_has_be]"
	}
	"close" { 
	    set importance 2
	    set subject "[_ intranet-forum.Closed] $topic_type in $object_name: $subject"
	    set message "
$org_message
[_ intranet-forum.lt_The_topic_type_has_be_1]"
	}
	"assign" { 
	    set importance 1
	    set subject "[_ intranet-forum.Assigned] $topic_type in $object_name: $subject"
	    set message "
$org_message
[_ intranet-forum.lt_The_topic_type_has_be_2]"
	}
        default {
	    #  probably mistake with a unknown action type in "edit_message"
	    set importance 1
	    set subject [lang::message::lookup "" intranet-forum.Changed_topic_in_object "Changed $topic_type in $object_name: $subject"]
	    set message "
$org_message
[_ intranet-forum.lt_A_new_topic_type_has_]"
        }
    }
}



# ---------------------------------------------------------------------
# Allow the user to select to whom to send info mails
# ---------------------------------------------------------------------

set stakeholder_sql "
	select
		u.user_id,
		u.email,
		im_name_from_user_id(u.user_id) as name
	from
		im_forum_topic_user_map m,
		cc_users u
	where
		m.user_id = u.user_id
		and m.topic_id = :topic_id
    UNION
	select
		u.user_id,
		u.email,
		im_name_from_user_id(u.user_id) as name
	from
		im_forum_topics t,
		acs_rels r,
		cc_users u
	where
		t.topic_id = :topic_id and
		r.object_id_one = t.object_id and
		r.object_id_two = u.user_id
    UNION
	select
		u.user_id,
		u.email,
		im_name_from_user_id(u.user_id) as name
	from
		im_forum_topics t,
		cc_users u
	where
		t.topic_id = :topic_id and
		t.owner_id = u.user_id
"

set num_stakeholders 0
db_multirow -extend {checked} stakeholders stakeholder_query $stakeholder_sql {

    set checked ""
    if {$user_id == $asignee_id} { set checked "checked" }
    if {$user_id == $owner_id} { set checked "checked" }
    incr num_stakeholders
}

# Owner is alway selected as a "stakeholder", so we don't 
# have the case of no stakeholder anymore_:
# if {0 == $num_stakeholders} {
#    ad_returnredirect $return_url
# }
