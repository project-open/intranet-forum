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
    { error_info:trim,allhtml ""}
    { error_first_names:trim ""}
    { error_last_name:trim ""}
    { error_user_email:trim ""}
    { error_type:trim "standard"}
    { error_content:trim ""}
    { error_content_filename:trim ""}
    { core_version:trim ""}
    { package_versions:trim ""}
    { system_url:trim ""}
    { system_id:trim ""}
    { hardware_id:trim "" }
    { publisher_name ""}
}

# -----------------------------------------------------------------
# Defaults & Security
# -----------------------------------------------------------------

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
# Keep in mind that the email and other data might be completely fake.
# -----------------------------------------------------------------

ns_log Notice "Check if the user already has an account: $error_user_email"
set error_user_id [db_string user_id "select party_id from parties where lower(email) = lower(:error_user_email)" -default 0]

if {0 != $error_user_id} {
    # The user already exists:
    # Make sure there are no more then $max_incidents today from the same IP
    
    # ToDo: Implement

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
# Determine the error user's company and SLA. 
# Otherwise use "internal"
# -----------------------------------------------------------------

set default_company_id [im_company_internal]
set error_company_id [db_string error_company "
	select	min(c.company_id)
	from	im_companies c,
		acs_rels r
	where	r.object_id_one = :error_user_id and
		r.object_id_two = c.company_id
" -default $default_company_id]
if {"" == $error_company_id} { set error_company_id $default_company_id }


# -----------------------------------------------------------------
# Find out the title line for the error
# -----------------------------------------------------------------

# Limit the shortened version of the url to 100 chars
# and put a space before every "&" to allow the line to break
set error_url_shortened [string range $error_url 0 100]
regsub -all {&} $error_url_shortened { &} error_url_shortened

# Determine the subject line. Do an effort to make it pretty.
set subject ""
if {[regexp {ERROR\:([^\n]*)} $error_info match error_descr]} {
    set subject "$error_url_shortened: $error_descr"
}

if {"" == $subject && [regexp {([^\n]*)} $error_info match error_descr]} {
    set subject "$error_url_shortened: $error_descr"
}

# Default - didn't find any reasonable piece of error code
if {"" == $subject} { set subject $error_url }



# -----------------------------------------------------------------
# Determine and/or Create a Package ConfItem
# -----------------------------------------------------------------

# Identify the package with the error. intranet-core is only exception 
set error_url_parts [split $error_url "/"]
set error_package [lindex $error_url_parts 1]

# The one and only exception: intranet-core is mounted on /intranet/:
if {$error_package == "intranet"} { set error_package "intranet-core" }

# Check for strange names and set to "core"
if {![regexp {^[a-z0-9\-]+$} $error_package match]} { set error_package "intranet-core" }

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
set package_conf_item_id [db_string cvs "
	select	min(conf_item_id)
	from	im_conf_items
	where	conf_item_nr = :error_package and conf_item_parent_id = :po_conf_id
" -default 0]

if {0 == $package_conf_item_id} { 
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

    if {[catch { set package_conf_item_id [db_string new $conf_item_new_sql] } errmsg ]} {
	ad_return_complaint 1 "Unable to handle your submission, pls. contact support@project-open.com"
    }

    if {[catch { db_dml update [im_conf_item_update_sql -include_dynfields_p 1] } errmsg ]} {
	ad_return_complaint 1 "Unable to handle your submission, pls. contact support@project-open.com"
    }
}



# -----------------------------------------------------------------
# Determine and/or Create Server ConfItem
# -----------------------------------------------------------------



# Get ConfItem for SystemID
set system_conf_item_id [db_string system "
	select	min(conf_item_id)
	from	im_conf_items
	where	conf_item_nr = :system_id
" -default ""]

if {"" == $system_conf_item_id} {

    im_software_update_server_update_conf_item \
	-sid $system_id \
	-hid $hardware_id \
	-email $error_user_email \
	-peer_ip [ad_conn peeraddr] \
	-server_ip $system_url \
	-package_list [array get pver_hash]

    set system_conf_item_id [db_string system "
	select	conf_item_id
	from	im_conf_items
	where	conf_item_nr = :system_id
    " -default ""]
}


# -----------------------------------------------------------------
# Create a category for po_product_version if necessary
# -----------------------------------------------------------------

# Fix "core_version" (if not part of the data sent)
if {"" == $core_version} {
    regexp {intranet-core:([0-9\.]*)} $package_versions match core_version
}

set pretty_version "V$core_version"
set version_category_id [db_string cat "select category_id from im_categories where category = :pretty_version and category_type = 'PO Product Version'" -default ""]

# Check if we need to create a new category
if {"" == $version_category_id || 0 == $version_category_id} {
	
    set cat_id [db_string cat_id "select nextval('im_categories_seq')"]
    set cat_id_low_p [db_string cat_id_low "select count(*) from im_categories where category_id >= :cat_id"]
    while {$cat_id_low_p} {
	set cat_id [db_string cat_id "select nextval('im_categories_seq')"]
	set cat_id_low_p [db_string cat_id_low "select count(*) from im_categories where category_id >= :cat_id"]
    }
    
    db_string new_cat "SELECT im_category_new(:cat_id, :pretty_version, 'PO Product Version')"
    set version_category_id [db_string cat "select category_id from im_categories where category = :pretty_version and category_type = 'PO Product Version'" -default ""]
}


# -----------------------------------------------------------------
# Create a Helpdesk Ticket
# -----------------------------------------------------------------

set ticket_id [db_nextval "acs_object_id_seq"]
set ticket_name "$error_url_shortened - $ticket_id"
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
set ticket_conf_item_id $package_conf_item_id

set ticket_id [db_string ticket_insert {}]

db_dml ticket_update {}
db_dml project_update {}

# Update the core_version. The field may not exist in the im_tickets table...
if {[db_column_exists im_tickets ticket_po_version]} {
    db_dml ver "update im_tickets set ticket_po_version = :core_version where ticket_id = :ticket_id"
}


# -----------------------------------------------------------------
# Associate ticket with a Server configuration item

# Update the system_id
set conf_item_id [db_string conf_item "select min(conf_item_id) from im_conf_items where conf_item_nr = :system_id" -default ""]
if {"" != $conf_item_id} {
    db_dml cid "
	update im_tickets set
		ticket_conf_item_id = :ticket_conf_item_id,
		ticket_po_package_id = :package_conf_item_id,
		po_product_version_id = :version_category_id
	where ticket_id = :ticket_id
    "
}

# Create an acs_rel relationship
if {"" != $system_conf_item_id && 0 != $system_conf_item_id} {
    im_conf_item_new_project_rel \
	-project_id $ticket_id \
	-conf_item_id $system_conf_item_id
}

# Make the error_user a "member" of the ticket
im_biz_object_add_role $error_user_id $ticket_id [im_biz_object_role_full_member]


# -----------------------------------------------------------------
# Write Audit Trail
im_project_audit -project_id $ticket_id

# Add the ticket message to the forum tracker of the open ticket.
set forum_ids [db_list forum_ids "
	select	ft.topic_id
	from	im_forum_topics ft
	where	ft.object_id = :ticket_id
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
System ID: $system_id
User Name: $error_first_names $error_last_name
User Email: $error_user_email
Publisher Name: $publisher_name

$more_info

Package Version(s): $core_version
Package Versions: $package_versions
Error Info:
$error_info
"
set message [string range $message 0 9998]

if {[catch { 
    db_dml topic_insert {
                insert into im_forum_topics (
                        topic_id, object_id, parent_id,
                        topic_type_id, topic_status_id, owner_id,
                        subject, message
                ) values (
                        :topic_id, :ticket_id, :parent_id,
                        :topic_type_id, :topic_status_id, :error_user_id,
                        :subject, :message
                )
    }
} errmsg ]} {
        ad_return_complaint 1 "Unable to handle submission, please contact support@project-open.com"
}

set resolved_p 0

# -----------------------------------------------------------------
# Save an error_content file if necessary
# -----------------------------------------------------------------

if {"" != $error_content} {
    # Check the filename and prepare to be stored in ticket filestorage
    set folder_type "im_ticket"
    regsub -all {[^a-zA-Z0-9]} $error_content_filename "_" error_content_filename
    set base_path [im_filestorage_base_path $folder_type $ticket_id]
    set dest_path "$base_path/$error_content_filename"
}

# Position at the end, this way we can refer to all actions happend in callback 
callback im_ticket_after_create -object_id $ticket_id