-- /packages/intranet-forum/sql/oracle/intranet-forum-create.sql
--
-- Copyright (c) 2003-2004 Project/Open
--
-- All rights reserved. Please check
-- http://www.project-open.com/license/ for details.
--
-- @author frank.bergmann@project-open.com

-----------------------------------------------------------
-- Tasks, Incidents, News and Discussions (TIND)
--
-- A simplified version of the ACS BBOARD module,
-- related to groups (project, customers, ...).
-- The idea is to provide project members with a
-- unified communication medium.

-----------------------------------------------------------
-- Topics
--

create sequence im_forum_topics_seq start with 1;
create table im_forum_topics (
	-- administrative information
	topic_id	integer
			constraint im_forum_topics_pk primary key,
	topic_name	varchar(200),
	topic_path	varchar(200),
	object_id	integer not null 
			constraint im_forum_topics_object_fk
			references acs_objects,
	parent_id	integer
			constraint im_forum_topics_parent_fk
			references im_forum_topics,
	topic_type_id	integer not null
			constraint im_forum_topics_type_fk
			references im_categories,
	topic_status_id	integer
			constraint im_forum_topics_status_fk
			references im_categories,
	posting_date	date default sysdate,
	owner_id	integer not null
			constraint im_forum_topics_owner_fk
			references users,
	scope		varchar(20) default 'group'
			constraint im_forum_topics_scope_ck
			check (scope in ('pm', 'group','public','client','staff','not_client')),
	-- message content
	subject		varchar(200) not null,
	message		clob,
	-- task and incident specific fields
	priority	number(1) default 5,
	due_date	date default sysdate,
	asignee_id	integer
			constraint im_forum_topics_asignee_fk
			references users
);
create index im_forum_topics_object_idx on im_forum_topics (object_id);


-- A function that decides whether a specific user can see a
-- forum item or not. Take into account permformance because
-- it's going to be a huge number of topics and take into
-- account a flexible role-based permission scheme
--
create or replace function im_forum_permission (
	p_user_id		integer,
	p_owner_id		integer,
	p_asignee_id		integer,
	p_object_id		integer,
	p_scope			varchar,
	p_user_is_object_member	integer,
	p_user_is_object_admin	integer,
	p_user_is_employee	integer,
	p_user_is_customer	integer	
) RETURN integer 
IS
	v_permission_p		integer;
BEGIN
	IF p_user_id = p_owner_id THEN		RETURN 1;	END IF;
	IF p_asignee_id = p_user_id THEN	RETURN 1;	END IF;
	IF p_scope = 'public' THEN		RETURN 1;	END IF;
	IF p_scope = 'group' THEN		RETURN p_user_is_object_member;	END IF;
	IF p_scope = 'pm' THEN			RETURN p_user_is_object_admin;	END IF;

	IF p_scope = 'client' AND p_user_is_customer = 1 THEN	
		RETURN p_user_is_object_member;
	END IF;
	IF p_scope = 'staff' AND p_user_is_employee = 1 THEN	
		RETURN p_user_is_object_member;	
	END IF;
	RETURN 0;
END im_forum_permission;
/
show errors;


-----------------------------------------------------------
-- Folders for Intranet users
--
-- folder_id in (0 or NULL) indicates "Inbox" items
-- folder_id = 1 indicates "Deleted" items
-- folder_id < 10 is reserved for system folders (user_id=NULL)
-- folder_id for users start with 10

create table im_forum_folders (
	folder_id	integer
			constraint im_forum_folders_pk
			primary key,
	user_id		integer
			constraint im_forum_folders_user_fk
			references users,
	parent_id	integer
			constraint im_forum_folders_parent_fk
			references im_forum_folders,
	folder_name	varchar(200)
);


-----------------------------------------------------------
-- Map between topics and users:
-- Remembers the interaction between a user and a topic.
--
-- Please note that this map is outer-joined with every
-- im_forum_topics "select", leading to many NULL values,
-- becuase this topic-user-map is not defined. So NULL
-- values have to be considered "default".

