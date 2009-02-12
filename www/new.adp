<!-- packages/intranet-forum/www/new.adp -->
<!-- @author Juanjo Ruiz (juanjoruizx@yahoo.es) -->

<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN">
<master src="../../intranet-core/www/master">
<property name="title">@page_title@</property>
<property name="context">@context_bar@</property>
<property name="main_navbar_label">forum</property>


<form action=new-2 method=POST>
<%= [eval "export_form_vars [join $export_var_list " "]"] %>

<table cellspacing=1 border=0 cellpadding=1>
@table_body;noquote@
</table>
</form>


@rendered_parent_html;noquote@

