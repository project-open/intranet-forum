-- /packages/intranet-hr/sql/oracle/intranet-forum-backup.sql
--
-- Copyright (C) 2004 Project/Open
--
-- This program is free software. You can redistribute it
-- and/or modify it under the terms of the GNU General
-- Public License as published by the Free Software Foundation;
-- either version 2 of the License, or (at your option)
-- any later version. This program is distributed in the
-- hope that it will be useful, but WITHOUT ANY WARRANTY;
-- without even the implied warranty of MERCHANTABILITY or
-- FITNESS FOR A PARTICULAR PURPOSE.
-- See the GNU General Public License for more details.
--
-- @author	frank.bergmann@project-open.com

-- 100	im_projects
-- 101	im_project_roles
-- 102	im_customers
-- 103	im_customer_roles
-- 104	im_offices
-- 105	im_office_roles
-- 106	im_categories
--
-- 110	users
-- 111	im_profiles
-- 115	im_employees
--
-- 120	im_freelancers
--
-- 130	im_forums
--
-- 140	im_filestorage
--
-- 150	im_translation
--
-- 160	im_quality
--
-- 170	im_marketplace
--
-- 180	im_hours
--
-- 190	im_invoices
--
-- 200

---------------------------------------------------------
-- Backup Forum Items
--

delete from im_view_columns where view_id = 130;
delete from im_views where view_id = 130;

insert into im_views (view_id, view_name, view_sql
) values (130, 'im_forum_topics', '
SELECT
	f.*,
	o.object_type,
	acs_object.name(o.object_id) as object_name,
	im_category_from_id(f.topic_type_id) as topic_type,
	im_category_from_id(f.topic_status_id) as topic_status,
	im_email_from_user_id(f.owner_id) as owner_email,
	im_email_from_user_id(f.asignee_id) as asignee_email
FROM
	im_forum_topics f,
	acs_objects o
WHERE
	f.object_id = o.object_id
');


delete from im_view_columns where column_id > 13000 and column_id < 13099;
--
insert into im_view_columns (column_id, view_id, column_name,
column_render_tcl, sort_order)
values (13001,130,'topic_name','$topic_name',1);

insert into im_view_columns (column_id, view_id, column_name,
column_render_tcl, sort_order)
values (13003,130,'topic_path','$topic_id',3);

insert into im_view_columns (column_id, view_id, column_name,
column_render_tcl, sort_order)
values (13005,130,'ref_object_type','$object_type',5);

insert into im_view_columns (column_id, view_id, column_name,
column_render_tcl, sort_order)
values (13007,130,'ref_object_name','[ns_urlencode $object_name]',7);

insert into im_view_columns (column_id, view_id, column_name,
column_render_tcl, sort_order)
values (13009,130,'parent_path','$parent_id',9);

insert into im_view_columns (column_id, view_id, column_name,
column_render_tcl, sort_order)
values (13011,130,'topic_type','$topic_type',11);

insert into im_view_columns (column_id, view_id, column_name,
column_render_tcl, sort_order)
values (13013,130,'topic_status','$topic_status',13);

insert into im_view_columns (column_id, view_id, column_name,
column_render_tcl, sort_order)
values (13014,130,'posting_date','$posting_date',14);

insert into im_view_columns (column_id, view_id, column_name,
column_render_tcl, sort_order)
values (13017,130,'owner_email','$owner_email',17);

insert into im_view_columns (column_id, view_id, column_name,
column_render_tcl, sort_order)
values (13019,130,'scope','$scope',19);

insert into im_view_columns (column_id, view_id, column_name,
column_render_tcl, sort_order)
values (13021,130,'subject','[ns_urlencode $subject]',21);

insert into im_view_columns (column_id, view_id, column_name,
column_render_tcl, sort_order)
values (13023,130,'message','[ns_urlencode $message]',23);

insert into im_view_columns (column_id, view_id, column_name,
column_render_tcl, sort_order)
values (13025,130,'priority','$priority',25);

insert into im_view_columns (column_id, view_id, column_name,
column_render_tcl, sort_order)
values (13027,130,'due_date','$due_date',
27);

insert into im_view_columns (column_id, view_id, column_name,
column_render_tcl, sort_order)
values (13029,130,'asignee_email','$asignee_email',29);

--
commit;


---------------------------------------------------------
-- Backup Forum Topics <-> User Map
--

delete from im_view_columns where view_id = 131;
delete from im_views where view_id = 131;

insert into im_views (view_id, view_name, view_sql) 
values (131, 'im_forum_topic_user_map', '
SELECT
        m.*,
        im_email_from_user_id(m.user_id) as user_email,
	f.folder_name
FROM
        im_forum_topic_user_map m,
	im_forum_folders f
WHERE
        m.folder_id = f.folder_id
');


delete from im_view_columns where column_id > 13100 and column_id < 13199;
--
insert into im_view_columns (column_id, view_id, column_name,
column_render_tcl, sort_order)
values (13101,131,'topic_path','$topic_id',1);

insert into im_view_columns (column_id, view_id, column_name,
column_render_tcl, sort_order)
values (13103,131,'user_email','$user_email',3);

insert into im_view_columns (column_id, view_id, column_name,
column_render_tcl, sort_order)
values (13105,131,'read_p','$read_p',5);

insert into im_view_columns (column_id, view_id, column_name,
column_render_tcl, sort_order)
values (13107,131,'folder_name','$folder_name',7);

insert into im_view_columns (column_id, view_id, column_name,
column_render_tcl, sort_order)
values (13109,131,'receive_updates','$receive_updates',9);


