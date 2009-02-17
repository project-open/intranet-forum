-- /package/intranet-forum/sql/intranet-forum-drop.sql
--
-- Copyright (c) 2003 - 2009 ]project-open[
--
-- All rights reserved. Please check
-- http://www.project-open.com/license/ for details.
--
-- @author frank.bergmann@project-open.com


-----------------------------------------------------
-- Drop menus and components defined by the module

select im_menu__del_module('intranet-forum');
select im_component_plugin__del_module('intranet-forum');


delete from im_view_columns where column_id >= 4000 and column_id < 4099;
delete from im_view_columns where column_id >= 4100 and column_id < 4199;
delete from im_view_columns where column_id >= 4200 and column_id < 4299;
delete from im_view_columns where view_id >= 40 and view_id < 50;
delete from im_views where view_id >= 40 and view_id < 50;




-----------------------------------------------------------
-- Delete Business Object View URLs
--

delete from im_biz_object_urls
where object_type = 'im_forum_topic';



-- before remove priviliges remove granted permissions
create or replace function inline_revoke_permission (varchar)
returns integer as '
DECLARE
        p_priv_name     alias for $1;
BEGIN
     lock table acs_permissions_lock;

     delete from acs_permissions
     where privilege = p_priv_name;
     
     delete from acs_privilege_hierarchy
     where child_privilege = p_priv_name;

     return 0;

end;' language 'plpgsql';

select inline_revoke_permission ('add_topic_pm');
select inline_revoke_permission ('add_topic_noncli');
select inline_revoke_permission ('add_topic_client');
select inline_revoke_permission ('add_topic_staff');
select inline_revoke_permission ('add_topic_group');
select inline_revoke_permission ('add_topic_public');

-- drop privileges
select acs_privilege__drop_privilege('add_topic_public');
select acs_privilege__drop_privilege('add_topic_group');
select acs_privilege__drop_privilege('add_topic_staff');
select acs_privilege__drop_privilege('add_topic_client');
select acs_privilege__drop_privilege('add_topic_noncli');
select acs_privilege__drop_privilege('add_topic_pm');


-- no objects yet...
-- delete from acs_objects where object_type='im_menu';

delete from im_component_plugins where package_name = 'intranet-forum';

drop sequence im_forum_topics_seq;
drop sequence im_forum_files_seq;

drop table im_forum_files;
drop table im_forum_topic_user_map;
drop table im_forum_folders;

drop trigger im_forum_topics_update_tr on im_forum_topics;
drop function im_forum_topics_update_tr ();

drop trigger im_forum_topic_insert_tr on im_forum_topics;
drop function im_forum_topic_insert_tr ();

drop table im_forum_topics;

