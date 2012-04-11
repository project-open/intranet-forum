# /packages/intranet-forum/www/intranet-forum/forum/new-3.tcl
#
# Copyright (C) 2003 - 2009 ]project-open[
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

# Determine the sender address

set sender_email [ad_parameter -package_id [ad_acs_kernel_id] SystemOwner "" [ad_system_owner]]
if { "CurrentUser" == [parameter::get -package_id [apm_package_id_from_key intranet-forum] -parameter "SenderMail" -default "CurrentUser"] } {
    set sender_email [db_string sender_email "select email as sender_email from parties where party_id = :user_id" -default $sender_email]
} 

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
set stakeholder_sql2 "
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

set stakeholder_sql "
	select distinct
		user_id as stakeholder_id,
		email as stakeholder_email
	from	($stakeholder_sql2) t
"

db_foreach update_stakeholders $stakeholder_sql {

    set url "/intranet-forum/view?topic_id=$topic_id"
    set auto_login [im_generate_auto_login -user_id $stakeholder_id]
    set msg_url [export_vars -base "/intranet/auto-login" {{user_id $stakeholder_id} {url $url} {auto_login $auto_login}}]
    set msg_url "[ad_parameter -package_id [ad_acs_kernel_id] SystemURL "" ""]$msg_url"

    ns_log Notice "forum/new-3: stakeholder_id=$stakeholder_id"
    if {[lsearch $notifyee_id $stakeholder_id] > -1} {

	set subject [string trim $subject]
	if {[catch {
	    acs_mail_lite::send \
		-send_immediately \
		-to_addr $stakeholder_email \
		-from_addr $sender_email \
		-subject $subject \
		-body "$msg_url\n\n$message"
	} errmsg]} {
	    ad_return_error $subject "<p>Error sending out mail:</p><div><code>[ad_quotehtml $errmsg]</code></div>"
	    ad_script_abort
	}
    }
}

db_release_unused_handles 
ad_returnredirect $return_url