create table im_forum_topic_user_map (
	topic_id	integer
			constraint im_forum_topics_um_topic_fk
			references im_forum_topics,
	user_id		integer
			constraint im_forum_topics_um_user_fk
			references users,
	-- read_p in ('f' or NULL) indicates "New" items
	read_p		char(1) default 't'
			constraint im_forum_topics_um_read_ck
			check (read_p in ('t','f')),
	-- folder_id in (0 or NULL) indicates "Inbox" items
	-- folder_id = 1 indicates "Deleted" items
	-- folder_id for users start with 10
	folder_id	integer default 0
			constraint im_forum_topics_um_folder_fk
			references im_forum_folders,
	receive_updates	varchar(20) default 'major'
			constraint im_forum_topics_um_rec_ck check (
			receive_updates in ('all','none','major')),
	constraint im_forum_topics_um_rec_pk
	primary key (topic_id, user_id)
);

-----------------------------------------------------------
-- Uploaded Files
--

create sequence im_forum_files_seq start with 1;
create table im_forum_files (
	msg_id			integer 
				constraint im_forum_files_pk
				primary key,
	n_bytes			integer,
	client_filename		varchar(4000),
	filename_stub		varchar(200),
	caption			varchar(200),
	content			clob
);


-----------------------------------------------------------
-- Setup the default folders
--
-- folder_id in (0 or NULL) indicates "Inbox" items
-- folder_id = 1 indicates "Deleted" items
-- folder_id for users start with 10


insert into im_forum_folders values (0, null, null, 'Inbox');
insert into im_forum_folders values (1, null, null, 'Deleted');
insert into im_forum_folders values (2, null, null, 'Sys2');
insert into im_forum_folders values (3, null, null, 'Sys3');
insert into im_forum_folders values (4, null, null, 'Sys4');
insert into im_forum_folders values (5, null, null, 'Sys5');
insert into im_forum_folders values (6, null, null, 'Sys6');
insert into im_forum_folders values (7, null, null, 'Sys7');
insert into im_forum_folders values (8, null, null, 'Sys8');
insert into im_forum_folders values (9, null, null, 'Sys9');


-- Forum Topic Types
delete from im_categories where category_type = 'Intranet Topic Type';

INSERT INTO im_categories VALUES (1100,'News',
'News item that may or may not be commented.',
'Intranet Topic Type','category','t','f');

INSERT INTO im_categories VALUES (1102,'Incident',
'Critical task that needs rapid resolution',
'Intranet Topic Type','category','t','f');

INSERT INTO im_categories VALUES (1104,'Task',
'Task that needs to be performed',
'Intranet Topic Type','category','t','f');

INSERT INTO im_categories VALUES (1106,'Discussion',
'Request for response/interaction',
'Intranet Topic Type','category','t','f');

INSERT INTO im_categories VALUES (1108,'Note',
'Calling attention about something',
'Intranet Topic Type','category','t','f');

INSERT INTO im_categories VALUES (1110,'Help Request',
'Help Request','Intranet Topic Type','category','t','f');

INSERT INTO im_categories VALUES (1190,'Reply',
'Reply','Intranet Topic Type','category','t','f');

commit;
-- reserved until 1199


create or replace view im_forum_topic_types as 
select 
	category_id as topic_type_id, 
	category as topic_type
from im_categories 
where category_type = 'Intranet Topic Type';






-------------------------------------------------------------
-- Privileges
--
-- Privileges are permission tokens relative to the "subsite"
-- (package) object "Project/Open Core".
--
prompt *** Creating Privileges
begin
    acs_privilege.create_privilege('add_topic_public','Add global messages','');
    acs_privilege.create_privilege('add_topic_group','Add essages for the entire (project) group','');
    acs_privilege.create_privilege('add_topic_staff','Messages to staff members of the group','');
    acs_privilege.create_privilege('add_topic_client','Messages to the clients of the group','');
    acs_privilege.create_privilege('add_topic_noncli','Message to non-clients of the group','');
    acs_privilege.create_privilege('add_topic_pm','Message to the project manager only','');
