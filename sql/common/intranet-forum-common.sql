-- /packages/intranet-forum/sql/common/intranet-forum-create.sql
--
-- Copyright (c) 2003 - 2009 ]project-open[
--
-- All rights reserved. Please check
-- http://www.project-open.com/license/ for details.
--
-- @author frank.bergmann@project-open.com
-- @author juanjoruizx@yahoo.es

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
-- delete from im_categories where category_type = 'Intranet Topic Type';

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

-- commit;
-- reserved until 1199


create or replace view im_forum_topic_types as 
select 
	category_id as topic_type_id, 
	category as topic_type
from im_categories 
where category_type = 'Intranet Topic Type';



-- Intranet Topic Status
-- delete from im_categories where category_type = 'Intranet Topic Status';

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

-- commit;
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
insert into im_views (view_id, view_name, visible_for) values (45, 'forum_list_company', 'view_forums');
insert into im_views (view_id, view_name, visible_for) values (46, 'forum_list_user', 'view_forums');


-- ForumList for home page
--
-- delete from im_view_columns where column_id >= 4000 and column_id < 4099;
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
[string_truncate -len 80 $subject]</a>"','','',6,'');

insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (4006,40,NULL,'Due',
'[if {$overdue > 0} {
        set t "<font color=red>$due_date</font>"
} else {
        set t "$due_date"
}]','','',8,'');

insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (4010,40,NULL,
'"[im_gif help "Select topics here for processing"]"',
'"<input type=checkbox name=topic_id.$topic_id>"',
'','',12,'');

-- commit;



-- ForumList for ProjectViewPage or CompanyViewPage
--
-- delete from im_view_columns where column_id >= 4100 and column_id < 4199;
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
[string_truncate -len 80 $subject]</a>"','','',6,'');

insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (4106,41,NULL,'Due',
'[if {$overdue > 0} {
        set t "<font color=red>$due_date</font>"
} else {
        set t "$due_date"
}]','','',8,'');

insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (4107,41,NULL,'Own',
'"<a href=/intranet/users/view?user_id=$owner_id>$owner_initials</a>"',
'','',9,'');

insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (4108,41,NULL,'Ass',
'"<a href=/intranet/users/view?user_id=$asignee_id>$asignee_initials</a>"',
'','',10,'');

insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (4109,41,NULL,'Status',
'$topic_status','','',11,'');

insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (4110,41,NULL,
'"[im_gif help "Select topics here for processing"]"',
'"<input type=checkbox name=topic_id.$topic_id>"',
'','',12,'');

-- commit;



-- ForumList for the forum index page (all projects with a lot of space)
--
-- delete from im_view_columns where column_id >= 4200 and column_id < 4299;
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
[string_truncate -len 80 $subject]</A>"','','',6,'');

insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (4206,42,NULL,'Due',
'[if {$overdue > 0} {
        set t "<font color=red>$due_date</font>"
} else {
        set t "$due_date"
}]','','',8,'');


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
extra_select, extra_where, sort_order, visible_for) values (4210,42,NULL,'Read',
'$read','','',12,'');

insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (4211,42,NULL,
'"[im_gif help "Select topics here for processing"]"',
'"<input type=checkbox name=topic_id.$topic_id>"',
'','',13,'');

insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (4212,42,NULL,'Folder',
'$folder_name','','',14,'');

-- commit;


-- ForumList Short as a default when no other LIST is found
--
-- delete from im_view_columns where column_id >= 4400 and column_id < 4499;
insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (4400,44,NULL,'P',
'$priority','','',2,'');

insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (4402,44,NULL,'Type',
'"<a href=/intranet-forum/view?[export_url_vars topic_id return_url]>\
[im_gif $topic_type]</a>"',
'','',4,'');

insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (4404,44,NULL,'Subject',
'"<a href=/intranet-forum/view?[export_url_vars topic_id return_url]>\
[string_truncate -len 80 $subject]</a>"','','',6,'');

insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (4406,44,NULL,'Due',
'[if {$overdue > 0} {
        set t "<font color=red>$due_date</font>"
} else {
        set t "$due_date"
}]','','',8,'');

insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (4407,44,NULL,'Own',
'"<a href=/intranet/users/view?user_id=$owner_id>$owner_initials</a>"',
'','',9,'');

insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (4408,44,NULL,'Ass',
'"<a href=/intranet/users/view?user_id=$asignee_id>$asignee_initials</a>"',
'','',10,'');

insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (4410,44,NULL,
'"[im_gif help "Select topics here for processing"]"',
'"<input type=checkbox name=topic_id.$topic_id>"',
'','',12,'');

-- commit;


-- ForumList Short as a default when no other LIST is found
--
-- delete from im_view_columns where column_id >= 4500 and column_id < 4599;
insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (4500,45,NULL,'P',
'$priority','','',2,'');

insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (4502,45,NULL,'Type',
'"<a href=/intranet-forum/view?[export_url_vars topic_id return_url]>\
[im_gif $topic_type]</a>"',
'','',4,'');

insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (4504,45,NULL,'Subject',
'"<a href=/intranet-forum/view?[export_url_vars topic_id return_url]>\
[string_truncate -len 80 $subject]</a>"','','',6,'');

insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (4506,45,NULL,'Due',
'[if {$overdue > 0} {
        set t "<font color=red>$due_date</font>"
} else {
        set t "$due_date"
}]','','',8,'');

insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (4507,45,NULL,'Own',
'"<a href=/intranet/users/view?user_id=$owner_id>$owner_initials</a>"',
'','',9,'');

insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (4508,45,NULL,'Ass',
'"<a href=/intranet/users/view?user_id=$asignee_id>$asignee_initials</a>"',
'','',10,'');

insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (4510,45,NULL,
'"[im_gif help "Select topics here for processing"]"',
'"<input type=checkbox name=topic_id.$topic_id>"',
'','',12,'');

-- commit;


-- ForumList Short as a default when no other LIST is found
--
-- delete from im_view_columns where column_id >= 4600 and column_id < 4699;
insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (4600,46,NULL,'P',
'$priority','','',2,'');

insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (4602,46,NULL,'Type',
'"<a href=/intranet-forum/view?[export_url_vars topic_id return_url]>\
[im_gif $topic_type]</a>"',
'','',4,'');

insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (4604,46,NULL,'Subject',
'"<a href=/intranet-forum/view?[export_url_vars topic_id return_url]>\
[string_truncate -len 80 $subject]</a>"','','',6,'');

insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (4606,46,NULL,'Due',
'[if {$overdue > 0} {
        set t "<font color=red>$due_date</font>"
} else {
        set t "$due_date"
}]','','',8,'');

insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (4607,46,NULL,'Own',
'"<a href=/intranet/users/view?user_id=$owner_id>$owner_initials</a>"',
'','',9,'');

insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (4608,46,NULL,'Ass',
'"<a href=/intranet/users/view?user_id=$asignee_id>$asignee_initials</a>"',
'','',10,'');

insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (4610,46,NULL,
'"[im_gif help "Select topics here for processing"]"',
'"<input type=checkbox name=topic_id.$topic_id>"',
'','',12,'');

-- commit;

