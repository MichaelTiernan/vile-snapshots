/*
 * Configurable headers used by termcap/terminfo driver for vile.
 *
 * $Header: /users/source/archives/vile.vcs/RCS/tcap.h,v 1.1 1997/12/02 11:59:06 tom Exp $
 */

#ifndef VILE_TCAP_H
#define VILE_TCAP_H 1

#ifdef __cplusplus
extern "C" {
#endif

#if USE_TERMINFO
#  define TGETSTR(name, bufp) tigetstr(name)
#  define TGETNUM(name)       tigetnum(name) /* may be tigetint() */
#  define TGETFLAG(name)      tigetflag(name)
#  define CAPNAME(a,b)        b
#  define NO_CAP(s)           (s == 0 || s == (char *)-1)
#  undef TRUE
#  undef FALSE
#  undef WINDOW
#  define WINDOW tcap_WINDOW
#  if HAVE_NCURSES_H
#    include <ncurses.h>
#  else
#    include <curses.h>
#  endif
#  undef WINDOW
#  define WINDOW vile_WINDOW
#  ifndef TRUE
#  define TRUE 1
#  endif
#  ifndef FALSE
#  define FALSE 0
#  endif
#  if HAVE_TERM_H
#    include <term.h>
#  endif
#  if !HAVE_TIGETNUM && HAVE_TIGETINT
#    define tigetnum tigetint
#  endif
#else /* USE_TERMCAP */
#  undef USE_TERMCAP
#  define USE_TERMCAP 1
#  define TGETSTR(name, bufp) tgetstr(name, bufp)
#  define TGETNUM(name)       tgetnum(name)
#  define TGETFLAG(name)      tgetflag(name)
#  define CAPNAME(a,b)        a
#  define NO_CAP(s)           (s == 0)
#  if HAVE_TERMCAP_H
#    include <termcap.h>
#  endif
#endif /* USE_TERMINFO */

#if HAVE_EXTERN_TCAP_PC
extern char PC;			/* used in 'tputs()' */
#endif

#if MISSING_EXTERN_TGETENT
extern	int	tgetent (char *buffer, char *termtype);
#endif
#if MISSING_EXTERN_TGETFLAG || MISSING_EXTERN_TIGETFLAG
extern	int	TGETFLAG (char *name);
#endif
#if MISSING_EXTERN_TGETNUM || MISSING_EXTERN_TIGETNUM
extern	int	TGETNUM (char *name);
#endif
#if MISSING_EXTERN_TGETSTR || MISSING_EXTERN_TIGETSTR
extern	char *	TGETSTR(const char *name, char **area);
#endif
#if MISSING_EXTERN_TGOTO
extern	char *	tgoto (const char *cstring, int hpos, int vpos);
#endif
#if MISSING_EXTERN_TPARAM
extern	char *	tparam (char *cstring, char *buf, int size, ...);
#endif
#if MISSING_EXTERN_TPARM
extern	char *	tparm (const char *fmt, ...);
#endif
#if MISSING_EXTERN_TPUTS
extern	int	tputs (char *string, int nlines, OUTC_DCL (*_f)(OUTC_ARGS) );
#endif

#ifdef __cplusplus
}
#endif

#endif /* VILE_TCAP_H */