end;
/


------------------------------------------------------
-- Add Topic PM
---
BEGIN
    im_priv_create('add_topic_pm',        'Accounting');
END;
/
BEGIN
    im_priv_create('add_topic_pm',        'Customers');
END;
/
BEGIN
    im_priv_create('add_topic_pm',        'Employees');
END;
/
BEGIN
    im_priv_create('add_topic_pm',        'Freelancers');
END;
/
BEGIN
    im_priv_create('add_topic_pm',        'P/O Admins');
END;
/
BEGIN
    im_priv_create('add_topic_pm',        'Project Managers');
END;
/
BEGIN
    im_priv_create('add_topic_pm',        'Sales');
END;
/
BEGIN
    im_priv_create('add_topic_pm',        'Senior Managers');
END;
/



------------------------------------------------------
-- Add Topic Client
---
BEGIN
    im_priv_create('add_topic_client',        'Accounting');
END;
/
BEGIN
    im_priv_create('add_topic_client',        'P/O Admins');
END;
/
BEGIN
    im_priv_create('add_topic_client',        'Sales');
END;
/
BEGIN
    im_priv_create('add_topic_client',        'Senior Managers');
END;
/


------------------------------------------------------
-- Add Topic Public
---
BEGIN
    im_priv_create('add_topic_public',        'P/O Admins');
END;
/
BEGIN
    im_priv_create('add_topic_public',        'Senior Managers');
END;
/



------------------------------------------------------
-- Add Topic Non-Clients
---
BEGIN
    im_priv_create('add_topic_noncli',        'Accounting');
END;
/
BEGIN
    im_priv_create('add_topic_noncli',        'Employees');
END;
/
BEGIN
    im_priv_create('add_topic_noncli',        'Freelancers');
END;
/
BEGIN
    im_priv_create('add_topic_noncli',        'P/O Admins');
END;
/
BEGIN
    im_priv_create('add_topic_noncli',        'Project Managers');
END;
/
BEGIN
    im_priv_create('add_topic_noncli',        'Sales');
END;
/
BEGIN
    im_priv_create('add_topic_noncli',        'Senior Managers');
END;
/


------------------------------------------------------
-- Add Topic Groups
---
BEGIN
    im_priv_create('add_topic_group',        'Accounting');
END;
/
BEGIN
    im_priv_create('add_topic_group',        'P/O Admins');
END;
/
BEGIN
    im_priv_create('add_topic_group',        'Sales');
END;
/
BEGIN
    im_priv_create('add_topic_group',        'Senior Managers');
END;
/



------------------------------------------------------
-- Add Topic Public
---
BEGIN
    im_priv_create('add_topic_client',        'P/O Admins');
END;
/
BEGIN
    im_priv_create('add_topic_client',        'Senior Managers');
END;
/



------------------------------------------------------
-- Add Topic Staff
---
BEGIN
    im_priv_create('add_topic_staff',        'Accounting');
END;
/
BEGIN
    im_priv_create('add_topic_staff',        'Employees');
END;
/
BEGIN
    im_priv_create('add_topic_staff',        'Freelancers');
END;
/
BEGIN
    im_priv_create('add_topic_staff',        'P/O Admins');
END;
/
BEGIN
    im_priv_create('add_topic_staff',        'Project Managers');
END;
/
BEGIN
    im_priv_create('add_topic_staff',        'Sales');
END;
/
BEGIN
    im_priv_create('add_topic_staff',        'Senior Managers');
END;
/




---------------------------------------------------------
-- Register the component in the core TCL pages
--
-- These DB-entries allow the pages of Project/Open Core
-- to render the forum components in the Home, Users, Projects 
-- and Customer pages.
--
-- The TCL code in the "component_tcl" field is executed
-- via "im_component_bay" in an "uplevel" statemente, exactly
-- as if it would be written inside the .adp <%= ... %> tag.
-- I know that's relatively dirty, but TCL doesn't provide
-- another way of "late binding of component" ...


