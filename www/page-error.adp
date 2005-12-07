<!-- This page goes into /packages/apm-tcl/lib/page-error.adp -->
<master>
<property name="title"><Server Error></property>


<p>
  There was a server error processing your request. We apologize.<br>
  Please contribute to remove this error by pressing the button below:
</p>


<% set error_url [im_url_with_query] %>
<% set error_location "[ns_info address] on [ns_info platform]" %>
<% set report_url [ad_parameter -package_id [im_package_core_id] "ErrorReportURL" "" ""] %>
<% set system_url [ad_parameter -package_id [ad_acs_kernel_id] SystemURL "" ""] %>
<% db_1row user_info "select * from cc_users where user_id=[ad_get_user_id]" %>
<% set publisher_name [ad_parameter -package_id [ad_acs_kernel_id] PublisherName "" ""] %>
<% set package_versions [db_list package_versions "select v.package_key||':'||v.version_name from (select max(version_id) as version_id, package_key from apm_package_versions group by package_key) m, apm_package_versions v where m.version_id = v.version_id"] %>


<form action="@report_url;noquote@" method=POST>
<input type=hidden name=error_url value=@error_url@>
<input type=hidden name=error_location value=@error_location@>
<input type=hidden name=system_url value=@system_url@>
<input type=hidden name=error_first_names value=@first_names;noquote@>
<input type=hidden name=error_last_name value=@last_name;noquote@>
<input type=hidden name=error_user_email value=@email;noquote@>
<input type=hidden name=package_versions value="@package_versions;noquote@">
<input type=hidden name=publisher_name value="@publisher_name;noquote@">
<if @message@ not nil>
  <input type=hidden name=error_message value="@message;noquote@">
</if>
<if @stacktrace@ not nil>
  <input type=hidden name=error_info value="@stacktrace@">
</if>
<input type=submit name=submit value="Report this Error">
</form>

<if @message@ not nil>
  <p>
    @message;noquote@
  </p>
</if>

<if @stacktrace@ not nil>
  <p>
    Here is a detailed dump of what took place at the time of the error, which may assist a programmer in tracking down the problem:
  </p>
  <blockquote><pre>@stacktrace@</pre></blockquote>
</if>
<else>
  <p>
    The error has been logged and will be investigated by our system programmers.
  </p>
</else>

