# /packages/intranet-forum/tcl/intranet-forum.tcl
#
# Copyright (C) 2003-2004 Project/Open
#
# All rights reserved. Please check
# http://www.project-open.com/license/ for details.

ad_library {
    The intranet forum provides a unified aprearance of 
    Tasks, Incidents, News & Discussions (TIND)

    @author frank.bergmann@project-open.com
}


# ----------------------------------------------------------------------
# Select Boxes
# ----------------------------------------------------------------------

ad_proc -public im_topic_status_id_open { } { return 1200 }
ad_proc -public im_topic_status_id_assigned { } { return 1202 }
ad_proc -public im_topic_status_id_accepted { } { return 1204 }
ad_proc -public im_topic_status_id_rejected { } { return 1206 }
ad_proc -public im_topic_status_id_needs_clarify { } { return 1208 }
ad_proc -public im_topic_status_id_closed { } { return 1210 }

ad_proc -public im_topic_type_id_task { } { return 1102 }
ad_proc -public im_topic_type_id_incident { } { return 1104 }
ad_proc -public im_topic_type_id_reply { } { return 1190 }



ad_proc -public im_package_forum_id {} {
    Returns the package id of the intranet-forum module
} {
    return [util_memoize "im_package_forum_id_helper"]
}

ad_proc -private im_package_forum_id_helper {} {
    return [db_string im_package_core_id {
        select package_id from apm_packages
        where package_key = 'intranet-forum'
    } -default 0]
}


ad_proc -public im_forum_is_task_or_incident { topic_type_id } {
    Returns 1 if it's a "Task" or "Incident"
} {
    if {$topic_type_id == [im_topic_type_id_task] || $topic_type_id == [im_topic_type_id_incident]} {
	return 1
    } else {
	return 0
    }
}


ad_proc -public im_forum_topic_type_select { select_name { default "" } } {
    Returns an html select box named $select_name and defaulted to
    $default with a list of all topic types (task, incident, news, ...)
} {
    return [im_category_select "Intranet Topic Type" $select_name $default]
}

ad_proc -public im_forum_topic_status_select { select_name { default "" } } {
    Returns an html select box named $select_name and defaulted to
    $default with a list of all stati for Tasks and Incidents
} {
    return [im_category_select "Intranet Topic Status" $select_name $default]
}


ad_proc -public im_forum_notification_select {name {default ""}} {
    Return a formatted HTML select box with the notification
    options for a im_forum_topic.
} {
    set checked_major ""
    set checked_all ""
    set checked_none ""
    if {[string equal $default "major"]} { set checked_major "checked" }
    if {[string equal $default "all"]} { set checked_all "checked" }
    if {[string equal $default "none"]} { set checked_none "checked" }

    return "
<input type=radio name=$name value=major $checked_major>Important Updates
<input type=radio name=$name value=all $checked_all>All Updates
<input type=radio name=$name value=none $checked_none>No Updates
"
}


ad_proc -public im_forum_scope_select {select_name user_id {default ""} } {
    Returns a formatted HTML "scope" select, according to user
    permissions.
    If the scope is limited to a the PM, just display a HTML
    text instead of a SelectBox.
} {
    set public_selected ""
    set group_selected ""
    set staff_selected ""
    set client_selected ""
    set not_client_selected ""
    set pm_selected ""
    switch $default {
	public { set public_selected "selected" }
	group { set group_selected "selected" }
	staff { set staff_selected "selected" }
	client { set client_selected "selected" }
	not_client { set not_client_selected "selected" }
	pm { set pm_selected "selected" }
    }

    set option_list [list]
    if {[im_permission $user_id add_topic_public]} { lappend option_list "<option value=public $public_selected>Public (everybody in the system)</option>\n" }
    if {[im_permission $user_id add_topic_group]} { lappend option_list "<option value=group $group_selected>Project (all project members)</option>" }
    if {[im_permission $user_id add_topic_staff]} { lappend option_list "<option value=staff $staff_selected>Staff (employees only)</option>" }
    if {[im_permission $user_id add_topic_client]} { lappend option_list "<option value=client $client_selected>Clients and PM only</option>" }
    if {[im_permission $user_id add_topic_noncli]} { lappend option_list "<option value=not_client $not_client_selected>Provider (project members without clients)</option>" }
    if {[im_permission $user_id add_topic_pm]} { lappend option_list "<option value=pm $pm_selected>Project Manager</option>" }

    if {1 == [llength $option_list]} {
	return "ProjectManager<input type=hidden name=scope value=\"pm\">"
    } else {
	return "<select name=scope>[join $option_list " "]</select>"
    }
}

