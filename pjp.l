%{
#include "pjp.tab.h"
#include <ctype.h>
#include <string.h>
#include "global.h"
void to_upper(char* s);
%}


%%
","						{ return ','; }
"."						{ return '.'; }
";"						{ return ';'; }
":"						{ return ':'; }
"("						{ return '('; }
")"						{ return ')'; }
"+"						{ return '+'; }
"-"						{ return '-'; }
"*"						{ return '*'; }
"/"						{ return '/'; }
"="|"<"|">"|"<="|">="|"<>" 	{ 
		if (strcmp(yytext, "=") == 0) { strcpy(yylval.val, "=="); }
		else if (strcmp(yytext, "<>") == 0) { strcpy(yylval.val, "!="); }
		else { strcpy(yylval.val, yytext); }
		return RELACNI_OPERATOR;
	}
":="						{ return PRIRAZOVACI_OPERATOR; }


div				{ return DIV_OPERATOR; }
mod				{ return MOD_OPERATOR; }
or|OR			{ return NEBO_OPERATOR; }
and|AND			{ return AND_OPERATOR; }
not				{ return NOT_OPERATOR; }
program			{ return PROGRAM; }
var				{ return VAR; }
integer			{ return INTEGER; }
char			{ return CHAR; }
begin 			{ return BEGIN_TOK; }
end				{ return END; }
if				{ return IF; }
then			{ return THEN; }
else			{ return ELSE; }
while			{ return WHILE; }
do				{ return DO; }


[0-9]{1,10}			{ strcpy(yylval.val, yytext); return NUM; }
(#([0-9]){1,3})		{ snprintf(yylval.val, VAL_SIZE, "'%c'", (char)atoi(yytext+1)); return ZNAKOVA_KONSTANTA; }
('.')				{ strcpy(yylval.val, yytext); return ZNAKOVA_KONSTANTA; }
[a-zA-Z]{1}[a-zA-Z0-9]{2,10}		{ to_upper(yytext); strcpy(yylval.val, yytext); return ID; }
[a-zA-Z]{1,10}						{ to_upper(yytext); strcpy(yylval.val, yytext); return ID; }

\{[^\{]*\}				{;}
\(\*[^\(]*\*\)			{;}

[ \t\r]				{;}
"\n"				{ yylineno++; }

.					{ return yytext[0]; }
%%

void to_upper(char* s)
{
	const unsigned long len = strlen(s);
	for (unsigned long i = 0; i < len; ++i) {
		s[i] = toupper(s[i]);
	}
}



