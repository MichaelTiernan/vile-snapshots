/* 
 * api.c -- (roughly) nvi's api to perl and tcl
 */

#include "estruct.h"
#include "edef.h"

#if OPT_PERL

#include "api.h"

static WINDOW *curwp_after;

/* Maybe this should go in line.c ? */
static int
linsert_chars(char *s, int len)
{
    int nlcount = 0;
    while (len-- > 0) {
	if (*s == '\n') {
	    lnewline();
	    nlcount++;
	}
	else
	    linsert(1, *s);
	s++;
    }
    return nlcount;
}

/* Another candidate for line.c */
static int
lreplace(char *s, int len)
{
    LINE *lp = DOT.l;
    int i;
    char *t;
    WINDOW *wp;

    copy_for_undo(lp);

    DOT.o = 0;

    if (len > lp->l_size) {
	int nlen;
	char *ntext;

#define roundlenup(n) ((n+NBLOCK-1) & ~(NBLOCK-1))

	nlen = roundlenup(len);
	ntext = castalloc(char, nlen);
	if (ntext == 0)
	    return FALSE;
	if (lp->l_text)
	    ltextfree(lp, curbp);
	lp->l_text = ntext;
	lp->l_size = nlen;
    }

    lp->l_used = len;

    /* FIXME: Handle embedded newlines */
    for (i=len-1, t=lp->l_text; i >=0; i--)
	t[i] = s[i];

    /* We'd normally need a call to chg_buff here, but I don't want
       to pay the price.  
       
       BUT...

       We do call chg_buff before returning to vile.  See
       api_command_cleanup below.
     */

    for_each_window(wp) {
	if (wp->w_dot.l == lp && wp->w_dot.o > len)
	    wp->w_dot.o = len;
	if (wp->w_lastdot.l == lp && wp->w_lastdot.o > len)
	    wp->w_lastdot.o = len;
    }
    do_mark_iterate(mp,
		    if (mp->l == lp && mp->o > len)
			mp->o = len;
    );

    return TRUE;
}

static void
setup_fake_win(SCR *sp)
{
    if (curwp_after == 0)
	curwp_after = curwp;

    if (sp->fwp) {
	curwp = sp->fwp;
    }
    else {
	(void) push_fake_win(sp->bp);
	sp->fwp = curwp;
	sp->changed = 0;
    }

    /* Should be call make_current() for this? */
    curbp = curwp->w_bufp;
}

/*
 * This is a variant of gotoline in basic.c.  It differs in that
 * it attempts to use the line number information to more efficiently
 * find the line in question.  It will also position DOT at the beginning
 * of the line.
 *
 */
static int
_api_gotoline(SCR *sp, int lno)
{
#if !SMALLER
    int count;
    LINE *lp;
    BUFFER *bp = sp->bp;

    if (!b_is_counted(bp))
	bsizes(bp);

    count = lno - DOT.l->l_number;
    lp = DOT.l;

    while (count < 0) {
	lp = lback(lp);
	count++;
    }
    while (count > 0) {
	lp = lforw(lp);
	count--;
    }

    DOT.o = 0;

    if (lp != buf_head(bp) && lno == lp->l_number) {
	DOT.l = lp;
	return TRUE;
    }
    else {
	DOT.l = lback(buf_head(bp));
	return FALSE;
    }

#else
    return gotoline(TRUE, lno);
#endif
}

int
api_aline(SCR *sp, int lno, char *line, int len)
{
    setup_fake_win(sp);

    if (lno >= 0 && lno < line_count(sp->bp)) {
	_api_gotoline(sp, lno+1);
	linsert_chars(line, len);
	lnewline();
    }
    else {	/* append to the end */
	gotoline(FALSE, 0);
	gotoeol(FALSE, 0);
	lnewline();
	linsert_chars(line, len);
    }

    return TRUE;
}

int
api_dline(SCR *sp, int lno)
{
    int status = TRUE;

    setup_fake_win(sp);

    if (lno > 0 && lno <= line_count(sp->bp)) {
	_api_gotoline(sp, lno);
	gotobol(TRUE,TRUE);
	ldelete(llength(DOT.l) + 1, TRUE);
    }
    else
	status = FALSE;

    return status;
}