ad_proc -public im_forum_scope_html {scope } {
    Returns a formatted HTML "scope"
} {
    set html ""
    switch $scope {
	public { set html "Public (everybody in the system)"}
	group {set html "All group members"}
	staff { set html "Staff group members only"}
	client { set html "Client group members and the PM only"}
	not_client { set html "Staff and Freelance group members"}
	pm { set html "Project Manager only"}
	default { set html "undefined"}
    }
    return $html
}




# ------------------------------------------------------------------
# Procedures
# ------------------------------------------------------------------

ad_proc -public im_forum_potential_asignees {user_id object_id} {
    Return a key-value list of all persons to whom the current
    user may assign his task or issue.
    <ul>
    <li>Project: <br>
	This list is restricted to the PM for customers 
	and freelancers.
    <li>Customer:<br>
	May be restricted to the Key Account
    </ul>
    The code is written using a large SQL "union" that joins
    several partial SQLs that select the user_id/user_name
    pairs for each of the user permissions.
    I have chosen this approach because otherwise I would 
    have had to calculate the set union in tcl which could
    be even more cumbersome and slow.
} {

    # ----------------------- Get Parameters -----------------------
    # Get the people related to the projects
    # We use the list of system administrators as a fallback
    # value in case the list of object members or object admins is emtpy.

    set admin_group_id [im_admin_group_id]
    set customer_group_id [im_customer_group_id]
    set employee_group_id [im_employee_group_id]
    set admins [db_list get_admins "select member_id from group_distinct_member_map where group_id = :admin_group_id"]

    set object_admins [im_biz_object_admin_ids $object_id]

    # Avoid empty select list: Add the system admins to the
    # list if the list was empty
    if {![llength $object_admins]} { set object_admins $admins }

    set object_members [im_biz_object_admin_ids $object_id]
    # Avoid empty select list: Add the system admins to the
    # list if the list was empty
    if {![llength $object_members]} { set object_members $admins }

    # Convert into forma suitable for SQL select
    set object_admins_commalist [join $object_admins ","]
    set object_members_commalist [join $object_members ","]


    # ----------------------- Start building the SQL Query ----------
    #
    set object_admin_sql "(
-- object_admin_sql
select distinct
	u.user_id,
	im_name_from_user_id(u.user_id) as user_name
from
	users u
where
	user_id in ($object_admins_commalist)
)"

    set object_group_sql "(
select distinct
	u.user_id,
	im_name_from_user_id(u.user_id) as user_name
from
	users u
where
	user_id in ($object_members_commalist)
)"

    # If the user can talk to the public (probably a SenMan
    # or SysAdmin), he can also assign the task to everybody.
    # ToDo: This may cause problems with large installations
    set public_sql "(
-- public_sql
select distinct
	u.user_id,
	im_name_from_user_id(u.user_id) as user_name
from
	users u
)"

    # Add the objects customers to the list
    set object_customer_sql "(
-- object_customer_sql
select distinct
	u.user_id,
	im_name_from_user_id(u.user_id) as user_name
from
	acs_rels r,
	group_member_map m,
	users u
where
	r.object_id_one = :object_id
	and r.object_id_two = u.user_id
	and m.member_id = u.user_id
	and m.group_id = :customer_group_id
)"

    # Add all object members to the list who are
    # not customers
    set object_non_customer_sql "(
-- object_non_customer_sql
select distinct
	u.user_id,
	im_name_from_user_id(u.user_id) as user_name
from
	acs_rels r,
	group_member_map m,
	users u
where
	r.object_id_one = :object_id
	and r.object_id_two = u.user_id
	and m.member_id = u.user_id
	and not(m.group_id = :customer_group_id)
)"

    set object_staff_sql "(
-- object_staff_sql
select distinct
	u.user_id,
	im_name_from_user_id(u.user_id) as user_name
from
	acs_rels r,
	group_member_map m,
	users u
where	r.object_id_one = :object_id
	and r.object_id_two = u.user_id
	and m.member_id = u.user_id
	and m.group_id = :employee_group_id
)"

    set sql_list [list]

    # Don't enable the list of the entire public - 
    # too many users in large installations
