# /packages/intranet-forum/tcl/intranet-forum-procs.tcl
#
# Copyright (C) 2003 - 2009 ]project-open[
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
ad_proc -public im_topic_type_id_discussion { } { return 1106 }
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
    if {[im_permission $user_id add_topic_public]} { 
	lappend option_list "<option value=public $public_selected>[_ intranet-forum.lt_Public_everybody_in_t]</option>\n" 
    }
    if {[im_permission $user_id add_topic_group]} { 
	lappend option_list "<option value=group $group_selected>[_ intranet-forum.lt_Project_all_project_m]</option>" 
    }
    if {[im_permission $user_id add_topic_staff]} { 
	lappend option_list "<option value=staff $staff_selected>[_ intranet-forum.Staff_employees_only]</option>" 
    }
    if {[im_permission $user_id add_topic_client]} { 
	lappend option_list "<option value=client $client_selected>Clients and PM only</option>" 
    }
    if {[im_permission $user_id add_topic_noncli]} { lappend option_list "<option value=not_client $not_client_selected>[_ intranet-forum.lt_Provider_project_memb]</option>" 
    }
    if {[im_permission $user_id add_topic_pm]} { 
	lappend option_list "<option value=pm $pm_selected>[_ intranet-forum.Project_Manager]</option>" 
    }

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
	public { set html "[_ intranet-forum.lt_Public_everybody_in_t]"}
	group {set html "[_ intranet-forum.All_group_members]"}
	staff { set html "[_ intranet-forum.lt_Staff_group_members_o]"}
	client { set html "[_ intranet-forum.lt_Client_group_members_]"}
	not_client { set html "[_ intranet-forum.lt_Staff_and_Freelance_g]"}
	pm { set html "[_ intranet-forum.Project_Manager_only]"}
	default { set html "[_ intranet-forum.undefined]"}
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
	This list is restricted to the PM for companies 
	and freelancers.
    <li>Company:<br>
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

    if {![llength $admins]} {
        ad_return_complaint 1 "Bad System Configuration:<br>
        The list of system administrators is empty.<br>
        However, this list is necessary to determine certain default
        permissions in the Forum system.<br>
        Please contact your system administrator and ask him to add
        atleast one user to the group P/O Admins."
	return
    }

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
		membership_rels mr,
		users u
	where
		r.object_id_one = :object_id
		and r.object_id_two = u.user_id
		and m.rel_id = mr.rel_id
		and mr.member_state = 'approved'
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
		users u
	where
		r.object_id_one = :object_id
		and r.object_id_two = u.user_id
		and u.user_id not in (
			select distinct
				m.member_id
			from	group_member_map m,
				membership_rels mr
			where	m.rel_id = mr.rel_id
				and mr.member_state = 'approved'
				and m.group_id = :customer_group_id
		)
    )"

    set object_staff_sql "(
	-- object_staff_sql
	select distinct
		u.user_id,
		im_name_from_user_id(u.user_id) as user_name
	from
		acs_rels r,
		group_member_map m,
		membership_rels mr,
		users u
	where
		r.object_id_one = :object_id
		and r.object_id_two = u.user_id
		and m.rel_id = mr.rel_id
		and mr.member_state = 'approved'
		and m.member_id = u.user_id
		and m.group_id = :employee_group_id
    )"


    set primary_accounting_contact_client_sql "(
	-- Primary contact / accounting contact of customer 
	select distinct
		user_id, 
		im_name_from_user_id(user_id) as user_name
	from (
		select   
			primary_contact_id as user_id
		from 
			im_companies c,
			im_projects p
		where 
			c.company_id = p.company_id and 
			p.project_id = :object_id
		UNION 
		select   
			accounting_contact_id as user_id
		from 
			im_companies c,
			im_projects p
		where 
			c.company_id = p.company_id and 
			p.project_id = :object_id
		UNION 
		select   
			accounting_contact_id as user_id
		from 
			im_companies
		where 
			company_id = :object_id
		UNION 
		select   
			primary_contact_id as user_id
		from 
			im_companies
		where 
			company_id = :object_id

		-- Get Primary/Accounting user is a employee of  
		UNION 
		select distinct
                        primary_contact_id as user_id
                from
                        im_companies c
                where
                        c.company_id in ( 
				select 
					object_id_one 
				from 
					acs_rels
				where 
					object_id_two = :object_id and 
					rel_type = 'im_company_employee_rel'
			) 
		UNION 
		select distinct
                        accounting_contact_id as user_id
                from
                        im_companies c
                where
                        c.company_id in ( 
				select 
					object_id_one 
				from 
					acs_rels
				where 
					object_id_two = :object_id and 
					rel_type = 'im_company_employee_rel'
			)  
  	) tt 
    )"

    set im_company_rel_sql "(
        -- get company employees of companies user has a im_company_rel with
        select distinct
                user_id,
                im_name_from_user_id(user_id) as user_name
        from (
                select distinct
                        object_id_two as user_id
                from
                        acs_rels r
                where
                        rel_type = 'im_key_account_rel' and
                        object_id_one in (
                                select
                                        object_id_one
                                from
                                        acs_rels
                                where
                                        object_id_two = :object_id and
                                        rel_type = 'im_company_employee_rel'
                         ) 
	) tt
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
	lappend sql_list $primary_accounting_contact_client_sql
	lappend sql_list $im_company_rel_sql
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
	if { "" == $user_id || "0" == $user_id } { continue }
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

    set user_is_group_member_p [im_biz_object_member_p $user_id $object_id]
    set task_or_incident_p [im_forum_is_task_or_incident $topic_type_id]

    set ctr 1
    set tind_html "
		<tr $bgcolor([expr $ctr % 2])>
		  <td>[_ intranet-forum.Subject]:</td>
		  <td>
		    [im_gif $topic_type_id "$topic_type"] 
		    $subject"
    append tind_html " (<A href=/intranet-forum/new?parent_id=$topic_id&[export_url_vars return_url]>[_ intranet-forum.Reply]</A>)"

    if {$object_admin || $user_id==$owner_id} {
	append tind_html " (<A href=/intranet-forum/new?[export_url_vars topic_id return_url]>[_ intranet-forum.Edit]</A>)"
    }

    append tind_html "
		  </td>
		</tr>"
    incr ctr


    if {$topic_type_id != [im_topic_type_id_reply]} {
	append tind_html "
		<tr $bgcolor([expr $ctr % 2])>
		  <td>[_ intranet-forum.Posted_in]</td>
		  <td><A href=[im_biz_object_url $object_id]>$object_name</A></td>
		</tr>\n"
	incr ctr
    }

    if {0 != $parent_id && "" != $parent_id} {
	set parent_subject [db_string parent_subject "select subject from im_forum_topics where topic_id=:parent_id" -default ""]
	append tind_html "
		<tr $bgcolor([expr $ctr % 2])>
		  <td>[_ intranet-forum.Parent_posting]:</td>
		  <td><A href=/intranet-forum/view?topic_id=$parent_id>$parent_subject</A></td>
		</tr>\n"
	incr ctr
    }


    append tind_html "
		<tr $bgcolor([expr $ctr % 2])>
		  <td>[_ intranet-forum.Posted_by]:</td>
		  <td>[im_render_user_id $owner_id $owner_name "" 0]</td>
		</tr>\n"
    incr ctr

    # Show the status only for tasks and incidents
    # For all other it really doesn't matter.
    if {$task_or_incident_p} {
	set topic_status_msg $topic_status
	if {$user_id == $asignee_id && $topic_status_id == [im_topic_status_id_assigned]} {
	    # We are assigned to this task/incident,
	    # but we haven't confirmed yet
	    append topic_status_msg " : <font color=red>[_ intranet-forum.lt_Please_Accept_or_Reje]</font>"
	}
	append tind_html "
		<tr $bgcolor([expr $ctr % 2])>
		  <td>[_ intranet-forum.Status]:</td>
                  <td>$topic_status_msg</td>
		</tr>\n"
	incr ctr
    }


    append tind_html "
		<tr $bgcolor([expr $ctr % 2])>
		  <td>[_ intranet-forum.Posting_Date]:</td>
		  <td>$posting_date</td>
		</tr>\n"
    incr ctr

    # Only tasks and incidents have a priority, assignee and due date.
    if {$task_or_incident_p} {
	append tind_html "
		<tr $bgcolor([expr $ctr % 2])>
		  <td>[_ intranet-forum.Priority]:</td>
		  <td>$priority</td>
		</tr>\n"
	incr ctr

	# Hide the asignee from a customers or others if they don't have
	# permissions to see the user.
	set asignee_html [im_render_user_id $asignee_id $asignee_name $user_id $object_id]
	if {"" != $asignee_html} {

	    append tind_html "
		<tr $bgcolor([expr $ctr % 2])>
		  <td>[_ intranet-forum.Assigned_to]:</td>
		  <td>\n"
	    if {"" == $asignee_name} { 
		append tind_html "unassigned"
	    } else {
		append tind_html [im_render_user_id $asignee_id $asignee_name "" 0]
	    }
	}

	
	if {$object_admin || $user_id==$owner_id} {
#	    append tind_html " (<A href=/intranet-forum/assign?[export_url_vars topic_id return_url]>[_ intranet-forum.Assign]</A>)"
	}

	append tind_html "
		  </td>
		</tr>\n"
	incr ctr


	if {$due_date != ""} {
	    append tind_html "
		<tr $bgcolor([expr $ctr % 2])>
		  <td>[_ intranet-forum.Due_Date]:</td>
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
                  <td>[_ intranet-forum.Visible_for]</td>
                  <td>[im_forum_scope_html $scope]
                  </td>
                </tr>"
	incr ctr

	# Show whether the user has subscribed to updates
	append tind_html "
                <tr $bgcolor([expr $ctr % 2])>
                  <td>[_ intranet-forum.Receive_updates]</td>
                  <td>$receive_updates
                  </td>
                </tr>"
	incr ctr
    }

    # Only allow plain text messages
    set html_p "f"
    set message_text [ad_convert_to_html -html_p $html_p -- $message]
    append tind_html "
		<tr class=rowplain><td colspan=2>
		  <table cellspacing=2 cellpadding=2 border=0><tr><td>
		    $message_text
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
		acs_object__name(t.object_id) as project_name,
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
		im_categories ftc,
		im_categories fts
	where
		tr.topic_id = t.topic_id
		and t.owner_id=ou.user_id
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
    append thread_html "</table>\n"
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
    {-start_idx 0} 
    {-restrict_to_new_topics 0} 
    {-restrict_to_folder 0}
    {-restrict_to_employees 0}
    {-forum_object_id 0}
    {-forum_start_date ""}
    {-forum_end_date ""}
    -user_id 
    {-object_id 0}
    -current_page_url 
    -return_url 
    -export_var_list 
    -forum_type
    {-write_icons 0}
    {-debug 0}
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
    # ToDo: Remove -object_id from argument list.
    # It has been replaced 2005-03-18 by forum_object_id.
    # Now doing backward compatibility operation 
    if {0 != $forum_object_id} { set object_id $forum_object_id }
    if {"" == $start_idx} { set start_idx 0}
    set forum_object_id $object_id

    if {$debug} { 
	ns_log Notice "im_forum_component: forum_type=$forum_type"
	ns_log Notice "im_forum_component: forum_object_id=$forum_object_id"
	ns_log Notice "im_forum_component: view_name=$view_name"
	ns_log Notice "im_forum_component: restrict_to_asignee_id=$restrict_to_asignee_id"
	ns_log Notice "im_forum_component: restrict_to_mine_p=$restrict_to_mine_p"
	ns_log Notice "im_forum_component: restrict_to_topic_type_id=$restrict_to_topic_type_id"
	ns_log Notice "im_forum_component: restrict_to_new_topics=$restrict_to_new_topics"
	ns_log Notice "im_forum_component: restrict_to_folder=$restrict_to_folder"
	ns_log Notice "im_forum_component: restrict_to_employees=$restrict_to_employees"
	ns_log Notice "im_forum_component: start_idx=$start_idx"
    }

    set bgcolor(0) " class=roweven"
    set bgcolor(1) " class=rowodd"

    set date_format "YYYY-MM-DD"

    set user_id [ad_get_user_id]

    if {0 == $max_entries_per_page && [string equal "home" $forum_type]} {
	set max_entries_per_page [ad_parameter -package_id [im_package_forum_id] "ForumItemsPerHomePage" "" 10]
    }

    if {0 == $max_entries_per_page && [string equal "forum" $forum_type]} {
	set max_entries_per_page [ad_parameter -package_id [im_package_forum_id] "ForumItemsPerForumPage" "" 50]
    }

    # Get the default value
    if {0 == $max_entries_per_page} { 
	set max_entries_per_page [ad_parameter -package_id [im_package_forum_id] ForumItemsPerPage "" 10]
    }

    set end_idx [expr $start_idx + $max_entries_per_page - 1]
    set user_is_employee_p [im_user_is_employee_p $user_id]
    set user_is_customer_p [im_user_is_customer_p $user_id]

    if {$restrict_to_employees && !$user_is_employee_p} { return "" }


    # ---------------------- Get the right view ---------------------------
    # If empty, try with "forum_list_<type>".
    # If that doesn't work try with the default "forum_list_short".
    if {"" == $view_name} {
	# No view_name defined (default for most pages).
	# So we append the "type of the forum" (=company, project, ...)
	# to "forum_list_". This allows the writers of future modules
	# to define customized views for their new business objects.
	set view_name "forum_list_$forum_type"
	set view_id [util_memoize [list db_string get_view_id "select view_id from im_views where view_name = '$view_name'" -default 0]]

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
    if {$debug} { ns_log Notice "im_forum_component: view_id=$view_id" }
    if {!$view_id} {
	return "<b>[_ intranet-forum.lt_Unable_to_find_view_v]</b>\n"
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
    if {$debug} { ns_log Notice "im_forum_component: column_headers=$column_headers" }

    # -------- Compile the list of parameters to pass-through-------

    set form_vars [ns_conn form]
    if {"" == $form_vars} { set form_vars [ns_set create] }

    set bind_vars [ns_set create]
    foreach var $export_var_list {
        upvar 1 $var value
        if { [info exists value] } {
            ns_set put $bind_vars $var $value
            if {$debug} { ns_log Notice "im_forum_component: $var <- $value" }
        } else {
        
            set value [ns_set get $form_vars $var]
            if {![string equal "" $value]} {
 	        ns_set put $bind_vars $var $value
 	        if {$debug} { ns_log Notice "im_forum_component: $var <- $value" }
            }
            
        }
    }

    ns_set delkey $bind_vars "forum_order_by"
    ns_set delkey $bind_vars "forum_start_idx"
    ns_set delkey $bind_vars "user_id"
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
    
    if { "1" == $write_icons  } {
	set table_header_html "<tr><td colspan=\"99\" align=\"right\">"
	append table_header_html [im_forum_create_bar "<B>[_ intranet-forum.Forum_Items]<B>" 0 $return_url]
	append table_header_html "</td></tr><tr>\n"
    } else {
	set table_header_html "<tr>\n"
    }

    foreach col $column_headers {

	set cmd_eval ""
	if {$debug} { ns_log Notice "im_forum_component: eval=$cmd_eval $col" }
	set cmd "set cmd_eval $col"
        eval $cmd
	if { [regexp "im_gif" $col] } {
	    set col_tr $cmd_eval
	} else {
	    set col_tr [lang::message::lookup "" intranet-forum.[lang::util::suggest_key $cmd_eval] $cmd_eval]
	}

	if { [string compare $forum_order_by $cmd_eval] == 0 } {
	    append table_header_html "  <td class=rowtitle>$col_tr</td>\n"
	} else {
	    append table_header_html "  <td class=rowtitle>
            <a href=$current_page_url?$pass_through_vars_html&forum_order_by=[ns_urlencode $cmd_eval]&forum_folder=$restrict_to_folder>$col_tr</a>
            </td>\n"
	}
    }
    append table_header_html "</tr>\n"


    # ---------------------- ------------------- ---------------------------
    # ---------------------- Build the SQL query ---------------------------

    # only show messages to intranet users
    set intranet_user_p 0
    set profiles [util_memoize [list db_list profiles "select profile_id from im_profiles"]]
    foreach profile_id $profiles {
    	if { [im_profile::member_p -profile_id $profile_id -user_id $user_id] } {
    		set intranet_user_p 1
    		break
    	}
    }
    
    if { $intranet_user_p } {

    	set order_by_clause "order by t.priority"
    	set order_by_clause_ext "order by priority"
    	switch $forum_order_by {
		"P" { 
			set order_by_clause "order by t.priority" 
			set order_by_clause_ext "order by priority"
		}
		"Subject" { 
			set order_by_clause "order by upper(t.subject)" 
			set order_by_clause_ext "order by upper(subject)" 
		}
		"Type" { 
			set order_by_clause "order by im_category_from_id(t.topic_type_id)" 
			set order_by_clause "order by topic_type" 
		}
		"Due" { 
			set order_by_clause "order by coalesce(t.due_date, to_date('1970-01-01','YYYY-MM-DD')) DESC" 
			set order_by_clause_ext "order by coalesce(z.due_date, to_date('1970-01-01','YYYY-MM-DD')) DESC" 
		}
		"Posting" { 
			set order_by_clause "order by t.posting_date" 
			set order_by_clause_ext "order by posting_date" 
		}
		"Own" { 
			set order_by_clause "order by upper(im_initials_from_user_id(t.owner_id))" 
			set order_by_clause_ext "order by upper(owner_initials)" 
		}
		"Ass" { 
			set order_by_clause "order by upper(im_initials_from_user_id(t.asignee_id))" 
			set order_by_clause_ext "order by upper(asignee_initials)" 
		}
		"Object" { 
			set order_by_clause "order by upper(acs_object__name(t.object_id))" 
			set order_by_clause_ext "order by upper(object_name)" 
		}
		"Status" { 
			set order_by_clause "order by upper(im_category_from_id(t.topic_status_id))" 
			set order_by_clause_ext "order by upper(topic_status)" 
		}
		"Read" { 
			set order_by_clause "order by upper(m.read_p)" 
			set order_by_clause_ext "order by upper(read_p)" 
		}
		"Folder" { 
			set order_by_clause "order by upper(f.folder_name)" 
			set order_by_clause_ext "order by upper(folder_name)" 
		}		
    	}
	
	
    	set restrictions []
    	if {0 != $forum_object_id} {
	    lappend restrictions "t.object_id=:forum_object_id" 
    	}
    	if {[string equal "t" $restrict_to_mine_p]} {
	    lappend restrictions "(owner_id=:user_id or asignee_id=:user_id)" 
    	}

    	if {"" != $forum_start_date} {
	    lappend restrictions "posting_date >= :forum_start_date::date" 
    	}
    	if {"" != $forum_end_date} {
	    lappend restrictions "posting_date <= :forum_end_date::date" 
    	}

    	if {$restrict_to_topic_status_id} {
	    lappend restrictions "topic_status_id=:restrict_to_topic_status_id" 
    	}
    	if {$restrict_to_asignee_id} {
	    lappend restrictions "asignee_id=:restrict_to_asignee_id" 
    	}
    	if {$restrict_to_new_topics} {
	    lappend restrictions "(m.read_p is null or m.read_p='f')" 
	    lappend restrictions "topic_status_id not in ([im_topic_status_id_closed],[im_topic_status_id_rejected])"
	    lappend restrictions "topic_type_id != [im_topic_type_id_reply]"
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
		    # folder_id = 1 means deleted
		    lappend restrictions "(t.topic_status_id != [im_topic_status_id_closed] and
		        m.folder_id != '1' and
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
    	if {$debug} { ns_log Notice "im_forum_component: restriction_clause=$restriction_clause" }

	
	# Permissions - who should see what
	set permission_clause "
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
	)"
	# We only want to remove the permission clause if the
	# user is allowed to see all items
	if {[im_permission $user_id view_topics_all]} {
	    set permission_clause ""
	}


	# Get the list of biz object URLs to avoid a SQL join
	set biz_url_sql "
		select	object_type,
			url
		from	im_biz_object_urls 
		where	url_type='view'
	"
	set biz_url_list [util_memoize [list db_list_of_lists biz_url $biz_url_sql]]
	foreach biz_url_row $biz_url_list {
	    set object_type [lindex $biz_url_row 0]
	    set url [lindex $biz_url_row 1]
	    set biz_url_hash($object_type) $url
	}

    	# Get the forum_sql statement
    	# Forum items have a complicated "scoped" permission 
    	# system where you can say who should be able to read
    	# the topic in function of the project/company/...
    	# membership.
    	# Also, items can be attached to all kinds of objects,
    	# so that we need some object_type meta data
    	# (im_biz_object_urls) to build correct URLs to link
    	# to these items.
    	# Finally we can have "read" and "unread" items and
    	# Items that have been filed in a specific "folder".
    	# So we are getting close here to a kind of MS-Outlook...
	
    	set forum_statement [db_qd_get_fullname "forum_query" 0]
    	set forum_sql_uneval [db_qd_replace_sql $forum_statement {}]
    	set forum_sql [expr "\"$forum_sql_uneval\""]
	
    	# ---------------------- Limit query to MAX rows -------------------------
    	
    	# We can't get around counting in advance if we want to be able to
    	# sort inside the table on the page for only those rows in the query 
    	# results
    	
    	set limited_query [im_select_row_range $forum_sql $start_idx [expr $start_idx + $max_entries_per_page]]
    	set total_in_limited_sql "select count(*) from ($forum_sql) f"
    	set total_in_limited [db_string total_limited $total_in_limited_sql]
    	set selection "select z.* from ($limited_query) z $order_by_clause_ext"
	
    	# How many items remain unseen?
    	set remaining_items [expr $total_in_limited - $start_idx - $max_entries_per_page]
    	if {$debug} { ns_log Notice "im_forum_component: total_in_limited=$total_in_limited, remaining_items=$remaining_items" }
	
    	# ---------------------- Format the body -------------------------------
	
    	set table_body_html ""
    	set ctr 0
    	set idx $start_idx
    	set old_object_id 0
	
    	db_foreach forum_query_limited $selection {

	    regsub -all " " $topic_status "_" topic_status_subs
	    set topic_status [lang::message::lookup "" intranet-forum.$topic_status_subs $topic_status]

	    set object_view_url ""
	    if {[info exists biz_url_hash($object_type)]} { set object_view_url $biz_url_hash($object_type)}

	    set due_date "<nobr>$due_date_pretty</nobr>"

    	    if {$read_p == "t"} {
		set read [lang::message::lookup "" intranet-forum.Topic_read "read"]
	    } else {
		set read [lang::message::lookup "" intranet-forum.Topic_unread "unread"]
	    }
    	    if {$folder_id == ""} {set folder_name Inbox }
	    regsub -all " " $folder_name "_" folder_name_subs
	    set folder_name [lang::message::lookup "" intranet-forum.$folder_name_subs $folder_name]

	    if {0 == $asignee_id} { 
	    	set asignee_id "" 
	    	set asignee_initials "" 
	    } else {
		set asignee_initials [im_name_from_user_id $asignee_id]
	    }

	    set owner_initials [im_name_from_user_id $owner_id]

    	    # insert intermediate headers for every project
    	    if {[string equal "Project" $forum_order_by]} {
    	        if {$old_object_id != $object_id} {
    	            append table_body_html "
    	            <tr><td colspan=$colspan>&nbsp;</td></tr>
    	            <tr><td class=rowtitle colspan=$colspan>
    	              <A href=/intranet/projects/view?project_id=$object_id>
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
		[_ intranet-forum.lt_There_are_no_active_i]
		</b></td></tr>"
    	}
   	
        if { $ctr == $max_entries_per_page && $end_idx < [expr $total_in_limited - 1] } {
		# This means that there are rows that we decided not to return
		# Include a link to go to the next page
		set next_start_idx [expr $end_idx + 1]
		set forum_max_entries_per_page $max_entries_per_page
		set next_page_url  "$current_page_url?[export_url_vars forum_object_id forum_max_entries_per_page forum_order_by]&forum_start_idx=$next_start_idx&$pass_through_vars_html"
		set next_page_html "($remaining_items more) <A href=\"$next_page_url\">&gt;&gt;</a>"
        } else {
		set next_page_html ""
        }

       if { $start_idx > 0 } {
   		# This means we didn't start with the first row - there is
		# at least 1 previous row. add a previous page link
		set previous_start_idx [expr $start_idx - $max_entries_per_page]
		if { $previous_start_idx < 0 } { set previous_start_idx 0 }
		set previous_page_html "<A href=$current_page_url?$pass_through_vars_html&forum_order_by=$forum_order_by&forum_start_idx=$previous_start_idx>&lt;&lt;</a>"
       } else {
 		set previous_page_html ""
       }

    } else {
    	set table_body_html "
			<tr><td colspan=$colspan align=center><b>
			[_ intranet-forum.lt_There_are_no_active_i]
		</b></td></tr>"
	set next_page_html ""
	set previous_page_html ""
	set ctr 0
    }
    # end else user_id != "0"	



    # ---------------------- Format the action bar at the bottom ------------

    set table_footer "
<tr>
  <td $bgcolor([expr $ctr % 2]) colspan=$colspan align=right>
    $previous_page_html
    $next_page_html
    <select name=action>
	<option value=mark_as_read>[_ intranet-forum.Mark_as_read]</option>
	<option value=mark_as_unread>[_ intranet-forum.Mark_as_unread]</option>
	<option value=move_to_deleted>[_ intranet-forum.Move_to_Deleted]</option>
	<option value=move_to_inbox>[_ intranet-forum.Move_to_Active]</option>
	<option value=task_accept>[lang::message::lookup "" intranet-forum.Accept_Tasks "Accept Tasks"]</option>
	<option value=task_reject>[lang::message::lookup "" intranet-forum.Reject_Tasks "Reject Tasks"]</option>
	<option value=task_close>[lang::message::lookup "" intranet-forum.Close_Tasks "Close Tasks"]</option>
    </select>
    <input type=submit name=submit value='[_ intranet-forum.Apply]'>
  </td>
</tr>"

    # ---------------------- Join all parts together ------------------------
    set component_html "

<form action=/intranet-forum/forum-action method=POST>
[export_form_vars object_id return_url]
<table class=table_list_page>
  $table_header_html
  $table_body_html
  $table_footer
</table>
</form>\n"

    return $component_html
}





# ----------------------------------------------------------------------
# Component with discussions designed to appear directly in a ProjectViewPage
# ----------------------------------------------------------------------

ad_proc -public im_forum_full_screen_component {
    -object_id:required
    { -read_only_p 0}
} {
    Creates a HTML table with the threaded discussions for a given object.
} {
    set user_id [ad_get_user_id]
    set todays_date [lindex [split [ns_localsqltimestamp] " "] 0]
    set bgcolor(0) " class=roweven"
    set bgcolor(1) " class=rowodd"
    set date_format "YYYY-MM-DD"
    set return_url [im_url_with_query]

    set topic_id [db_string tid "select min(topic_id) from im_forum_topics where object_id = :object_id" -default ""]
    if {"" == $topic_id} { return "" }

    set object_admin 0
    set object_admins [im_biz_object_admin_ids $object_id]
    if {[lsearch $object_admins $user_id] > -1} { set object_admin 1}

    # ------------------------------------------------------------------
    # Get the message details

    set action_type "edit_message"
    set topic_sql "
	select	t.*,
		to_char(t.due_date, :date_format) as due_date,
		to_char(t.posting_date, :date_format) as posting_date,
		m.read_p,
		m.folder_id,
		m.receive_updates,
		im_category_from_id(t.topic_status_id) as topic_status,
		im_category_from_id(t.topic_type_id) as topic_type,
		im_name_from_user_id(t.owner_id) as owner_name,
		im_name_from_user_id(t.asignee_id) as asignee_name,
		acs_object__name(t.object_id) as object_name
	from
		im_forum_topics t
		LEFT JOIN (
			select	* 
			from	im_forum_topic_user_map 
			where	user_id=:user_id
		) m USING (topic_id)
	where
		t.topic_id = :topic_id
    "
    db_1row get_topic $topic_sql
    if {$due_date == ""} { set due_date $todays_date }
    set old_asignee_id $asignee_id

    
    # Only incidents and tasks have priority, status, asignees and due_dates
    #
    set task_or_incident_p [im_forum_is_task_or_incident $topic_type_id]
    set ctr 1

    # ------------------------------------------------------------------
    # Render the message
    append table_body [im_forum_render_tind $topic_id $parent_id $topic_type_id $topic_type $topic_status_id $topic_status $owner_id $asignee_id $owner_name $asignee_name $user_id $object_id $object_name $object_admin $subject $message $posting_date $due_date $priority $scope $receive_updates $return_url]

    set actions ""

    if {$task_or_incident_p && $user_id == $asignee_id} {
	# Add Accept/Reject for "assigned" tasks
	if {$topic_status_id == [im_topic_status_id_assigned]} {
	    # Asignee has not "accepted" yet
	    append actions "<option value=accept>[_ intranet-forum.Accept_topic_type]</option>\n"
	    append actions "<option value=reject>[_ intranet-forum.Reject_topic_type]</option>\n"
	}
	
	# Allow to mark task as "closed" only after accepted
	# 061114 fraber: Not anymore - really a hassle
	if {![string equal $topic_status_id [im_topic_status_id_closed]]} {
	    append actions "<option value=close>[_ intranet-forum.Close_topic_type]</option>\n"
	}
	
	# Always allow to ask for clarification from owner if not already in clarify
	if {![string equal $topic_status_id [im_topic_status_id_needs_clarify]] && ![string equal $topic_status_id [im_topic_status_id_closed]]} {
	    append actions "<option value=clarify>[_ intranet-forum.lt_topic_type_needs_clar]</option>\n"
	}
    }
    
    append actions "<option value=reply selected>[_ intranet-forum.lt_Reply_to_this_topic_t]</option>\n"
    
    # Only admins can edit the message
    set assign_hidden ""
    if {$object_admin || $user_id==$owner_id} {
	append actions "<option value=edit>[_ intranet-forum.Edit_topic_type]</option>\n"
	if {$task_or_incident_p && $topic_status_id == [im_topic_status_id_needs_clarify]} {
	    append actions "<option value=assign>[_ intranet-forum.Re_assign_topic]</option>\n"
	    #assignee does not change
	    set assign_hidden "<input type=hidden name=asignee_id value=$asignee_id>"
	}
	# owner can also close topic
	if {$user_id != $asignee_id && ![string equal $topic_status_id [im_topic_status_id_closed]]} {
	    append actions "<option value=close>[_ intranet-forum.Close_topic_type]</option>\n"
	}
    }
    
    if {!$read_only_p} {
	append table_body "
		<tr $bgcolor([expr $ctr % 2])>
		  <td>[_ intranet-forum.Actions]</td>
		  <td>
		    <select name=actions>
		    $actions
		    </select>
		    <input type=submit value=\"[_ intranet-forum.Apply]\">
		  </td>
		</tr> 
		$assign_hidden
        "
    }
    incr ctr

    # -------------- Table and Form Start -----------------------------
    set thread_html [im_forum_render_thread $topic_id $user_id $object_id $object_name $object_admin $return_url]

    set page_body "
	<form action='/intranet-forum/new-2' method=POST>
	[export_form_vars action_type owner_id old_asignee_id object_id topic_id parent_id subject message return_url topic_status_id topic_type_id]
	<table cellspacing=1 border=0 cellpadding=1>
	$table_body
	</table>
	</form>
	$thread_html
    "
    return $page_body
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
<table cellpadding=0 cellspacing=0 border=0 class='forumBar'>
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

    set active_topics [im_navbar_tab "index" [_ intranet-forum.Inbox] [string equal $section "Inbox"]]
    set deleted_topics [im_navbar_tab "index?forum_folder=1" [_ intranet-forum.Deleted] [string equal $section "Deleted"]]
    set unresolved_topics [im_navbar_tab "index?forum_folder=2" [_ intranet-forum.Unresolved] [string equal $section "Unresolved"]]
    set discussion_view [im_navbar_tab "index?forum_view_name=forum_list_discussion" [_ intranet-forum.Discussion_View] [string equal $section "Discussion View"]]
    set history [im_navbar_tab "index?forum_view_name=forum_list_history" [_ intranet-forum.History] [string equal $section "History"]]

    # $discussion_view $history

    return "
         <div id=\"navbar_sub_wrapper\">
            <ul id=\"navbar_sub\">
    	       $active_topics
	       $deleted_topics
	       $unresolved_topics
            </ul>
         </div>"
}


