<!-- packages/intranet-forum/www/index.adp -->
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN">

<master src="../../intranet-core/www/master">
<property name="doc(title)">@page_title;literal@</property>
<property name="context">@context_bar;literal@</property>
<property name="main_navbar_label">forum</property>
<property name="sub_navbar">@sub_navbar;literal@</property>
<property name="left_navbar">@left_navbar_html;literal@</property>

<%= [im_table_with_title "Forum" $forum_content] %>
