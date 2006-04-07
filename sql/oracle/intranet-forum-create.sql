-- /packages/intranet-forum/sql/oracle/intranet-forum-create.sql
--
-- Copyright (c) 2003-2004 Project/Open
--
-- All rights reserved. Please check
-- http://www.project-open.com/license/ for details.
--
-- @author frank.bergmann@project-open.com
-- @author juanjoruizx@yahoo.es

-----------------------------------------------------------
-- Tasks, Incidents, News and Discussions (TIND)
--
-- A simplified version of the ACS BBOARD module,
-- related to groups (project, companies, ...).
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
	-- Hierarchy of messages
	parent_id	  integer
			  constraint im_forum_topics_parent_fk
			  references im_forum_topics,
	tree_sortkey      raw(240),
	max_child_sortkey raw(100),	
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
			references users,
	constraint im_forums_topic_sk_forum_un
	unique (tree_sortkey, topic_id)
);
create index im_forum_topics_object_idx on im_forum_topics (object_id);

-- This is the sortkey code
--
create or replace trigger im_forum_topic_insert_tr
before insert on im_forum_topics
for each row
declare
    v_max_child_sortkey             im_forum_topics.max_child_sortkey%TYPE;
    v_parent_sortkey                im_forum_topics.tree_sortkey%TYPE;
begin

    if :new.parent_id is null
    then
        :new.tree_sortkey := lpad(tree.int_to_hex(:new.topic_id + 1000), 6, '0');

    else

        select tree_sortkey, tree.increment_key(max_child_sortkey)
        into v_parent_sortkey, v_max_child_sortkey
        from im_forum_topics
        where topic_id = :new.parent_id
        for update of max_child_sortkey;

        update im_forum_topics
        set max_child_sortkey = v_max_child_sortkey
        where topic_id = :new.parent_id;
	
	:new.tree_sortkey := v_parent_sortkey || v_max_child_sortkey;
    end if;

    :new.max_child_sortkey := null;
end im_forum_topic_insert_tr;
/
show errors


create or replace trigger im_forum_topics_update_tr
before update on im_forum_topics
for each row
declare
        v_parent_sk             im_forum_topics.tree_sortkey%TYPE;
        v_max_child_sortkey     im_forum_topics.max_child_sortkey%TYPE;
        v_old_parent_length     integer;
begin
        if :new.topic_id != :old.topic_id
           or ( (:new.parent_id != :old.parent_id)
                and
                (:new.parent_id is not null or :old.parent_id is not null) ) then
           -- the tree sortkey is going to change so get the new one and update it and all its
           -- children to have the new prefix...
           v_old_parent_length := length(:new.tree_sortkey) + 1;

           if :new.parent_id is null then
                v_parent_sk := lpad(tree.int_to_hex(:new.topic_id + 1000), 6, '0');
           else
                SELECT tree_sortkey, tree.increment_key(max_child_sortkey)
                INTO v_parent_sk, v_max_child_sortkey
                FROM im_forum_topics
                WHERE topic_id = :new.parent_id
                FOR UPDATE;

                UPDATE im_forum_topics
                SET max_child_sortkey = v_max_child_sortkey
                WHERE topic_id = :new.parent_id;

                v_parent_sk := v_parent_sk || v_max_child_sortkey;
           end if;

           UPDATE im_forum_topics
           SET tree_sortkey = v_parent_sk || substr(tree_sortkey, v_old_parent_length)
           WHERE tree_sortkey between :new.tree_sortkey and tree.right(:new.tree_sortkey);
        end if;
end im_forum_topics_update_tr;
/
show errors

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
	p_user_is_company	integer	
) RETURN integer 
IS
	v_permission_p		integer;
BEGIN
	IF p_user_id = p_owner_id THEN		RETURN 1;	END IF;
	IF p_asignee_id = p_user_id THEN	RETURN 1;	END IF;
	IF p_scope = 'public' THEN		RETURN 1;	END IF;
	IF p_scope = 'group' THEN		RETURN p_user_is_object_member;	END IF;
	IF p_scope = 'pm' THEN			RETURN p_user_is_object_admin;	END IF;

	IF p_scope = 'client' AND p_user_is_company = 1 THEN	
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


-------------------------------------------------------------
-- Privileges
--
-- Privileges are permission tokens relative to the "subsite"
-- (package) object "Project/Open Core".
--
prompt *** Creating Privileges
begin
    acs_privilege.create_privilege('add_topic_public','Add global messages','');
    acs_privilege.add_child('admin', 'add_topic_public');

    acs_privilege.create_privilege('add_topic_group','Add essages for the entire (project) group','');
    acs_privilege.add_child('admin', 'add_topic_group');

    acs_privilege.create_privilege('add_topic_staff','Messages to staff members of the group','');
    acs_privilege.add_child('admin', 'add_topic_staff');

    acs_privilege.create_privilege('add_topic_client','Messages to the clients of the group','');
    acs_privilege.add_child('admin', 'add_topic_client');

    acs_privilege.create_privilege('add_topic_noncli','Message to non-clients of the group','');
    acs_privilege.add_child('admin', 'add_topic_noncli');

    acs_privilege.create_privilege('add_topic_pm','Message to the project manager only','');
    acs_privilege.add_child('admin', 'add_topic_pm');
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
-- and Company pages.
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
        v_companies             integer;
        v_freelancers           integer;
        v_proman                integer;
        v_admins                integer;
begin

    select group_id into v_admins from groups where group_name = 'P/O Admins';
    select group_id into v_senman from groups where group_name = 'Senior Managers';
    select group_id into v_proman from groups where group_name = 'Project Managers';
    select group_id into v_accounting from groups where group_name = 'Accounting';
    select group_id into v_employees from groups where group_name = 'Employees';
    select group_id into v_companies from groups where group_name = 'Customers';
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
    acs_permission.grant_permission(v_menu, v_companies, 'read');
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
			"<B>[_ intranet-forum.Forum_Items]<B>" \
			$project_id \
			$return_url \
		] \
		[im_forum_component \
			-user_id $user_id \
			-forum_object_id $project_id \
			-current_page_url $current_url \
			-return_url $return_url \
			-export_var_list [list \
				project_id \
				forum_start_idx \
				forum_order_by \
				forum_how_many \
				forum_view_name \
			] \
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


-- Show the forum component in company page
--
declare
    v_plugin            integer;
begin
    v_plugin := im_component_plugin.new (
	plugin_name =>	'Companies Forum Component',
	package_name =>	'intranet-forum',
        page_url =>     '/intranet/companies/view',
        location =>     'right',
        sort_order =>   10,
        component_tcl => 
	'im_table_with_title \
		[im_forum_create_bar \
			"<B>[_ intranet-forum.Forum_Items]<B>" \
			$company_id \
			$return_url \
		] \
		[im_forum_component \
			-user_id $user_id \
			-forum_object_id $company_id \
			-current_page_url $current_url \
			-return_url $return_url \
			-export_var_list [list \
				company_id \
				forum_start_idx \
				forum_order_by \
				forum_how_many \
				forum_view_name \
			] \
			-forum_type company \
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
			"<B>[_ intranet-forum.Forum_Items]<B>" \
			0 \
			$return_url \
		] \
		[im_forum_component \
			-user_id $user_id \
			-forum_object_id 0 \
			-current_page_url $current_url \
			-return_url $return_url \
			-export_var_list [list \
				forum_start_idx \
				forum_order_by \
				forum_how_many \
				forum_view_name \
			] \
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


@../common/intranet-forum-common.sql