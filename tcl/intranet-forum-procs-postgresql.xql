<?xml version="1.0"?>
<!DOCTYPE queryset PUBLIC "-//OpenACS//DTD XQL 1.0//EN" "/usr/share/emacs/DTDs/xql.dtd">
<!-- packages/intranet-forum/tcl/intranet-forum-procs-postgresql.xql -->
<!-- @author  (nsadmin@barna.competitiveness.com) -->
<!-- @creation-date 2004-09-14 -->
<!-- @arch-tag 0765ad02-e9d6-4658-bfe1-5d9b62e1b620 -->
<!-- @cvs-id $Id$ -->

<queryset>
  
  
  <rdbms>
    <type>postgresql</type>
    <version>7.2</version>
  </rdbms>

  <fullquery name="im_forum_component.forum_query">
    <querytext>
select
	t.*,
	to_char(t.posting_date, :date_format) as posting_date,
	to_char(t.due_date, :date_format) as due_date_pretty,
	CASE 	WHEN t.due_date < now() and t.topic_type_id in (1102, 1104)
		THEN 1 
		ELSE 0 
	END as overdue,
	t.asignee_id,
	acs_object__name(t.object_id) as object_name,
	m.read_p,
	m.folder_id,
	f.folder_name,
	m.receive_updates,
	im_initials_from_user_id(t.owner_id) as owner_initials,
	im_initials_from_user_id(t.asignee_id) as asignee_initials,
	im_category_from_id(t.topic_type_id) as topic_type,
	im_category_from_id(t.topic_status_id) as topic_status
from
        im_forum_topics t
	LEFT JOIN 
           (select * from im_forum_topic_user_map where user_id=:user_id) m using (topic_id)
	LEFT JOIN 
           im_forum_folders f using (folder_id)
        LEFT JOIN
	(	select 1 as p, 
			object_id_one as object_id 
		from 	acs_rels
		where	object_id_two = :user_id
	) member_objects using (object_id)
        LEFT JOIN
	(	select 1 as p, 
			r.object_id_one as object_id 
		from 	acs_rels r,
			im_biz_object_members m
		where	r.object_id_two = :user_id
			and r.rel_id = m.rel_id
			and m.object_role_id in (1301, 1302, 1303)
	) admin_objects using (object_id),
        acs_objects o
where
        (t.parent_id is null or t.parent_id=0)
        and t.object_id != 1
	and t.object_id = o.object_id
	$permission_clause
	$restriction_clause
$order_by_clause

    </querytext>
  </fullquery>

  <fullquery name="im_forum_render_thread.get_topic">
    <querytext>
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
		children.topic_id,
		children.tree_sortkey,
		tree_level(children.tree_sortkey) -
        tree_level(parent.tree_sortkey) as indent_level
	from
		im_forum_topics parent,	
		im_forum_topics children
	where
		children.tree_sortkey between parent.tree_sortkey and tree_right(parent.tree_sortkey)
		and parent.topic_id = :topic_id
	) tr,
	users ou,
	im_forum_topics t
      LEFT JOIN
	users au ON t.asignee_id=au.user_id
      LEFT JOIN
	im_categories ftc ON t.topic_type_id=ftc.category_id
      LEFT JOIN
	im_categories fts ON t.topic_status_id=fts.category_id
where
	tr.topic_id = t.topic_id
	and t.owner_id=ou.user_id
order by tr.tree_sortkey

    </querytext>
  </fullquery>



</queryset>
