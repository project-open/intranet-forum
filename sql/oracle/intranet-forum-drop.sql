-- /package/intranet-forum/sql/intranet-forum-drop.sql
--
-- Copyright (c) 2003-2004 ]project-open[
--
-- All rights reserved. Please check
-- http://www.project-open.com/license/ for details.
--
-- @author frank.bergmann@project-open.com


-----------------------------------------------------
-- Drop menus and components defined by the module

BEGIN
    im_menu.del_module(module_name => 'intranet-forum');
    im_component_plugin.del_module(module_name => 'intranet-forum');
END;
/
show errors

commit;


delete from im_view_columns where column_id >= 4000 and column_id < 4099;
delete from im_view_columns where column_id >= 4100 and column_id < 4199;
delete from im_view_columns where column_id >= 4200 and column_id < 4299;
delete from im_views where view_id >= 40 and view_id < 50;


-- before remove priviliges remove granted permissions
delete from acs_permissions where privilege = 'add_topic_pm';
delete from acs_permissions where privilege = 'add_topic_noncli';
delete from acs_permissions where privilege = 'add_topic_client';
delete from acs_permissions where privilege = 'add_topic_staff';
delete from acs_permissions where privilege = 'add_topic_group';
delete from acs_permissions where privilege = 'add_topic_public';


-- drop privileges
begin
	acs_privilege.remove_child('admin', 'add_topic_public');
	acs_privilege.remove_child('admin', 'add_topic_group');
	acs_privilege.remove_child('admin', 'add_topic_staff');
	acs_privilege.remove_child('admin', 'add_topic_client');
	acs_privilege.remove_child('admin', 'add_topic_noncli');
	acs_privilege.remove_child('admin', 'add_topic_pm');

	acs_privilege.drop_privilege('add_topic_public');
	acs_privilege.drop_privilege('add_topic_group');
	acs_privilege.drop_privilege('add_topic_staff');
	acs_privilege.drop_privilege('add_topic_client');
	acs_privilege.drop_privilege('add_topic_noncli');
	acs_privilege.drop_privilege('add_topic_pm');
end;
/
show errors


-- no objects yet...
-- delete from acs_objects where object_type='im_menu';

delete from im_component_plugins where package_name = 'intranet-forum';


drop sequence im_forum_topics_seq;
drop sequence im_forum_files_seq;

drop table im_forum_files;
drop table im_forum_topic_user_map;
drop table im_forum_folders;
drop trigger im_forum_topic_insert_tr;
drop table im_forum_topics;