#    if {[im_permission $user_id add_topic_public]} {
#	lappend sql_list $public_sql
#    }
    if {[im_permission $user_id add_topic_group]} {
	lappend sql_list $object_group_sql
    }
    if {[im_permission $user_id add_topic_staff]} {
	lappend sql_list $object_staff_sql
    }
    if {[im_permission $user_id add_topic_client]} {
	lappend sql_list $object_customer_sql
    }
    if {[im_permission $user_id add_topic_noncli]} {
	lappend sql_list $object_non_customer_sql
    }
    if {[im_permission $user_id add_topic_pm]} {
	lappend sql_list $object_admin_sql
    }

    # Append an empty string to the SQL in case there
    # are no permissions for a user to avoid an error
    lappend sql_list "select 0 as user_id, '' as user_name from dual"

    set sql [join $sql_list " UNION "]
    ns_log Notice "im_forum_potential_asignees: sql=$sql"


    set asignee_list [list]
    db_foreach object_admins $sql {
	if {!$user_id} { continue }
	lappend asignee_list $user_id
	lappend asignee_list $user_name
    }

    # Worst case - the user has absolutely no rights
    # and there are no global admins: Add the system 
    # user
    if {0 == [llength $asignee_list]} {

	set system_owner_email [ad_parameter -package_id [ad_acs_kernel_id] SystemOwner]
	set system_owner_id [db_string user_id "select party_id from parties where lower(email) = lower(:system_owner_email)" -default 0]
	set system_owner_name [db_string sysowner_name "select im_name_from_user_id(:system_owner_id) from dual"]

	lappend asignee_list $system_owner_id
	lappend asignee_list $system_owner_name
    }
    return $asignee_list
}



ad_proc -public im_forum_topic_alert_user {
    $topic_id
    $owner_id 
    $asignee_id 
    $topic_status_id 
    $old_topic_status_id
} {
    Returns 1/0 to indicate whether the specific user wants to be
    informed about a specific event
} {
    return 1
}




# ----------------------------------------------------------------------
# Render a single TIND (Task, Incident, News or Discussion)
# ----------------------------------------------------------------------

ad_proc -public im_forum_render_tind {
	topic_id parent_id
	topic_type_id topic_type 
        topic_status_id topic_status
	owner_id asignee_id owner_name asignee_name
	user_id object_id object_name object_admin
	subject message
	posting_date due_date
	priority scope
        receive_updates
        return_url
} {
    Render the rows of a single TIND
} {
    set bgcolor(0) " class=roweven"
    set bgcolor(1) " class=rowodd"

    set user_is_group_member_p [ad_user_group_member $object_id $user_id]
    set task_or_incident_p [im_forum_is_task_or_incident $topic_type_id]

    set ctr 1
    set tind_html "
		<tr $bgcolor([expr $ctr % 2])>
		  <td>Subject:</td>
		  <td>
		    [im_gif $topic_type_id "$topic_type"] 
		    $subject"
    append tind_html " (<A href=new?parent_id=$topic_id&[export_url_vars return_url]>Reply</A>)"

    if {$object_admin || $user_id==$owner_id} {
	append tind_html " (<A href=new?[export_url_vars topic_id return_url]>Edit</A>)"
    }

    append tind_html "
		  </td>
		</tr>"
    incr ctr


    if {$topic_type_id != [im_topic_type_id_reply]} {
	append tind_html "
		<tr $bgcolor([expr $ctr % 2])>
		  <td>Posted in:</td>
		  <td><A href=[im_biz_object_url $object_id]>$object_name</A></td>
		</tr>\n"
	incr ctr
    }

    if {0 != $parent_id && "" != $parent_id} {
	set parent_subject [db_string parent_subject "select subject from im_forum_topics where topic_id=:parent_id" -default ""]
	append tind_html "
		<tr $bgcolor([expr $ctr % 2])>
		  <td>Parent posting:</td>
		  <td><A href=/intranet-forum/view?topic_id=$parent_id>$parent_subject</A></td>
		</tr>\n"
	incr ctr
    }


    append tind_html "
		<tr $bgcolor([expr $ctr % 2])>
		  <td>Posted by:</td><td>
		    <A HREF=/intranet/users/view?user_id=$owner_id>
		      $owner_name
		   </A>
		  </td>
		</tr>\n"
    incr ctr


    # Show the status only for tasks and incidents
    # For all other it really doesn't matter.
    if {$task_or_incident_p} {
	set topic_status_msg $topic_status
	if {$user_id == $asignee_id && $topic_status_id == [im_topic_status_id_assigned]} {
	    # We are assigned to this task/incident,
	    # but we haven't confirmed yet
	    append topic_status_msg " : <font color=red>Please Accept or Reject the $topic_type</font>"
	}
	append tind_html "
		<tr $bgcolor([expr $ctr % 2])>
		  <td>Status:</td>
                  <td>$topic_status_msg</td>
		</tr>\n"
	incr ctr
    }


    append tind_html "
		<tr $bgcolor([expr $ctr % 2])>
		  <td>Posting Date:</td>
		  <td>$posting_date</td>
		</tr>\n"
    incr ctr

    # Only tasks and incidents have a priority, assignee and due date.
    if {$task_or_incident_p} {
	append tind_html "
		<tr $bgcolor([expr $ctr % 2])>
		  <td>Priority:</td>
		  <td>$priority</td>
		</tr>\n"
	incr ctr

	# Hide the asignee from a customer or others if they don't have
	# permissions to see the user.
	set asignee_html [im_render_user_id $asignee_id $asignee_name $user_id $object_id]
	if {"" != $asignee_html} {

	    append tind_html "
		<tr $bgcolor([expr $ctr % 2])>
		  <td>Assigned to:</td>
		  <td>\n"
	    if {"" == $asignee_name} { 
		append tind_html "unassigned"
	    } else {
		append tind_html "
		    <A href=/intranet/users/view?user_id=$asignee_id>
		      $asignee_name
		    </A>"
	    }
	}

	
	if {$object_admin} {
	    append tind_html " (<A href=assign?[export_url_vars topic_id return_url]>Assign</A>)"
	}
	append tind_html "
		  </td>
		</tr>\n"
	incr ctr


	if {$due_date != ""} {
	    append tind_html "
		<tr $bgcolor([expr $ctr % 2])>
		  <td>Due Date:</td>
		  <td>$due_date</td>
		</tr>\n"
	    incr ctr
	}
    }

    # Don't show the visibility information for reply messages
    # (not necessary because it is governed by the thread parent)
    if {$topic_type_id != [im_topic_type_id_reply]} {
	append tind_html "
                <tr $bgcolor([expr $ctr % 2])>
                  <td>Visible for</td>
                  <td>[im_forum_scope_html $scope]
                  </td>
                </tr>"
	incr ctr

	# Show whether the user has subscribed to updates
	append tind_html "
                <tr $bgcolor([expr $ctr % 2])>
                  <td>Receive updates</td>
                  <td>$receive_updates
                  </td>
                </tr>"
	incr ctr
    }

    # Only allow plain text messages
    set html_p "f"
    append tind_html "
		<tr class=rowplain><td colspan=2>
		  <table cellspacing=2 cellpadding=2 border=0><tr><td>
		    [ad_convert_to_html -html_p $html_p -- $message]
		  </td></tr></table>
		</td></tr>
    "
    return $tind_html
}