-- delete potentially existing menus and plugins if this 
-- file is sourced multiple times during development...

BEGIN
    im_component_plugin.del_module(module_name => 'intranet-forum');
    im_menu.del_module(module_name => 'intranet-forum');
END;
/
show errors
commit;

-- Setup the "Forum" main menu entry
--
declare
        -- Menu IDs
        v_menu                  integer;
	v_main_menu		integer;

        -- Groups
        v_employees             integer;
        v_accounting            integer;
        v_senman                integer;
        v_customers             integer;
        v_freelancers           integer;
        v_proman                integer;
        v_admins                integer;
begin

    select group_id into v_admins from groups where group_name = 'P/O Admins';
    select group_id into v_senman from groups where group_name = 'Senior Managers';
    select group_id into v_proman from groups where group_name = 'Project Managers';
    select group_id into v_accounting from groups where group_name = 'Accounting';
    select group_id into v_employees from groups where group_name = 'Employees';
    select group_id into v_customers from groups where group_name = 'Customers';
    select group_id into v_freelancers from groups where group_name = 'Freelancers';

    select menu_id
    into v_main_menu
    from im_menus
    where label='main';

    v_menu := im_menu.new (
	package_name =>	'intranet-forum',
	label =>	'forum',
	name =>		'Forum',
	url =>		'/intranet-forum/',
	sort_order =>	20,
	parent_menu_id => v_main_menu
    );

    acs_permission.grant_permission(v_menu, v_admins, 'read');
    acs_permission.grant_permission(v_menu, v_senman, 'read');
    acs_permission.grant_permission(v_menu, v_proman, 'read');
    acs_permission.grant_permission(v_menu, v_accounting, 'read');
    acs_permission.grant_permission(v_menu, v_employees, 'read');
    acs_permission.grant_permission(v_menu, v_customers, 'read');
    acs_permission.grant_permission(v_menu, v_freelancers, 'read');
end;
/
commit;
	

-- Show the forum component in project page
--
declare
    v_plugin            integer;
begin
    v_plugin := im_component_plugin.new (
	plugin_name =>	'Project Forum Component',
	package_name =>	'intranet-forum',
        page_url =>     '/intranet/projects/view',
        location =>     'right',
        sort_order =>   10,
        component_tcl => 
	'im_table_with_title \
		[im_forum_create_bar \
			"<B>Forum Items<B>" \
			$project_id \
			$return_url \
		] \
		[im_forum_component \
			-user_id $user_id \
			-object_id $project_id \
			-current_page_url $current_url \
			-return_url $return_url \
			-export_var_list [list \
				project_id \
				forum_start_idx \
				forum_order_by \
				forum_how_many \
				forum_view_name \
			] \
			-how_many 10 \
			-forum_type project \
			-view_name [im_opt_val forum_view_name] \
			-forum_order_by [im_opt_val forum_order_by] \
			-restrict_to_mine_p "f" \
			-restrict_to_new_topics 1 
		]'
    );
end;
/
show errors

commit;


-- Show the forum component in customer page
--
declare
    v_plugin            integer;
begin
    v_plugin := im_component_plugin.new (
	plugin_name =>	'Customers Forum Component',
	package_name =>	'intranet-forum',
        page_url =>     '/intranet/customers/view',
        location =>     'right',
        sort_order =>   10,
        component_tcl => 
	'im_table_with_title \
		[im_forum_create_bar \
			"<B>Forum Items<B>" \
			$customer_id \
			$return_url \
		] \
		[im_forum_component \
			-user_id $user_id \
			-object_id $customer_id \
			-current_page_url $current_url \
			-return_url $return_url \
			-export_var_list [list \
				customer_id \
				forum_start_idx \
				forum_order_by \
				forum_how_many \
				forum_view_name \
			] \
			-how_many 10 \
			-forum_type customer \
			-view_name [im_opt_val forum_view_name] \
			-forum_order_by [im_opt_val forum_order_by] \
			-restrict_to_mine_p "f" \
			-restrict_to_new_topics 1 \
			-restrict_to_employees 1 \
		]'
    );
