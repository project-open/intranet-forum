# /packages/intranet-forum/tcl/intranet-backup-procs.tcl#
#
# Copyright (C) 2003 - 2009 ]project-open[
#
# All rights reserved. Please check
# http://www.project-open.com/license/ for details.

ad_library {
    Definitions for the intranet module

    @author frank.bergmann@project-open.com
}

# -------------------------------------------------------
# Forum_Topics
# -------------------------------------------------------

ad_proc -public im_import_forum_topics { filename } {
    Import the forum_topics file
} {
    set err_return ""
    if {![file readable $filename]} {
	append err_return "Unable to read file '$filename'"
	return $err_return
    }

    set csv_content [exec /bin/cat $filename]
    set csv_lines [split $csv_content "\n"]
    set csv_lines_len [llength $csv_lines]

    # Check whether we accept the specified backup version
    set csv_version_line [lindex $csv_lines 0]
    set csv_version_fields [split $csv_version_line " "]
    set csv_system [lindex $csv_version_fields 0]
    set csv_version [lindex $csv_version_fields 1]
    set csv_table [lindex $csv_version_fields 2]
    set err_msg [im_backup_accepted_version_nr $csv_version]
    if {![string equal $csv_system "po"]} {
	append err_msg "'$csv_system' invalid backup dump<br>"
    }
    if {![string equal $csv_table "im_forum_topics"]} {
	append err_msg "Invalid backup table: '$csv_table'<br>"
    }
    if {"" != $err_msg} {
	append err_return "<li>Error reading '$filename': <br><pre>\n$err_msg</pre>"
	return $err_return
    }

    set csv_header [lindex $csv_lines 1]
    set csv_header_fields [split $csv_header "\""]
    set csv_header_len [llength $csv_header_fields]
    ns_log Notice "csv_header_fields=$csv_header_fields"

    for {set i 2} {$i < $csv_lines_len} {incr i} {

	set csv_line [string trim [lindex $csv_lines $i]]
	set csv_line_fields [split $csv_line "\""]
	ns_log Notice "csv_line_fields=$csv_line_fields"
	if {"" == $csv_line} {
	    ns_log Notice "skipping empty line"
	    continue
	}


	# -------------------------------------------------------
	# Extract variables from the CSV file
	#

	for {set j 0} {$j < $csv_header_len} {incr j} {

	    set var_name [string trim [lindex $csv_header_fields $j]]
	    set var_value [string trim [lindex $csv_line_fields $j]]

	    # Skip empty columns caused by double quote separation
	    if {"" == $var_name || [string equal $var_name ";"]} {
		continue
	    }

	    set cmd "set $var_name \"$var_value\""
	    ns_log Notice "cmd=$cmd"
	    set result [eval $cmd]
	}
	set note [ns_urldecode $note]

	# -------------------------------------------------------
	# Transform email and names into IDs
	#

	set topic_type_id [im_import_get_category $topic_type "Intranet Topic Type" 1108]
	set topic_status_id [im_import_get_category $topic_status "Intranet Topic Status" 1200]
	set parent_id [db_string parent_topic "select topic_id from im_forum_topics where topic_path=:parent_path" -default ""]
	set owner_id [im_import_get_user $owner_email ""]
	set asignee_id [im_import_get_user $asignee_email ""]
	set object_id [im_import_get_parent_topic_id $ref_object_type $ref_object_name]

	set topic_insert_sql "
                insert into im_forum_topics (
                        topic_id, object_id, topic_type_id,
                        topic_status_id, owner_id, subject
                ) values (
                        :topic_id, :object_id, :topic_type_id,
                        :topic_status_id, :owner_id, :subject
                )"

	set topic_update_sql "
		update im_forum_topics set
		        object_id=:object_id,
		        parent_id=:parent_id,
		        topic_type_id=:topic_type_id,
		        topic_status_id=:topic_status_id,
		        posting_date=:today,
		        owner_id=:owner_id,
		        scope=:scope,
		        subject=:subject,
		        message=:message,
		        priority=:priority,
		        asignee_id=:asignee_id,
		        due_date=:due
		where topic_id=:topic_id"

	# -------------------------------------------------------
	# Insert into the DB and deal with errors
	#

	# Check if the forum_topic already exists..
	set exists_p [db_string forum_topic "select count(*) from im_forum_topics where forum_topic_path = :topic_path" -default 0]
	if { [catch {

	    if {!$exists_p} {

		set topic_id [db_nextval "im_forum_topics_seq"]
		set db_dml insert_topic $topic_insert_sql
	    }
	    db_dml topic_update $topic_update_sql
	
	} err_msg] } {
	    ns_log Warning "$err_msg"
	    append err_return "<li>Error loading forum_topics:<br>
	    $csv_line<br><pre>\n$err_msg</pre>"
	}
    }

    return $err_return
}
