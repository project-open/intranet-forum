# /packages/intranet-forum/www/intranet/forum/index.tcl
#
# Copyright (C) 2003 - 2009 ]project-open[
#
# All rights reserved. Please check
# http://www.project-open.com/license/ for details.

# ---------------------------------------------------------------
# Page Contract
# ---------------------------------------------------------------

ad_page_contract { 
    List all projects with dimensional sliders.

    @param order_by project display order 
    @param include_subprojects_p whether to include sub projects
    @param mine_p show my projects or all projects
    @param status_id criteria for project status
    @param type_id criteria for project_type_id
    @param letter criteria for im_first_letter_default_to_a(ug.group_name)
    @param start_idx the starting index for query
    @param how_many how many rows to return

    @author frank.bergmann@project-open.com
} {
    { forum_object_id 0 }
    { forum_order_by "Project" }
    { forum_view_name "forum_list_forum" }
    { forum_mine_p "t" }
    { forum_topic_type_id:integer 0 }
    { forum_status_id 0 }
    { forum_group_id:integer 0 }
    { forum_start_idx:integer 0 }
    { forum_how_many 0 }
    { forum_folder 0 }
    { forum_max_entries_per_page 0 }
    { forum_start_date "" }
    { forum_end_date "" }
}

# ---------------------------------------------------------------
# Defaults & Security
# ---------------------------------------------------------------

# User id already verified by filters
set user_id [ad_maybe_redirect_for_registration]
set current_user_id $user_id
set view_types [list "t" [lang::message::lookup "" intranet-core.Object_Mine "Mine"] "f" [lang::message::lookup "" intranet-core.Object_All "All"]]
set page_title "[_ intranet-forum.Forum]"
set context_bar [im_context_bar $page_title]
set page_focus "im_header_form.keywords"
set user_admin_p [im_is_user_site_wide_or_intranet_admin $current_user_id]

set return_url [im_url_with_query]
set current_url [ns_conn url]

if { [empty_string_p $forum_how_many] || $forum_how_many < 1 } {
    set forum_how_many [ad_parameter -package_id [im_package_core_id] NumberResultsPerPage "" 50]
} 

set end_idx [expr $forum_start_idx + $forum_how_many - 1]

if {[string equal $forum_view_name "forum_list_tasks"]} {
    set forum_view_name "forum_list_forum"
    # Preselect "Tasks & Incidents"
    set forum_topic_type_id 1
}


# ---------------------------------------------------------------
# Check dates
# ---------------------------------------------------------------

# Check that Start & End-Date have correct format
if {"" != $forum_start_date && ![regexp {[0-9][0-9][0-9][0-9]\-[0-9][0-9]\-[0-9][0-9]} $forum_start_date]} {
    ad_return_complaint 1 "Start Date doesn't have the right format.<br>
    Current value: '$forum_start_date'<br>
    Expected format: 'YYYY-MM-DD'"
}

if {"" != $forum_end_date && ![regexp {[0-9][0-9][0-9][0-9]\-[0-9][0-9]\-[0-9][0-9]} $forum_end_date]} {
    ad_return_complaint 1 "End Date doesn't have the right format.<br>
    Current value: '$forum_end_date'<br>
    Expected format: 'YYYY-MM-DD'"
}


if {"" == $forum_start_date} { set forum_start_date [parameter::get_from_package_key -package_key "intranet-cost" -parameter DefaultStartDate -default "2000-01-01"] }
if {"" == $forum_end_date} { set forum_end_date [parameter::get_from_package_key -package_key "intranet-cost" -parameter DefaultEndDate -default "2100-01-01"] }






# ---------------------------------------------------------------
# Define Filter Categories
# ---------------------------------------------------------------

# Forum Topic Types come from a category list, but we need
# some manual extensions...
#
set forum_topic_types [im_memoize_list select_forum_topic_types \
			   "select * from im_forum_topic_types order by topic_type_id"]
