<!-- packages/intranet-forum/www/index.adp -->
<!-- @author Juanjo Ruiz (juanjoruizx@yahoo.es) -->

<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN">
<master src="../../intranet-core/www/master">
<property name="title">@page_title@</property>
<property name="context">@context_bar@</property>
<property name="main_navbar_label">forum</property>
<property name="sub_navbar">@sub_navbar;noquote@</property>

<div class="filter-list">
   <div class="filter">
      <div class="filter-block">
         <div class="filter-title">
            #intranet-forum.Filter_Topics#
         </div>
         <form method=get action="index">
            <%= [export_form_vars forum_group_id forum_start_idx forum_order_by forum_how_many forum_view_name] %>
            @filter_html;noquote@
         </form>
      </div>
   </div>

   <div class="fullwidth-list">
      <%= [im_table_with_title "Forum" $forum_content] %>
   </div>

   <div class="filter-list-footer"></div>

</div>