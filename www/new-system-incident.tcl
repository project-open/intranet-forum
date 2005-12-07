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

set system_owner_email [ad_parameter -package_id [ad_acs_kernel_id] SystemOwner]
set system_owner_id [db_string user_id "select party_id from parties where lower(email) = lower(:system_owner_email)" -default 0]

# -----------------------------------------------------------------
# Get more debug information
# -----------------------------------------------------------------

set more_info ""

# Extract variables from form and HTTP header
set form_vars [ns_conn form]
set header_vars [ns_conn headers]
set url [ns_conn url]

# Convert the form vars into a list

append more_info "Form Vars:\n"
if {"" != $form_vars} {
    foreach var [ad_ns_set_keys $form_vars] {
	set value [ns_set get $form_vars $var]
	ns_log Notice "new-system-incident: $var=$value"
	append more_info "$var: $value\n"
    }
}

# UserId probably 0, except for returning users
set user_id [ad_get_user_id]

set client_ip [ns_set get $header_vars "Client-ip"]
set referer_url [ns_set get $header_vars "Referer"]
set peer_ip [ns_conn peeraddr]

set ip $peer_ip
if {"" != $client_ip} { set ip $client_ip }

# Extract cookies
set cookie_string [ns_set get $header_vars "Cookie"]
set cookies [split $cookie_string ";"]
set cookie_vars [ns_set create]
foreach cookie $cookies {
    set cookie [string trim $cookie]
    set cookie_parts [split $cookie "="]
    set cookie_name [lindex $cookie_parts 0]
    set cookie_value [ns_urldecode [lindex $cookie_parts 1]]
        ns_set put $cookie_vars $cookie_name $cookie_value
}

ns_log Notice "var:     url     =       $url\n"
ns_log Notice "var:     user_id =       $user_id\n"
ns_log Notice "var:     client_ip       =       $client_ip\n"
ns_log Notice "var:     peer_ip =       $peer_ip\n"
ns_log Notice "var:     ip      =       $ip\n"


append more_info "Header Vars:\n"
foreach var [ad_ns_set_keys $header_vars] {
    set value [ns_set get $header_vars $var]
    append more_info ns_log Notice "$var: $value\n"
}

#foreach var [ad_ns_set_keys $cookie_vars] {
#    set value [ns_set get $cookie_vars $var]
#    ns_log Notice "cookie:      $var    =       $value\n"
#}

# Are we behind a firewall or behind a reverse proxy?
# set x_forwarded_for [ns_set get $header_vars "X-Forwarded-For"]
# if {"" != $x_forwarded_for} {
#         set ip $x_forwarded_for
# }



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
# Create an incident (without mail alert)
# -----------------------------------------------------------------

set topic_id [db_nextval "im_forum_topics_seq"]
set parent_id ""
set owner_id $error_user_id
set scope "group"
set subject $error_url
set message "
Error URL: $error_url
Error Location: $error_location
System URL: $system_url
User Name: $error_first_names $error_last_name
User Email: $error_user_email
Publisher Name: $publisher_name
Package Version(s): $core_version
Package Versions: $package_versions
Error Info: 
$error_info"


# Limit Subject and message to their field sizes
set subject [string_truncate -len 200 $error_url]
set message [string_truncate -len 4000 $message]
set error_url_50 [string_truncate -len 40 $error_url]


set priority 3
set due [db_string tomorrow "select to_date(to_char(now(), 'J'), 'J') + 1 from dual"]


set asignee_id $system_owner_id

# 1102 is "Incident"
set topic_type_id 1102

# 1202 is "Open"
set topic_status_id 1202


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


