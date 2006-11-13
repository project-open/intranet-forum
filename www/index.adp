<!-- packages/intranet-forum/www/index.adp -->
<!-- @author Juanjo Ruiz (juanjoruizx@yahoo.es) -->

<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN">
<master src="../../intranet-core/www/master">
<property name="title">@page_title@</property>
<property name="context">@context_bar@</property>
<property name="main_navbar_label">forum</property>


<form method=get action='index'>
<%= [export_form_vars forum_group_id forum_start_idx forum_order_by forum_how_many forum_view_name] %>
@filter_html;noquote@
</form>

<%= [im_forum_navbar "/intranet-forum/index" [list forum_group_id forum_start_idx forum_order_byforum_how_many forum_mine_p forum_view_name] $forum_folder] %>

@forum_content;noquote@