int
api_gline(SCR *sp, int lno, char **linep, int *lenp)
{
    int status = TRUE;

    setup_fake_win(sp);

    if (lno > 0 && lno <= line_count(sp->bp)) {
	_api_gotoline(sp, lno);
	*linep = DOT.l->l_text;
	*lenp = llength(DOT.l);
	if (*lenp == 0) {
	    *linep = "";	/* Make sure we pass back a zero length,
	                           null terminated value when the length
				   is zero.  Otherwise perl gets confused.
				   (It thinks it should calculate the length
				   when given a zero length.)
				 */
	}
    }
    else
	status = FALSE;

    return status;
}

int
api_sline(SCR *sp, int lno, char *line, int len)
{
    int status = TRUE;

    setup_fake_win(sp);

    if (lno > 0 && lno <= line_count(sp->bp)) {
	_api_gotoline(sp, lno);
	if (   DOT.l->l_text != line 
	    && (   llength(DOT.l) != len
	        || memcmp(line, DOT.l->l_text, len) != 0)) {
	    lreplace(line, len);
	    sp->changed = 1;
	}
    }
    else
	status = FALSE;

    return status;
}

int
api_iline(SCR *sp, int lno, char *line, int len)
{
    return api_aline(sp, lno-1, line, len);
}

int
api_lline(SCR *sp, int *lnop)
{
    *lnop = line_count(sp->bp);
    return TRUE;
}

SCR *
api_fscreen(int id, char *name)
{
    BUFFER *bp;

    bp = find_b_file(name);

    if (bp)
	return api_bp2sp(bp);
    else
	return 0;
}

/* FIXME: return SCR * for retbpp */
int
api_edit(SCR *sp, char *fname, SCR **retspp, int newscreen)
{
    BUFFER *bp;
    if (fname == NULL) {
	/* FIXME: This should probably give you a truly anonymous buffer */
	fname = (char *) UNNAMED_BufName;
    }
    bp = getfile2bp(fname, FALSE, FALSE);
    if (bp == 0) {
	*retspp = 0;
	return 1;
    }
    *retspp = api_bp2sp(bp);
    setup_fake_win(*retspp);
    return !swbuffer_lfl(bp, FALSE);
}

int
api_swscreen(SCR *oldsp, SCR *newsp)
{
    api_command_cleanup();		/* pop the fake windows */

    swbuffer(sp2bp(oldsp));
    swbuffer(sp2bp(newsp));
    curwp_after = curwp;
}

/*
 * The following are not in the nvi API. But I needed them in order to
 * do an efficient implementation for vile.
 */

void
api_command_cleanup(void)
{
    BUFFER *bp;

    if (curwp_after == 0)
	curwp_after = curwp;

    /* Pop the fake windows */

    while ((bp = pop_fake_win(curwp_after)) != NULL) {
	if (bp2sp(bp) != NULL)
	    bp2sp(bp)->fwp = 0;
	    if (bp2sp(bp)->changed) {
		chg_buff(bp, WFHARD);
		bp2sp(bp)->changed = 0;
	    }
    }

    curwp_after = 0;

    if (curbp != curwp->w_bufp)
	make_current(curwp->w_bufp);
}

void
api_free_private(void *vsp)
{
    SCR *sp = (SCR *) vsp;

    if (sp) {
	sp->bp->b_api_private = 0;
#if OPT_PERL
	perl_free_handle(sp->perl_handle);
#endif
	free(sp);
    }
}

/* Given a buffer pointer, returns a pointer to a SCR structure,
 * creating it if necessary.
 */
SCR *
api_bp2sp(BUFFER *bp)
{
    SCR *sp;

    sp = bp2sp(bp);
    if (sp == 0) {
	sp = typecalloc(SCR);
	if (sp != 0) {
	    bp->b_api_private = sp;
	    sp->bp = bp;
	}
    }
    return sp;
}

#endif