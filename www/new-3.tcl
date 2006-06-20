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
    @author juanjoruizx@yahoo.es
} {
    topic_id:integer
    return_url
    object_type
    subject:html
    msg_url
    message:html
    notifyee_id:multiple
}

# ------------------------------------------------------------------
# Security, Parameters & Default
# ------------------------------------------------------------------

set user_id [ad_maybe_redirect_for_registration]

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
	m.topic_id=:topic_id
"

db_foreach update_stakeholders $stakeholder_sql {

    if {[lindex $notifyee_id $user_id] > 0} {

	ns_log Notice "intranet-forum/new-2: Sending out alert: '$subject'"
	im_send_alert $stakeholder_id "hourly" $subject "$msg_url\n\n$message"

    }
}

db_release_unused_handles 
ad_returnredirect $return_url