# ----------------------------------------------------------------------
# Render a Thread
# ----------------------------------------------------------------------

ad_proc -public im_forum_render_thread { topic_id user_id object_id object_name object_admin return_url} {
    Returns a formatted HTML representing the child postings
    of the specified topic.
} {
    set topic_sql "
select
	t.*,
	ug.project_name,
	tr.indent_level,
	(10-tr.indent_level) as colspan_level,
	ftc.category as topic_type,
	fts.category as topic_status,
	im_name_from_user_id(ou.user_id) as owner_name,
	im_name_from_user_id(au.user_id) as asignee_name
from
	(select
		topic_id,
		(level-1) as indent_level
	from
		im_forum_topics t
	start with
		topic_id=:topic_id
	connect by
		parent_id = PRIOR topic_id
	) tr,
	im_forum_topics t,
	users ou,
	users au,
	im_projects ug,
	im_categories ftc,
	im_categories fts
where
	tr.topic_id = t.topic_id
	and t.owner_id=ou.user_id
	and ug.project_id=t.object_id
	and t.asignee_id=au.user_id(+)
	and t.topic_type_id=ftc.category_id(+)
	and t.topic_status_id=fts.category_id(+)
"

    # -------------- Setup the outer table with indents-----------------------

    # outer table with 10 columns for indenting
    set thread_html "
<table cellspacing=0 border=0 cellpadding=3>
<tr>
 <td>&nbsp; &nbsp; &nbsp; &nbsp; &nbsp; </td>
 <td>&nbsp; &nbsp; &nbsp; &nbsp; &nbsp; </td>
 <td>&nbsp; &nbsp; &nbsp; &nbsp; &nbsp; </td>
 <td>&nbsp; &nbsp; &nbsp; &nbsp; &nbsp; </td>
 <td>&nbsp; &nbsp; &nbsp; &nbsp; &nbsp; </td>
 <td>&nbsp; &nbsp; &nbsp; &nbsp; &nbsp; </td>
 <td>&nbsp; &nbsp; &nbsp; &nbsp; &nbsp; </td>
 <td>&nbsp; &nbsp; &nbsp; &nbsp; &nbsp; </td>
 <td>&nbsp; &nbsp; &nbsp; &nbsp; &nbsp; </td>
 <td>&nbsp; &nbsp; &nbsp; &nbsp; &nbsp; </td>
</tr>
"


    # -------------- Render all TIND elements -----------------------

    set msg_ctr 1
    db_foreach get_topic $topic_sql {

	# skip the first message, displayed above.
	if {$msg_ctr != 1} {

	    # position table within the outer indent-table
	    append thread_html "<tr>"
	    if {$indent_level > 0} {
		append thread_html "<td colspan=$indent_level>&nbsp;</td>"
	    }
	    append thread_html "
		  <td colspan=$colspan_level>
		     <table border=0 cellpadding=0 bgcolor=#E0E0E0>"

	    # don't show received updates for everything but the main message
	    set receive_updates ""

	    append thread_html " [im_forum_render_tind $topic_id 0 $topic_type_id $topic_type $topic_status_id $topic_status $owner_id $asignee_id $owner_name $asignee_name $user_id $object_id $object_name $object_admin $subject $message $posting_date $due_date $priority $scope $receive_updates $return_url]

		    </table>
		  </td>
		</tr>\n"
	}
	incr msg_ctr
    }
    return $thread_html
}


