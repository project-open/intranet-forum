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
    { object_id:integer 0 }
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

set topics_object_id [db_string topics_oid "select object_id from im_forum_topics where topic_id = :topic_id" -default 0]

if {$object_id != $topics_object_id} {
    # Bad, bad guys: Somebody is trying to tinker with security...
    ad_return_complaint 1 "You have no rights to communicate with members of this object."
    ad_script_abort
}

# expect commands such as: "im_project_permissions" ...
#
set object_view 0
set object_read 0
set object_write 0
set object_admin 0
set object_type [db_string acs_object_type "
	select object_type 
	from acs_objects 
	where object_id = :object_id
" -default ""]

if {"" != $object_type} {
    set perm_cmd "${object_type}_permissions \$user_id \$object_id object_view object_read object_write object_admin"
    eval $perm_cmd
}

if {!$object_read} {
    ad_return_complaint 1 "You have no rights to communicate with members of this object."
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

