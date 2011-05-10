<?xml version="1.0"?>
<!DOCTYPE queryset PUBLIC "-//OpenACS//DTD XQL 1.0//EN" "/usr/share/emacs/DTDs/xql.dtd">
<!-- packages/intranet-forum/tcl/new-2-postgresql.xql -->
<!-- @author  (nsadmin@barna.competitiveness.com) -->
<!-- @creation-date 2004-09-14 -->
<!-- @arch-tag 1feaadb3-aa32-427e-b540-ed8b20a4bb20 -->
<!-- @cvs-id $Id$ -->

<queryset>
  
  
  <rdbms>
    <type>postgresql</type>
    <version>7.2</version>
  </rdbms>
  
  <fullquery name="subscribe_object_members">

    <querytext>

select
	p.party_id as user_id
from
	acs_rels r,
	-- get the members and admins of object_id
	(       select  1 as member_p,
			(CASE WHEN m.object_role_id = 1301 
			       or m.object_role_id = 1302 
			       or m.object_role_id = 1303 
			THEN 1 
			ELSE 0 END
			) as admin_p,
			r.object_id_two as user_id
		from    acs_rels r,
			im_biz_object_members m
		where   r.object_id_one = :object_id
			and r.rel_id = m.rel_id
	) o_mem,
	parties p
      LEFT JOIN
	(select	m.member_id as user_id,
		1 as p
	 from group_distinct_member_map m
	 where	m.group_id = [im_customer_group_id]
	) customers ON p.party_id=customers.user_id
      LEFT JOIN
	(select	m.member_id as user_id,
		1 as p
	 from group_distinct_member_map m
	 where	m.group_id = [im_employee_group_id]
	) employees ON p.party_id=employees.user_id
where
	r.object_id_one = :object_id
	and r.object_id_two = p.party_id
	and o_mem.user_id = p.party_id
	and 1 = im_forum_permission(
		p.party_id,
		:current_user_id,
		:asignee_id,
		:object_id,
		:scope,
		o_mem.member_p,
		o_mem.admin_p,
		employees.p,
		customers.p
	)

    </querytext>

  </fullquery>
</queryset>