# ----------------------------------------------------------------------
# Forum List Page Component
# ---------------------------------------------------------------------

ad_proc -public im_forum_component {
    {-view_name ""} 
    {-forum_order_by "priority"} 
    {-restrict_to_mine_p f} 
    {-restrict_to_topic_type_id 0} 
    {-restrict_to_topic_status_id 0} 
    {-restrict_to_asignee_id 0} 
    {-max_entries_per_page 0} 
    {-start_idx 1} 
    {-restrict_to_new_topics 0} 
    {-restrict_to_folder 0}
    -user_id 
    -object_id 
    -current_page_url 
    -return_url 
    -export_var_list 
    -forum_type 
} {
    Creates a HTML table showing a table of "Discussion Topics" of 
    various types. Parameters:
    <ul>
      <li>object_id : The object_id of the object where the discussion takes place
          (historic name...)
      <li>restrict_to_topic_type_id: 0=All, 1=Tasks & Incidents, 2=Unresolved, other=Specific
      <li>forum_type: ....
    </ul>

    ToDo: Very ugly! Future packages won'te be able to use this component because
    the object_type used here is limited to the object types known right now.
    Future versions would need to call an object method to render adecuately the
    object name etc.
} {
    ns_log Notice "im_forum_component: forum_type=$forum_type"
    ns_log Notice "im_forum_component: view_name=$view_name"
    ns_log Notice "im_forum_component: restrict_to_asignee_id=$restrict_to_asignee_id"
    ns_log Notice "im_forum_component: restrict_to_mine_p=$restrict_to_mine_p"
    ns_log Notice "im_forum_component: restrict_to_topic_type_id=$restrict_to_topic_type_id"
    ns_log Notice "im_forum_component: restrict_to_new_topics=$restrict_to_new_topics"
    ns_log Notice "im_forum_component: restrict_to_folder=$restrict_to_folder"


    set bgcolor(0) " class=roweven"
    set bgcolor(1) " class=rowodd"

    if {!$max_entries_per_page} { set max_entries_per_page 10 }
    set end_idx [expr $start_idx + $max_entries_per_page - 1]

    # ---------------------- Get the right view ---------------------------
    # If empty, try with "forum_list_<type>".
    # If that doesn't work try with the default "forum_list_short".
    if {"" == $view_name} {
	# No view_name defined (default for most pages).
	# So we append the "type of the forum" (=customer, project, ...)
	# to "forum_list_". This allows the writers of future modules
	# to define customized views for their new business objects.
	set view_name "forum_list_$forum_type"
	set view_id [db_string get_view_id "select view_id from im_views where view_name=:view_name" -default 0]

    } else {
	# We have got an explicit view_name, probably through
	# HTTP parameters.
	set view_id [db_string get_view_id "select view_id from im_views where view_name=:view_name" -default 0]
    }

    if {0 == $view_id} {
	# We haven't found the specified view, so let's emit an error message
	# and proceed with a default view that should work everywhere.
	ns_log Error "im_forum_component: we didn't find view_name=$view_name"
	set view_name "forum_list_short"
	set view_id [db_string get_view_id "select view_id from im_views where view_name=:view_name" -default 0]
    }
    ns_log Notice "im_forum_component: view_id=$view_id"
    if {!$view_id} {
	return "<b>Unable to find view '$view_name'</b>\n"
    }

    # ---------------------- Get Columns ----------------------------------
    # Define the column headers and column contents that
    # we want to show:
    #
    set column_headers [list]
    set column_vars [list]

    set column_sql "
	select
	        column_name,
	        column_render_tcl,
	        visible_for
	from
	        im_view_columns
	where
	        view_id=:view_id
	        and group_id is null
	order by
	        sort_order
    "

    db_foreach column_list_sql $column_sql {
	if {"" == $visible_for || [eval $visible_for]} {
        lappend column_headers "$column_name"
        lappend column_vars "$column_render_tcl"
	}
    }
    ns_log Notice "im_forum_component: column_headers=$column_headers"

    # -------- Compile the list of parameters to pass-through-------

    set bind_vars [ns_set create]
    foreach var $export_var_list {
        upvar 1 $var value
        if { [info exists value] } {
            ns_set put $bind_vars $var $value
            ns_log Notice "im_forum_component: $var <- $value"
        }
    }

    ns_set delkey $bind_vars "forum_order_by"
    set params [list]
    set len [ns_set size $bind_vars]
    for {set i 0} {$i < $len} {incr i} {
        set key [ns_set key $bind_vars $i]
        set value [ns_set value $bind_vars $i]
        if {![string equal $value ""]} {
            lappend params "$key=[ns_urlencode $value]"
        }
    }
    set pass_through_vars_html [join $params "&"]

    # ---------------------- Format Header ----------------------------------

    # Set up colspan to be the number of headers + 1 for the # column
    set colspan [expr [llength $column_headers] + 1]

    # Format the header names with links that modify the
    # sort order of the SQL query.
    #
    set table_header_html "<tr>\n"
    foreach col $column_headers {

	set cmd_eval ""
	ns_log Notice "im_forum_component: eval=$cmd_eval"
	set cmd "set cmd_eval $col"
        eval $cmd

	if { [string compare $forum_order_by $cmd_eval] == 0 } {
	    append table_header_html "  <td class=rowtitle>$col</td>\n"
	} else {
	    append table_header_html "  <td class=rowtitle>
            <a href=$current_page_url?$pass_through_vars_html&forum_order_by=[ns_urlencode $cmd_eval]>$cmd_eval</a>
            </td>\n"
	}
    }
    append table_header_html "</tr>\n"



    # ---------------------- ------------------- ---------------------------
    # ---------------------- Build the SQL query ---------------------------

    set order_by_clause "order by priority"
    switch $forum_order_by {
	"P" { set order_by_clause "order by priority" }
	"Subject" { set order_by_clause "order by upper(subject)" }
	"Type" { set order_by_clause "order by topic_type_id" }
	"Due" { set order_by_clause "order by due_date" }
	"Who" { set order_by_clause "order by upper(owner_initials)" }
    }


    set restrictions []
    if {0 != $object_id} {
	lappend restrictions "t.object_id=:object_id" 
    }
    if {[string equal "t" $restrict_to_mine_p]} {
	lappend restrictions "(owner_id=:user_id or asignee_id=:user_id)" 
    }
    if {$restrict_to_topic_status_id} {
	lappend restrictions "topic_status_id=:restrict_to_topic_status_id" 
    }
    if {$restrict_to_asignee_id} {
	lappend restrictions "asignee_id=:restrict_to_asignee_id" 
    }
    if {$restrict_to_new_topics} {
	lappend restrictions "(m.read_p is null or m.read_p='f')" 
    }
    switch $restrict_to_folder {
	0 {
	    # "Active topics" = "Inbox"
	    lappend restrictions "(m.folder_id is null or m.folder_id=0)" 
	}
	1 {
	    # Deleted topics
	    lappend restrictions "m.folder_id=:restrict_to_folder" 
	}
	2 {
	    # Unresolved topics
	    lappend restrictions "(t.topic_status_id != [im_topic_status_id_closed] and
            t.topic_type_id in ([im_topic_type_id_task],[im_topic_type_id_incident]))"
	}
	default {
	    lappend restrictions "m.folder_id=:restrict_to_folder" 
	}
    }


    # ToDo: Replace this by a hierarchy of topic types 
    # such as in project types.
    if {$restrict_to_topic_type_id} {
	# 0=All, 1=Tasks & Incidents, other=Specific Type
	if {1 == $restrict_to_topic_type_id} {
	    lappend restrictions "(topic_type_id=1102 or topic_type_id=1104)"
	} else {
	    lappend restrictions "topic_type_id=:restrict_to_topic_type_id"
	}
    }

    set restriction_clause [join $restrictions "\n\tand "]
    if {"" != $restriction_clause} { 
	set restriction_clause "and $restriction_clause" 
    }

    set user_is_employee_p [im_user_is_employee_p $user_id]
    set user_is_customer_p [im_user_is_customer_p $user_id]

    # Forum items have a complicated "scoped" permission 
    # system where you can say who should be able to read
    # the topic in function of the project/customer/...
    # membership.
    # Also, items can be attached to all kinds of objects,
    # so that we need some object_type meta data
    # (im_biz_object_urls) to build correct URLs to link
    # to these items.
    # Finally we can have "read" and "unread" items and
    # Items that have been filed in a specific "folder".
    # So we are getting close here to a kind of MS-Outlook...
    set forum_sql "