set forum_topic_types [linsert $forum_topic_types 0 1 "Tasks / Incidents]"]
set forum_topic_types [linsert $forum_topic_types 0 0 "All"]
ns_log Notice "/intranet-forum/index: forum_topic_types=$forum_topic_types"

# project_types will be a list of pairs of (project_type_id, project_type)
set project_types [im_memoize_list select_project_types \
        "select project_type_id, project_type
         from im_project_types
        order by lower(project_type)"]
set project_types [linsert $project_types 0 0 All]

# ---------------------------------------------------------------
# Format the Filter
# ---------------------------------------------------------------

set filter_html "
	<table border=0 cellpadding=0 cellspacing=1>
"

if {[im_permission $current_user_id "view_topics_all"]} {
    append filter_html "
	<tr>
	  <td class=form-label>[lang::message::lookup "" intranet-core.Filter_View "View"]:</td>
	  <td class=form-widget>[im_select forum_mine_p $view_types $forum_mine_p]</td>
	</tr>
    "
} else {
    append filter_html "<input type=hidden name=forum_mine_p value='t'>\n"
}

append filter_html "
	<tr>
	  <td class=form-label>[_ intranet-forum.Topic_Type]:</td>
	  <td class=form-widget>
	    [im_select forum_topic_type_id $forum_topic_types $forum_topic_type_id] 
	  </td>
	</tr>
	<tr>
	  <td class=form-label>[lang::message::lookup "" intranet-core.Start_Date "Start Date"]</td>
	  <td class=form-widget><input type=text size=10 maxsize=10 name=forum_start_date value=\"$forum_start_date\"></td>
	</tr>
	<tr>
	  <td class=form-label>[lang::message::lookup "" intranet-core.End_Date "End Date"]</td>
	  <td class=form-widget><input type=text size=10 maxsize=10 name=forum_end_date value=\"$forum_end_date\"></td>
	</tr>
	<tr>
	  <td class=form-label>&nbsp;</td>
	  <td class=form-widget>
	    <input type=submit value='[lang::message::lookup "" intranet-core.Action_Go "Go"]' name=submit>
	  </td>
	</tr>
        </table>
"

# ---------------------------------------------------------------
# Prepare parameters for the Forum Component
# ---------------------------------------------------------------

# Variables of this page to pass through im_forum_component to maintain the
# current selection and view of the current project

set export_var_list [list forum_group_id forum_start_idx forum_order_by forum_how_many forum_view_name forum_mine_p]

set restrict_to_asignee_id 0
set restrict_to_new_topics 0

set forum_content [im_forum_component \
	-user_id		$user_id \
	-forum_object_id	$forum_object_id \
	-forum_type		"forum" \
	-current_page_url	$current_url \
	-return_url		$return_url \
	-start_idx		$forum_start_idx \
	-export_var_list	$export_var_list \
	-view_name 		[im_opt_val forum_view_name] \
	-forum_order_by		[im_opt_val forum_order_by] \
	-restrict_to_mine_p	$forum_mine_p \
	-restrict_to_folder	$forum_folder \
	-restrict_to_new_topics 0 \
	-max_entries_per_page	$forum_max_entries_per_page \
	-restrict_to_topic_type_id $forum_topic_type_id \
	-forum_start_date	$forum_start_date \
	-forum_end_date		$forum_end_date \
]

# ---------------------------------------------------------------
# Join all parts together
# ---------------------------------------------------------------

set sub_navbar [im_forum_navbar "/intranet-forum/index" [list forum_group_id forum_start_idx forum_order_byforum_how_many forum_mine_p forum_view_name] $forum_folder]

# ---------------------------------------------------------------
# Build the Left Navbar
# ---------------------------------------------------------------

set left_navbar_html "
    <div class='filter-block'>
      <div class='filter-title'>
        [lang::message::lookup "" intranet-forum.Filter_Topics "Filter Topics"]
      </div>
      <form method=get action='index'>
        [export_form_vars forum_group_id forum_start_idx forum_order_by forum_how_many forum_view_name]
        $filter_html
      </form>
    </div>
"


ad_return_template