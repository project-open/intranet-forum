# /packages/intranet-forum/www/intranet-forum/forum/new-3.tcl
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
    return_url
    object_type
    subject:html
    msg_url
    message:html
    notifyee_id:multiple,optional
}

# ------------------------------------------------------------------
# Security, Parameters & Default
# ------------------------------------------------------------------

set user_id [ad_maybe_redirect_for_registration]
set user_is_employee_p [im_user_is_employee_p $user_id]
set user_is_customer_p [im_user_is_customer_p $user_id]


# Permissions - who should see what
set permission_clause "
        and 1 = im_forum_permission(
                :user_id,
                t.owner_id,
                t.asignee_id,
                t.object_id,
                t.scope,
                member_objects.p,
                admin_objects.p,
                :user_is_employee_p,
                :user_is_customer_p
        )
"

# We only want to remove the permission clause if the
# user is allowed to see all items
if {[im_permission $user_id view_topics_all]} {
            set permission_clause ""
}

set perm_sql "
	select	t.topic_id as allowd_topics
	from
		im_forum_topics t
	        LEFT JOIN
	        (       select 1 as p,
	                        object_id_one as object_id
	                from    acs_rels
	                where   object_id_two = :user_id
	        ) member_objects using (object_id)
	        LEFT JOIN
	        (       select 1 as p,
	                        r.object_id_one as object_id
	                from    acs_rels r,
	                        im_biz_object_members m
	                where   r.object_id_two = :user_id
	                        and r.rel_id = m.rel_id
	                        and m.object_role_id in (1301, 1302, 1303)
	        ) admin_objects using (object_id)
	where
		t.topic_id = :topic_id
		$permission_clause
"

set perm_topics [db_list perms $perm_sql]
if {0 == [llength $perm_topics]} {
    ad_return_complaint 1 "You don't have the right to access this topic"
    ad_script_abort
}



if {![info exists notifyee_id]} { set notifyee_id [list] }

# Get the list of all subscribed users.
# By going through this list (and determining whether the
# given user is "checked") we avoid any security issues,
# because the security is build into the subscription part.
#
# ToDo: A user could abuse this page to send spam messages
# to users in the system. This is not really a security 
# issue, but might be annoying.
# Also, the user needs to be a registered users, so he or
# she could be kicked out easily when misbehaving.
#
set stakeholder_sql "
select
	user_id as stakeholder_id
from
	im_forum_topic_user_map m
where
	m.topic_id = :topic_id
"



ns_log Notice "forum/new-3: notifyee_id=$notifyee_id"

db_foreach update_stakeholders $stakeholder_sql {

    ns_log Notice "forum/new-3: stakeholder_id=$stakeholder_id"
    if {[lsearch $notifyee_id $stakeholder_id] > -1} {

	ns_log Notice "intranet-forum/new-3: Sending out alert: '$subject'"
	im_send_alert $stakeholder_id "hourly" $subject "$msg_url\n\n$message"

    }
}

db_release_unused_handles 
ad_returnredirect $return_url