select
	t.*,
	acs_object.name(t.object_id) as object_name,
	m.read_p,
	m.folder_id,
	f.folder_name,
	m.receive_updates,
	u.url as object_view_url,
	im_initials_from_user_id(t.owner_id) as owner_initials,
	im_initials_from_user_id(t.asignee_id) as asignee_initials,
	im_category_from_id(t.topic_type_id) as topic_type,
	im_category_from_id(t.topic_status_id) as topic_status
from
	im_forum_topics t,
	im_forum_folders f,
	acs_objects o,
        (select * from im_forum_topic_user_map where user_id=:user_id) m,
	(select * from im_biz_object_urls where	url_type='view') u,
	(	select 1 as p, 
			object_id_one as object_id 
		from 	acs_rels
		where	object_id_two = :user_id
	) member_objects,
	(	select 1 as p, 
			r.object_id_one as object_id 
		from 	acs_rels r,
			im_biz_object_members m
		where	r.object_id_two = :user_id
			and r.rel_id = m.rel_id
			and m.object_role_id in (1301, 1302, 1303)
	) admin_objects
where
        (t.parent_id is null or t.parent_id=0)
        and t.object_id != 1
	and t.topic_id=m.topic_id(+)
	and m.folder_id=f.folder_id(+)
	and t.object_id = member_objects.object_id(+)
	and t.object_id = admin_objects.object_id(+)
	and t.object_id = o.object_id
	and o.object_type = u.object_type(+)
	and 1 =	im_forum_permission(
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
	$restriction_clause
$order_by_clause"



    # ---------------------- Limit query to MAX rows -------------------------
    
    # We can't get around counting in advance if we want to be able to
    # sort inside the table on the page for only those rows in the query 
    # results
    
    set limited_query [im_select_row_range $forum_sql $start_idx $end_idx]
    set total_in_limited_sql "
	select count(*)
	from 
		im_forum_topics t,
		im_forum_topic_user_map m,
		im_forum_folders f
	where 
		object_id != 1
		and (t.parent_id is null or t.parent_id=0)
		and t.topic_id=m.topic_id(+)
		and m.folder_id=f.folder_id(+)
		$restriction_clause
    "

    set total_in_limited [db_string projects_total_in_limited $total_in_limited_sql]
    ns_log Notice "im_forum_component: total_in_limited=$total_in_limited"
    set selection "select z.* from ($limited_query) z $order_by_clause"

    # How many items remain unseen?
    set remaining_items [expr $total_in_limited - $start_idx - $max_entries_per_page + 1]


    # ---------------------- Format the body -------------------------------

    set table_body_html ""
    set ctr 0
    set idx $start_idx
    set old_object_id 0

    set limited_query $forum_sql

    db_foreach forum_query $limited_query {
        if {$read_p == "t"} {set read "read"} else {set read "unread"}
        if {$folder_id == ""} {set folder_name "Inbox"}

        # insert intermediate headers for every project
        if {[string equal "Project" $forum_order_by]} {
            if {$old_object_id != $object_id} {
                append table_body_html "
                <tr><td colspan=$colspan>&nbsp;</td></tr>
                <tr><td class=rowtitle colspan=$colspan>
                  <A href=/intranet/projects/view?group_id=$object_id>
                    $object_name
                  </A>
                </td></tr>\n"
                set old_object_id $object_id
            }
        }

        append table_body_html "<tr$bgcolor([expr $ctr % 2])>\n"
        foreach column_var $column_vars {
            append table_body_html "\t<td valign=top>"
            set cmd "append table_body_html $column_var"
            eval $cmd
            append table_body_html "</td>\n"
        }
        append table_body_html "</tr>\n"

        incr ctr
        if { $max_entries_per_page > 0 && $ctr >= $max_entries_per_page } {
            break
	}
    }
    # Show a reasonable message when there are no result rows:
    if { [empty_string_p $table_body_html] } {
	set table_body_html "
	<tr><td colspan=$colspan align=center><b>
	There are no active items.
	</b></td></tr>"
    }

    if { $ctr == $max_entries_per_page && $end_idx < $total_in_limited } {
	# This means that there are rows that we decided not to return
	# Include a link to go to the next page
	set next_start_idx [expr $end_idx + 1]
	set next_page_html "($remaining_items more) <A href=$current_page_url?$pass_through_vars_html&start_idx=$next_start_idx>&gt;&gt;</a>"
    } else {
	set next_page_html ""
    }

    if { $start_idx > 1 } {
	# This means we didn't start with the first row - there is
	# at least 1 previous row. add a previous page link
	set previous_start_idx [expr $start_idx - $max_entries_per_page]
	if { $previous_start_idx < 1 } {
	set previous_start_idx 1
	}
	set previous_page_html "<A href=$current_page_url?$pass_through_vars_html&start_idx=$previous_start_idx>&lt;&lt;</a>"
    } else {
	set previous_page_html ""
    }


    # ---------------------- Format the action bar at the bottom ------------

    set table_footer "
<tr>
  <td $bgcolor([expr $ctr % 2]) colspan=$colspan align=right>
    $previous_page_html
    $next_page_html
    <select name=action>
	<option value=mark_as_read>Mark as read</option>
	<option value=mark_as_unread>Mark as unread</option>
	<option value=move_to_deleted>Move to Deleted</option>
	<option value=move_to_inbox>Move to Active</option>
    </select>
    <input type=submit name=submit value='Apply'>
  </td>
</tr>"

    # ---------------------- Join all parts together ------------------------
#<form action=/intranet-forum/forum-action method=POST>
    set component_html "

<form action=/intranet-forum/forum-action method=POST>
[export_form_vars object_id return_url]
<table bgcolor=white border=0 cellpadding=1 cellspacing=1>
  $table_header_html
  $table_body_html
  $table_footer
</table>
</form>\n"

    return $component_html
}


