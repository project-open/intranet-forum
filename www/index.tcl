# /packages/intranet-forum/www/intranet/forum/index.tcl
#
# Copyright (C) 2003-2004 Project/Open
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
    { forum_mine_p "f" }
    { forum_topic_type_id:integer 0 }
    { forum_status_id 0 }
    { forum_group_id:integer 0 }
    { forum_start_idx:integer "1" }
    { forum_how_many 0 }
    { forum_folder 0 }
    { forum_max_entries_per_page 0 }
}

# ---------------------------------------------------------------
# Defaults & Security
# ---------------------------------------------------------------

# User id already verified by filters
set user_id [ad_maybe_redirect_for_registration]
set current_user_id $user_id
set view_types [list "t" "Mine" "f" "All"]
set page_title "Forum"
set context_bar [ad_context_bar $page_title]
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
# Define Filter Categories
# ---------------------------------------------------------------

# Forum Topic Types come from a category list, but we need
# some manual extensions...
#
set forum_topic_types [im_memoize_list select_forum_topic_types \
			   "select * from im_forum_topic_types order by topic_type_id"]
set forum_topic_types [linsert $forum_topic_types 0 1 "Tasks & Incidents"]
set forum_topic_types [linsert $forum_topic_types 0 0 All]
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

# Note that we use a nested table because im_slider might
# return a table with a form in it (if there are too many
# options
set filter_html "
<table border=0 cellpadding=0 cellspacing=0>
<tr>
  <td colspan='2' class=rowtitle align=center>Filter Topics</td>
</tr>\n"

if {[im_permission $current_user_id "view_forum_topics_all"]} {
    append filter_html "
<tr>
  <td valign=top>View:</td>
  <td valign=top>[im_select forum_mine_p $view_types ""]</td>
</tr>"
}
if {[im_permission $current_user_id "view_forum_topics_all"]} {
    append filter_html "
<!--
<tr>
  <td valign=top>Project Status:</td>
  <td valign=top>[im_select status_id $forum_topic_types ""]</td>
</tr>
-->
"
}

append filter_html "
<tr>
  <td valign=top>Topic Type:</td>
  <td valign=top>
    [im_select forum_topic_type_id $forum_topic_types $forum_topic_type_id]
          <input type=submit value=Go name=submit>
  </td>
</tr>\n"

append filter_html "</table>"


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
	-object_id		$forum_object_id \
	-forum_type		home \
	-current_page_url	$current_url \
	-return_url		$return_url \
	-export_var_list	[list forum_start_idx forum_order_by forum_how_many forum_view_name] \
	-view_name 		[im_opt_val forum_view_name] \
	-forum_order_by		[im_opt_val forum_order_by] \
	-restrict_to_mine_p	$forum_mine_p \
	-restrict_to_folder	$forum_folder \
	-restrict_to_new_topics 0 \
	-max_entries_per_page	$forum_max_entries_per_page \
]

# ---------------------------------------------------------------
# Join all parts together
# ---------------------------------------------------------------

set page_body "
  <form method=get action='index'>
  [export_form_vars forum_group_id forum_start_idx forum_order_by forum_how_many forum_view_name]
    $filter_html
  </form>

[im_forum_navbar "/intranet-forum/index" [list forum_group_id forum_start_idx forum_order_byforum_how_many forum_mine_p forum_view_name] $forum_folder]

$forum_content

"

db_release_unused_handles


doc_return  200 text/html [im_return_template]
