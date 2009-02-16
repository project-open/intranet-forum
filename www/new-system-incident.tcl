# /packages/intranet-forum/www/intranet/forum/new-system-error.tcl
#
# Copyright (C) 2003 - 2009 ]project-open[
#
# All rights reserved. Please check
# http://www.project-open.com/license/ for details.

ad_page_contract {
    Creates a new system error from a "Report this error" button.
    Works as an inteface between the request procesor generating
    the incident and the forum module that works differntly then
    the old ACS ticket tracker.

    So there are several difficulties:
    - This page is publicly accessible, so it may be used for
      denial of service attacks by flooding the system with
      incidents
    - We have to route the incidents to 

    @author frank.bergmann@project-open.com
} {
    { error_url:trim ""}
    { error_location:trim ""}
    { error_info:trim,html ""}
    { error_first_names:trim ""}
    { error_last_name:trim ""}
    { error_user_email:trim ""}
    { core_version:trim ""}
    { package_versions:trim ""}
    { system_url:trim ""}
    { publisher_name ""}
}

set current_user_id [ad_get_user_id]

ns_log Notice "new-system-incident: error_url=$error_url"
ns_log Notice "new-system-incident: error_info=$error_info"
ns_log Notice "new-system-incident: error_first_names=$error_first_names"
ns_log Notice "new-system-incident: error_last_name=$error_last_name"
ns_log Notice "new-system-incident: error_user_email=$error_user_email"
ns_log Notice "new-system-incident: core_version=$core_version"
ns_log Notice "new-system-incident: package_versions=$package_versions"

# Maximum number of incidents per day per IP address
# Designed to avoid denial or service attacks
set max_dayily_incidents 3

set return_url "/intranet/"
set authority_id ""
set username ""

set title "New System Incident"

set system_owner_email [ad_parameter -package_id [im_package_forum_id] ReportThisErrorEmail]
set system_owner_id [db_string user_id "select min(user_id) from users where user_id > 0"]

# -----------------------------------------------------------------
# Get more debug information
# -----------------------------------------------------------------

set more_info "Generic Vars:\n"

# Extract variables from form and HTTP header
set header_vars [ns_conn headers]
set url [ns_conn url]

# UserId probably 0, except for returning users
set user_id [ad_get_user_id]
append more_info "user_id: $user_id\n"


set client_ip [ns_set get $header_vars "Client-ip"]
set referer_url [ns_set get $header_vars "Referer"]
set peer_ip [ns_conn peeraddr]
append more_info "client_ip: $client_ip\n"
append more_info "referer_url: $referer_url\n"
append more_info "peer_ip: $peer_ip\n"


append more_info "\nHeader Vars:\n"
foreach var [ad_ns_set_keys $header_vars] {
    set value [ns_set get $header_vars $var]
    append more_info "$var: $value\n"
}


# -----------------------------------------------------------------
# Lookup user_id or create entry
# -----------------------------------------------------------------
# Keep in mind that the email and other data might be completely fake.

ns_log Notice "Check if the user already has an account: $error_user_email"
set error_user_id [db_string user_id "select party_id from parties where lower(email) = lower(:error_user_email)" -default 0]

if {0 != $error_user_id} {
    # The user already exists:
    # Make sure there are no more then $max_incidents today from the same IP
    
    # ToDo: Implement !!!

} else {

    # Doesn't exist yet - let's create it
    ns_log Notice "new-system-incident: creating new user '$error_user_email'"
    array set creation_info [auth::create_user \
	-email $error_user_email \
	-url $system_url \
	-verify_password_confirm \
	-first_names $error_first_names \
	-last_name $error_last_name \
	-screen_name "$error_first_names $error_last_name" \
	-username "$error_first_names $error_last_name" \
	-password $error_first_names \
	-password_confirm $error_first_names \
    ]

    ns_log Notice "new-system-incident: creation info: [array get creation_info]"
    ns_log Notice "new-system-incident: checking for '$error_user_email' after creation"
    set error_user_id [db_string user_id "select party_id from parties where lower(email) = lower(:error_user_email)" -default 0]

}

# Make the user member of group "Customers"
set rel_id [relation_add -member_state "approved" "membership_rel" [im_profile_customers] $error_user_id]
db_dml update_relation "update membership_rels set member_state='approved' where rel_id = :rel_id"


# Default if there was an error creating a new user
if {!$error_user_id} {
    # create user didn't succeed...
    set error_user_id $system_owner_id
}

# -----------------------------------------------------------------
# Determine the error user's company and SLA. Otherwise use "internal"
# -----------------------------------------------------------------

