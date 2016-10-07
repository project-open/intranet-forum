# /packages/intranet-forum/tcl/intranet-forum-procs.tcl
#
# Copyright (C) 2003 - 2009 ]project-open[
#
# All rights reserved. Please check
# http://www.project-open.com/license/ for details.

set prefix "/intranet-forum"
set url "${prefix}/*"
ns_register_proc OPTIONS ${url} im_forum_handle_options