# ----------------------------------------------------------------------
# Forum Navigation Bar
# ----------------------------------------------------------------------

# <A HREF=/intranet-forum/index?[export_url_vars object_id return_url]>

ad_proc -public im_forum_create_bar { title_text object_id {return_url ""} } {
    Returns rendered HTML table with icons for creating new 
    forum elements
} {
    set html "
<table cellpadding=0 cellspacing=0 border=0>
<tr>
<td>
  <A HREF=/intranet-forum/index?[export_url_vars object_id return_url]>
    $title_text
  </A>
</td>
<td>
  <A href='/intranet-forum/new?topic_type_id=1102&[export_url_vars object_id return_url]'>
    [im_gif "incident" "Create new Incident"]
  </A>
</td>
<td>
  <A href='/intranet-forum/new?topic_type_id=1104&[export_url_vars object_id return_url]'>
    [im_gif "task" "Create new Task"]
  </A>
</td>
<td>
  <A href='/intranet-forum/new?topic_type_id=1106&[export_url_vars object_id return_url]'>
    [im_gif "discussion" "Create a new Discussion"]
  </A>
</td>
<td>
  <A href='/intranet-forum/new?topic_type_id=1100&[export_url_vars object_id return_url]'>
    [im_gif "news" "Create new News Item"]
  </A>
</td>
<td>
  <A href='/intranet-forum/new?topic_type_id=1108&[export_url_vars object_id return_url]'>
    [im_gif "note" "Create new Note"]
  </A>
</td>
</tr>
</table>
"
}



