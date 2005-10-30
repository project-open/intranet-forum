<master src="../../intranet-core/www/master">
<property name="title">@title@</property>

<H1>#intranet-forum.Incident_Received#</H1>

<p>
#intranet-forum.Thank_you_for_submitting_your_incident#
</p><p>
#intranet-forum.We_will_notify_you_as_soon_as_possible#
</p>


<table border=0 cellspacing=1 cellpadding=1>
<tr valign=top>
  <td valign=top>


<table border=0 cellspacing=1 cellpadding=1>
<tr class=rowtitle>
  <td class=rowtitle align=center colspan=2>
    #intranet-forum.Incident_Information#
  </td>
</tr>
<tr>
  <td>#intranet-forum.Your_Name#</td>
  <td>@error_first_names@ @error_last_name@</td>
</tr>
<tr>
  <td>#intranet-forum.Your_Email#</td>
  <td>@error_user_email@</td>
</tr>
<tr>
  <td>#intranet-forum.System_URL#</td>
  <td>@system_url@</td>
</tr>
<tr>
  <td>#intranet-forum.Publisher_Name#</td>
  <td>@publisher_name@</td>
</tr>
<tr>
  <td>#intranet-forum.Error_URL#</td>
  <td>@error_url_50@</td>
</tr>
</table>


  </td>
  <td valign=top>

<table border=0 cellspacing=1 cellpadding=1>
<tr class=rowtitle>
  <td class=rowtitle align=center colspan=2>
    #intranet-forum.Do_you_have_a_support_contract#
  </td>
</tr>
<tr>
  <td colspan=2>
<include src="/packages/acs-subsite/lib/login" return_url="@return_url;noquote@" no_frame_p="1" authority_id="@authority_id@" username="@username;noquote@" email="@error_user_email;noquote@" &="__adp_properties">
  </td>
</tr>
</table>

  </td>
</tr>
</table>








