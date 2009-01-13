<master src="../../intranet-core/www/master">
<property name="title">@title@</property>

<H1>#intranet-forum.Incident_Received#</H1>

<p>
#intranet-forum.Thank_you_for_submitting_your_incident#
</p>


<table border=0 cellspacing=1 cellpadding=1>
<tr valign=top>
  <td valign=top>


	<table border=0 cellspacing=2 cellpadding=2 width="100%">
	<tr class=rowtitle>
	  <td class=rowtitle align=center colspan=2>
	    #intranet-forum.Incident_Information#
	  </td>
	</tr>
	<tr>
	  <td class="form-element">#intranet-forum.Your_Name#</td>
	  <td class="form-widget">@error_first_names@ @error_last_name@</td>
	</tr>
	<tr>
	  <td class="form-element">#intranet-forum.Your_Email#</td>
	  <td class="form-widget">@error_user_email@</td>
	</tr>
	<tr>
	  <td class="form-element">#intranet-forum.System_URL#</td>
	  <td class="form-widget">@system_url@</td>
	</tr>
	<tr>
	  <td class="form-element">#intranet-forum.Publisher_Name#</td>
	  <td class="form-widget">@publisher_name@</td>
	</tr>
	<tr>
	  <td class="form-element">#intranet-forum.Error_URL#</td>
	  <td class="form-widget">@error_url@</td>
	</tr>
	</table>


  </td>
</tr>
<tr><td>&nbsp;<br>&nbsp;</td></tr>
<tr><td>

<h1>Login</h1>
<p>
Please login or use the "Forgot your password?" link<br>
to check the status of your issue requests.
</p>

</td></tr>
<tr>
  <td valign=top>

	<table border=0 cellspacing=2 cellpadding=2 width="100%">
	<tr class=rowtitle>
	  <td class=rowtitle align=center colspan=2>
	    #acs-kernel.common_Login#
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


<p>
Please use the navigation tabs above to explore the system.
</p>



<if @resolved_p@>
	<table border=0 cellspacing=1 cellpadding=1>
	<tr class=rowtitle>
	  <td class=rowtitle align=center colspan=2>
	    Bug Resolution
	  </td>
	</tr>
	<tr>
	  <td>

	<p>
	This bug has already been marked as "@bug_resolution;noquote@".
	</p>
	<p>
	This means that there is probably already a newer version of 
	<span class=brandsec>&\#93;</span><span class=brandfirst>project-open</span><span class=brandsec>&\#91;</span>
	with this bug fixed.<br>
	For details please see the "Open Discussion" form at our
	<a href="http://www.sourceforge.net/projects/project-open/">
	<span class=brandsec>&\#93;</span><span class=brandfirst>po</span><span class=brandsec>&\#91;</span>
	SourceForge Community</a>.
	</p>

	  </td>
	</tr>
	</table>
	<p>&nbsp;</p>
</if>

