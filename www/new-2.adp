<!-- packages/intranet-forum/www/new-2.adp -->
<master src="../../intranet-core/www/master">
<property name="title">@page_title@</property>
<property name="context">@context_bar@</property>
<property name="main_navbar_label">forum</property>


<h1><%= [lang::message::lookup "" intranet-forum.Send_Forum_Notifications "Send Forum Notifications"] %></h1>
<form method=post action=new-3>
<%= [export_form_vars topic_id object_type subject msg_url message return_url] %>
<table class="list">

  <tr class="list-header">
    <th class="list-narrow"><%= [lang::message::lookup "" intranet-forum.Email "Email"] %></th>
    <th class="list-narrow"><%= [lang::message::lookup "" intranet-forum.Name "Name"] %></th>
    <th class="list-narrow"><%= [im_gif help [lang::message::lookup "" intranet-forum.Select_users_to_notify "Please select the users to notify"]] %></th>
  </tr>

  <multiple name=stakeholders>
  <if @stakeholders.rownum@ odd>
    <tr class="list-odd">
  </if> <else>
    <tr class="list-even">
  </else>

    <td class="list-narrow">
        @stakeholders.email@
    </td>
    <td class="list-narrow">
        @stakeholders.name@
    </td>
    <td class="list-narrow">
        <input type=checkbox name=notifyee_id value="@stakeholders.user_id@" @stakeholders.checked@>
    </td>
  </tr>
  </multiple>

  <tr>
    <td colspan=3 align=right>
      <input type=submit value="<%= [lang::message::lookup "" intranet-forum.Send_Email "Send Email"] %>">
    </td>
  </tr>
</table>
</form>