end;
/
commit;


-- Show the forum component in users page
--
declare
    v_plugin            integer;
begin
    v_plugin := im_component_plugin.new (
	plugin_name =>	'User Forum Component',
	package_name =>	'intranet-forum',
        page_url =>     '/intranet/users/view',
        location =>     'right',
        sort_order =>   20,
        component_tcl => 
	'im_table_with_title \
		[im_forum_create_bar \
			"<B>Forum Items<B>" \
			$user_id \
			$return_url \
		] \
		[im_forum_component \
			-user_id $current_user_id \
			-object_id $user_id \
			-current_page_url $current_url \
			-return_url $return_url \
			-export_var_list [list \
				user_id \
				forum_start_idx \
				forum_order_by \
				forum_how_many \
				forum_view_name \
			] \
			-how_many 10 \
			-forum_type user \
			-view_name [im_opt_val forum_view_name] \
			-forum_order_by [im_opt_val forum_order_by] \
			-restrict_to_mine_p "f" \
			-restrict_to_new_topics 0 \
			-restrict_to_employees 1 \
		]'
    );
end;
/
commit;


-- Show the forum component in home page
--
declare
    v_plugin            integer;
begin
    v_plugin := im_component_plugin.new (
	plugin_name =>	'Home Forum Component',
	package_name =>	'intranet-forum',
        page_url =>     '/intranet/index',
        location =>     'right',
        sort_order =>   10,
        component_tcl => 
	'im_table_with_title \
		[im_forum_create_bar \
			"<B>Forum Items<B>" \
			0 \
			$return_url \
		] \
		[im_forum_component \
			-user_id $user_id \
			-object_id 0 \
			-current_page_url $current_url \
			-return_url $return_url \
			-export_var_list [list \
				forum_start_idx \
				forum_order_by \
				forum_how_many \
				forum_view_name \
			] \
			-how_many 10 \
			-forum_type home \
			-view_name [im_opt_val forum_view_name] \
			-forum_order_by [im_opt_val forum_order_by] \
			-restrict_to_mine_p t \
			-restrict_to_new_topics 1
		]'
    );
end;
/
show errors

commit;


-- Intranet Topic Status
delete from im_categories where category_type = 'Intranet Topic Status';

INSERT INTO im_categories VALUES (1200,'Open',
'A topic has been generated, but is not assigned to anybody (discussion, ...)',
'Intranet Topic Status','category','t','f');

INSERT INTO im_categories VALUES (1202,'Assigned',
'A task has been assigned to someone, but this person has not confirmed yet.',
'Intranet Topic Status','category','t','f');

INSERT INTO im_categories VALUES (1204,'Accepted',
'The asignee has confirmed that he will be responsible for the task',
'Intranet Topic Status','category','t','f');

INSERT INTO im_categories VALUES (1206,'Rejected',
'The asignee has rejected to take responsability for the task',
'Intranet Topic Status','category','t','f');

INSERT INTO im_categories VALUES (1208,'Needs Clarify',
'The asignee passes the task back to the owner for clarification',
'Intranet Topic Status','category','t','f');

INSERT INTO im_categories VALUES (1210,'Closed',
'The owner has canceled the task or the asignee has finished the task',
'Intranet Topic Status','category','t','f');

commit;
-- reserved until 1299


create or replace view im_forum_topic_status as 
select 	category_id as topic_type_id, 
	category as topic_type
from im_categories 
where category_type = 'Intranet Topic Status';
	

create or replace view im_forum_topic_status_active as 
select 	category_id as topic_type_id, 
	category as topic_type
from im_categories 
where	category_type = 'Intranet Topic Status'
	and category_id not in (1202, 1204, 1206);



