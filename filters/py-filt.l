%pointer
%s NORMAL QUOTE1 QUOTE2 QUOTE3

%{

/*
 * $Header: /users/source/archives/vile.vcs/filters/RCS/py-filt.l,v 1.19 2013/12/02 01:32:53 tom Exp $
 *
 * Filter to add vile "attribution" sequences to a Python script
 */

#include <filters.h>

DefineFilter(py);

static char *Comment_attr;
static char *Ident2_attr;
static char *Keyword_attr;
static char *Number_attr;
static char *String_attr;

%}

COMMENT		#.*\n

KEYWORD		[[:alpha:]_][[:alnum:]_]*

SIGN		[-+]
DECIMAL		[[:digit:]_]+
OCTAL		0[0-7_]+
HEXADECIMAL	0x[[:xdigit:]_]+
REAL		[-+]?([[:digit:]_]*\.[[:digit:]][[:digit:]_]*)([eE][+-]?[[:digit:]_]+)?
NUMBER		{SIGN}?({DECIMAL}|{OCTAL}|{HEXADECIMAL})[L]?|{REAL}

%%

<NORMAL>{KEYWORD}	{ WriteToken(get_keyword_attr(yytext)); }

<NORMAL>{COMMENT}	{ WriteToken(Comment_attr); }

<NORMAL>{NUMBER}	{ WriteToken(Number_attr); }

<NORMAL>\'		{ BeginQuote(QUOTE1, String_attr); }
<QUOTE1>\'		{ FinishQuote(NORMAL); }
<QUOTE1>(\\.|.)		{ flt_bfr_append(yytext, yyleng); }
<QUOTE1>[\n]		{ flt_bfr_append(yytext, yyleng); }

<NORMAL>\"		{ BeginQuote(QUOTE2, String_attr); }
<QUOTE2>\"		{ FinishQuote(NORMAL); }
<QUOTE2>(\\.|.)		{ flt_bfr_append(yytext, yyleng); }
<QUOTE2>[\n]		{ flt_bfr_append(yytext, yyleng); }

<NORMAL>\"\"\"		{ BeginQuote(QUOTE3, String_attr); }
<QUOTE3>\"\"\"		{ FinishQuote(NORMAL); }
<QUOTE3>(\\.|.)		{ flt_bfr_append(yytext, yyleng); }
<QUOTE3>[\n]		{ flt_bfr_append(yytext, yyleng); }

<NORMAL>.		{ ECHO; }

%%

static void
init_filter(int before GCC_UNUSED)
{
    (void) before;
}

static void
do_filter(FILE *inputs)
{
    InitLEX(inputs);

    Comment_attr = class_attr(NAME_COMMENT);
    Ident2_attr = class_attr(NAME_IDENT2);
    Keyword_attr = class_attr(NAME_KEYWORD);
    Number_attr = class_attr(NAME_NUMBER);
    String_attr = class_attr(NAME_LITERAL);

    BEGIN(NORMAL);
    RunLEX();
    flt_bfr_finish();
}

#if NO_LEAKS
static void
free_filter(void)
{
    USE_LEXFREE;
}
#endif