set error_company_id [im_company_internal]
set error_company_ids [db_list comps "
	select	c.company_id
	from	im_companies c,
		acs_rels r
	where	r.object_id_one = :error_user_id and
		r.object_id_two = c.company_id
	order by
		c.company_id
"]
if {[llength $error_company_ids] > 0} { set error_company_id [lindex $error_company_ids 0] }


# -----------------------------------------------------------------
# Find out the report_object
# -----------------------------------------------------------------

set report_object_id 0

# Try with a company first
set report_object_id [db_string report_company "
select	min(company_id)
from	im_companies c,
	acs_rels r
where	c.company_id = r.object_id_one
	and r.object_id_two = :error_user_id
" -default 0]

# Set the report_object to the user itself
if {"" == $report_object_id || !$report_object_id} {
    set report_object_id $error_user_id
}

# -----------------------------------------------------------------
# Find out the title line for the error
# -----------------------------------------------------------------

set error_url [string range $error_url 0 50]
set subject ""

if {[regexp {ERROR\:([^\n]*)} $error_info match error_descr]} {
    set subject "$error_url: $error_descr"
}

if {"" == $subject && [regexp {([^\n]*)} $error_info match error_descr]} {
    set subject "$error_url: $error_descr"
}

# Default - didn't find any reasonable piece of error code
if {"" == $subject} { set subject $error_url }



# -----------------------------------------------------------------
# Determine and/or create the ConfItem 
# -----------------------------------------------------------------

# Identify the package with the error. intranet-core is only exception 
set error_url_parts [split $error_url "/"]
set error_package [lindex $error_url_parts 1]
if {$error_package == "intranet"} { set error_package "intranet-core" }

# Parse the package string and store into hash
set package_list [split $package_versions " "]
foreach package_str $package_list {
    regexp {([a-z0-9\-]*)\:([0-9\.]*)} $package_str match package version
    set pver_hash($package) $version
}

# Get toplevel ConfItem for ]po[ internal development
set po_conf_id [db_string cvs "select conf_item_id from im_conf_items where conf_item_nr = 'po'" -default 0]
if {0 == $po_conf_id} { ad_return_complaint 1 "Didn't find ConfItem 'po'.<br>Please inform support@project-open.com." }

# Get ConfItem of package below 'po'
set package_conf_id [db_string cvs "select conf_item_id from im_conf_items where conf_item_nr = :error_package and conf_item_parent_id = :po_conf_id" -default 0]
if {0 == $package_conf_id} { 
    # No package yet for this $error_packag - create

    set conf_item_name $error_package
    set conf_item_nr $error_package
    set conf_item_parent_id $po_conf_id
    set conf_item_type_id [im_conf_item_type_po_package]
    set conf_item_status_id [im_conf_item_status_active]

    set conf_item_new_sql "
		select im_conf_item__new(
			null,
			'im_conf_item',
			now(),
			:system_owner_id,
			'[ad_conn peeraddr]',
			null,
			:conf_item_name,
			:conf_item_nr,
			:conf_item_parent_id,
			:conf_item_type_id,
			:conf_item_status_id
		)
    "
    set package_conf_id [db_string new $conf_item_new_sql]
    db_dml update [im_conf_item_update_sql -include_dynfields_p 1]
}

# -----------------------------------------------------------------
# Create a Helpdesk Ticket
# -----------------------------------------------------------------

set ticket_id [db_nextval "acs_object_id_seq"]
set ticket_name "$error_url - $ticket_id"
set ticket_customer_id $error_company_id
set ticket_customer_contact_id $error_user_id
set ticket_type_id [im_ticket_type_bug_request]
set ticket_status_id [im_ticket_status_open]
set ticket_nr [db_nextval im_ticket_seq]
set start_date [db_string now "select now()::date from dual"]
set end_date [db_string now "select (now()::date) from dual"]
set start_date_sql [template::util::date get_property sql_date $start_date]
set end_date_sql [template::util::date get_property sql_timestamp $end_date]
set ticket_sla_id [im_ticket::internal_sla_id]
set ticket_conf_item_id $package_conf_id

set open_nagios_ticket_id [db_string ticket_insert {}]
db_dml ticket_update {}
db_dml project_update {}

# Write Audit Trail
im_project_audit $ticket_id
    
# Add the ticket message to the forum tracker of the open ticket.
set forum_ids [db_list forum_ids "
	select	ft.topic_id
	from	im_forum_topics ft
	where	ft.object_id = :open_nagios_ticket_id
	order by ft.topic_id
"]

# Get the first forum topic associated with the ticket and use as parent
set parent_id [lindex $forum_ids 0]

# Create a new forum topic of type "Note"
set topic_id [db_nextval im_forum_topics_seq]
set topic_type_id [im_topic_type_id_task]
set topic_status_id [im_topic_status_id_open]
set subject $error_url

set message "
Error URL: $error_url
Error Location: $error_location
System URL: $system_url
User Name: $error_first_names $error_last_name
User Email: $error_user_email
Publisher Name: $publisher_name

$more_info

Package Version(s): $core_version
Package Versions: $package_versions
Error Info:
$error_info
"
set message [string range $message 0 3998]

db_dml topic_insert {
		insert into im_forum_topics (
			topic_id, object_id, parent_id,
			topic_type_id, topic_status_id, owner_id, 
			subject, message
		) values (
			:topic_id, :open_nagios_ticket_id, :parent_id,
			:topic_type_id,	:topic_status_id, :error_user_id, 
			:subject, :message
		)
}

# -----------------------------------------------------------------
# 
# -----------------------------------------------------------------

set resolved_p 0



