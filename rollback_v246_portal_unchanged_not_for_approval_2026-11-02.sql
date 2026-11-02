-- استرجاع v246: يعيد teacher_portal_submit كما كانت قبل v246
do $r$ begin execute (select def from private.v246_backup where name = 'teacher_portal_submit'); end $r$;