ad_proc -public im_forum_navbar { base_url export_var_list {forum_folder 0} } {
    Returns rendered HTML code for a horizontal sub-navigation
    bar for /intranet-forum/.
} {
    # -------- Compile the list of parameters to pass-through-------
    set bind_vars [ns_set create]
    foreach var $export_var_list {
	upvar 1 $var value
	if { [info exists value] } {
	    ns_set put $bind_vars $var $value
	}
    }

    # --------------- Determine the calling page ------------------
    set user_id [ad_get_user_id]
    set section ""
    
    switch $forum_folder {
	0 { set section "Inbox" }
	1 { set section "Deleted" }
	2 { set section "Unresolved" }
	default {
	    set section "Inbox"
	}
    }

    set sel "<td class=tabsel>"
    set nosel "<td class=tabnotsel>"
    set a_white "<a class=whitelink"
    set tdsp "<td>&nbsp;</td>"

    set active_topics "$tdsp$nosel<a href='index'>Inbox</a></td>"
    set deleted_topics "$tdsp$nosel<a href='index?forum_folder=1'>Deleted</a></td>"
    set unresolved_topics "$tdsp$nosel<a href='index?forum_folder=2'>Unresolved</a></td>"
    set discussion_view "$tdsp$nosel<a href='index?forum_view_name=forum_list_discussion'>Discussion View</a></td>"
    set history "$tdsp$nosel<a href='index?forum_view_name=forum_list_history'>History</a></td>"

    switch $section {
"Inbox" {set active_topics "$tdsp$sel Inbox</td>"}
"Deleted" {set deleted_topics "$tdsp$sel Deleted</td>"}
"Unresolved" {set unresolved_topics "$tdsp$sel Unresolved</td>"}
"Discussion View" {set discussion_view "$tdsp$sel Discussion View</td>"}
"History" {set history "$tdsp$sel History</td>"}
default {
    # Nothing - just let all sections deselected
}
    }


# $discussion_view $history

    set navbar "
<table width=100% cellpadding=0 cellspacing=0 border=0>
  <tr>
    <td colspan=6 align=right>
      <table cellpadding=1 cellspacing=0 border=0>
	<tr>
	  $active_topics
	  $deleted_topics
	  $unresolved_topics
	</tr>
      </table>
    </td>
  </tr>
  <tr>
    <td colspan=6 class=tabnotsel align=center>
	&nbsp;
    </td>
  </tr>
</table>
"
    return $navbar
}