-- views to "forum" items: 40-49
insert into im_views (view_id, view_name, visible_for) values (40, 'forum_list_home', 'view_forums');
insert into im_views (view_id, view_name, visible_for) values (41, 'forum_list_project', 'view_forums');
insert into im_views (view_id, view_name, visible_for) values (42, 'forum_list_forum', 'view_forums');
insert into im_views (view_id, view_name, visible_for) values (43, 'forum_list_extended', 'view_forums');
insert into im_views (view_id, view_name, visible_for) values (44, 'forum_list_short', 'view_forums');
insert into im_views (view_id, view_name, visible_for) values (45, 'forum_list_customer', 'view_forums');


-- ForumList for home page
--
delete from im_view_columns where column_id >= 4000 and column_id < 4099;
insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (4000,40,NULL,'P',
'$priority','','',2,'');

insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (4002,40,NULL,'Type',
'"<a href=/intranet-forum/view?[export_url_vars topic_id return_url]>\
[im_gif $topic_type]</a>"',
'','',4,'');

insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (4003,40,NULL,'Object',
'"<a href=$object_view_url$object_id>$object_name</a>"',
'','',5,'');

insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (4004,40,NULL,'Subject',
'"<a href=/intranet-forum/view?[export_url_vars topic_id return_url]>\
$subject</a>"','','',6,'');

insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (4006,40,NULL,'Due',
'$due_date','','',8,'');

insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (4010,40,NULL,
'"[im_gif help "Select topics here for processing"]"',
'"<input type=checkbox name=topic_id.$topic_id>"',
'','',12,'');

commit;



-- ForumList for ProjectViewPage or CustomerViewPage
--
delete from im_view_columns where column_id >= 4100 and column_id < 4199;
insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (4100,41,NULL,'P',
'$priority','','',2,'');

insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (4102,41,NULL,'Type',
'"<a href=/intranet-forum/view?[export_url_vars topic_id return_url]>\
[im_gif $topic_type]</a>"',
'','',4,'');

insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (4104,41,NULL,'Subject',
'"<a href=/intranet-forum/view?[export_url_vars topic_id return_url]>\
$subject</a>"','','',6,'');

insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (4106,41,NULL,'Due',
'$due_date','','',8,'');

insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (4107,41,NULL,'Own',
'"<a href=/intranet/users/view?user_id=$owner_id>$owner_initials</a>"',
'','',9,'');

insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (4108,41,NULL,'Ass',
'"<a href=/intranet/users/view?user_id=$asignee_id>$asignee_initials</a>"',
'','',10,'');

insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (4110,41,NULL,
'"[im_gif help "Select topics here for processing"]"',
'"<input type=checkbox name=topic_id.$topic_id>"',
'','',12,'');

commit;


-- ForumList for the forum index page (all projects with a lot of space)
--
delete from im_view_columns where column_id >= 4200 and column_id < 4299;
insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (4200,42,NULL,'P',
'$priority','','',2,'');

insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (4201,42,NULL,'Object',
'"<a href=$object_view_url$object_id>$object_name</a>"',
'','',3,'');

insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (4202,42,NULL,'Type',
'"<a href=/intranet-forum/view?[export_url_vars topic_id return_url]>\
[im_gif $topic_type]</a>"',
'','',4,'');

insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (4204,42,NULL,'Subject',
'"<a href=/intranet-forum/view?[export_url_vars topic_id return_url]>\
$subject</A>"','','',6,'');

insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (4206,42,NULL,'Due',
'$due_date','','',8,'');

insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (4207,42,NULL,'Own',
'"<a href=/intranet/users/view?user_id=$owner_id>$owner_initials</a>"',
'','',9,'');

insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (4208,42,NULL,'Ass',
'"<a href=/intranet/users/view?user_id=$asignee_id>$asignee_initials</a>"',
'','',10,'');

insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (4209,42,NULL,'Status',
'$topic_status','','',11,'');

insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (42010,42,NULL,'Read',
'$read','','',12,'');

insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (4210,42,NULL,
'"[im_gif help "Select topics here for processing"]"',
'"<input type=checkbox name=topic_id.$topic_id>"',
'','',13,'');

insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (4212,42,NULL,'Folder',
'$folder_name','','',14,'');

commit;


