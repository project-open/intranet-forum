# /packages/intranet-forum/www/intranet/forum/new-system-error.tcl
#
# Copyright (C) 2003-2004 Project/Open
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
set system_owner_id [db_string user_id "select party_id from parties where lower(email) = lower(:system_owner_email)" -default 0]

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

if {!$error_user_id} {
    # create user didn't succeed...
    set error_user_id $system_owner_id
}

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
# Create an incident (without mail alert)
# -----------------------------------------------------------------

set topic_id [db_nextval "im_forum_topics_seq"]
set parent_id ""
set owner_id $error_user_id
set scope "group"
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
$error_info"


# Limit Subject and message to their field sizes
#set message [string range $message 0 400]
set error_url_50 [string range $error_url 0 50]


set priority 3
set due [db_string tomorrow "select to_date(to_char(now(), 'J'), 'J') + 1 from dual"]


set asignee_id $system_owner_id

# 1102 is "Incident"
set topic_type_id 1102

# 1202 is "Open"
set topic_status_id 1202

set ttt {

db_transaction {
        db_dml topic_insert "
INSERT INTO im_forum_topics (
        topic_id, object_id, parent_id, topic_type_id, topic_status_id,
        posting_date, owner_id, scope, subject, message, priority,
        asignee_id, due_date
) VALUES (
        :topic_id, :report_object_id, :parent_id, :topic_type_id, :topic_status_id,
        now(), :owner_id, :scope, :subject, :message, :priority,
        :asignee_id, :due
)"
} on_error {
    ad_return_error "Error adding a new topic" "
    <LI>There was an error adding your ticket to our system.<br>
    Please send an email to <A href=\"mailto:[ad_parameter "SystemOwner" "" ""]\">
    our webmaster</a>, thanks."
}

}


# -----------------------------------------------------------------
# Create a Bug-Tracker entry
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

# extract the version of the package in question
set error_package_version ""
catch { set error_package_version "V$pver_hash($error_package)" } err
if {"" == $error_package_version} { ad_return_complaint 1 "Internal Error:<br>Didn't find version for '$error_package'" }

# Get the standard system bug-tracker instance
set bt_package_id [apm_package_id_from_key [bug_tracker::package_key]]

# Create component if not already there...
set component_id [db_string comp_id "
	select	component_id
	from	bt_components 
	where	component_name = :error_package
		and project_id = :bt_package_id 
" -default 0]
if {0 == $component_id} {
    # Create a new "component" for the package
    set component_id [db_nextval "t_acs_object_id_seq"]
    db_dml new_component "
	insert into bt_components (component_id, project_id, component_name)
    	values (:component_id, :bt_package_id, :error_package)
    "

    util_memoize_flush_regexp "bug.*"
} 

# Create the version if it doesn't exist yet
set version_id [db_string version_id "
	select	version_id
	from	bt_versions
	where	project_id = :bt_package_id
		and version_name = :error_package_version
" -default 0]
if {0 == $version_id} {
    # Create a new "version" for the package
    set version_id [db_nextval "t_acs_object_id_seq"]
    db_dml insert_version "
	insert into bt_versions (
		version_id,
		project_id,
		version_name,
		description
	) values (
		:version_id,
		:bt_package_id,
		:error_package_version,
		:error_package_version
	)
    "
    util_memoize_flush_regexp "bug.*"
}


# Check if the bug was there already
set bug_id [db_string bug_id "
	select	bug_id
	from	bt_bugs
	where	component_id = :component_id
		and found_in_version = :version_id
		and summary = :subject
" -default 0]

if {0 == $bug_id} {

	# Define Bug classifications
	set keyword_ids [list]
	set kid [db_string kid "select keyword_id from cr_keywords where heading = '2 - Broken Function'" -default 0]
	if {0 != $kid} { lappend keyword_ids $kid }
	set kid [db_string kid "select keyword_id from cr_keywords where heading = '2 - Broken Function'" -default 0]
	if {0 != $kid} { lappend keyword_ids $kid }
	set kid [db_string kid "select keyword_id from cr_keywords where heading = '5 - Normal'" -default 0]
	if {0 != $kid} { lappend keyword_ids $kid }
	set kid [db_string kid "select keyword_id from cr_keywords where heading = '3 - Normal'" -default 0]
	if {0 != $kid} { lappend keyword_ids $kid }

	# Create a new bug
	set bug_id [db_nextval "t_acs_object_id_seq"]
	set bug_container_project_id [db_string cont "
		select	min(project_id) 
		from	im_projects 
		where	project_nr like 'bug_tracker%'
	" -default ""]

	bug_tracker::bug::new \
	        -bug_id $bug_id \
	        -package_id $bt_package_id \
	        -component_id $component_id \
	        -found_in_version $version_id \
	        -summary $subject \
	        -description $message \
	        -desc_format "text/plain" \
	        -keyword_ids $keyword_ids \
	        -fix_for_version $version_id \
	        -bug_container_project_id $bug_container_project_id

    set resolved_p 0
    set bug_resolution ""

} else {

    set bug_count [db_string bug_count "select bug_count from bt_bugs where bug_id = :bug_id" -default ""]
    if {"" == $bug_count} { set bug_count 1 }
    db_dml count "
	update bt_bugs set
	bug_count = :bug_count + 1
	where bug_id = :bug_id
    "

    set resolved_p [db_string res "select count(*) from bt_bugs where bug_id = :bug_id and resolution is not null" -default 0]
    set bug_resolution [db_string res "select resolution from bt_bugs where bug_id = :bug_id" -default ""]
}

