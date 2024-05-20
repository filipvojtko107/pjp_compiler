%{
	#include <stdio.h>
	#include <fcntl.h>
	#include <unistd.h>
	#include <stdlib.h>
	#include <string.h>
	#include "global.h"
	#define ICGF		"mezikod.tac"
	//#define YYDEBUG 1

	// Queue type
	enum QType
	{
		IEQ,
		WQ
	};

	enum Direction
	{
		BEGIN,
		TAIL
	};

	struct Label
	{
		struct Label* next;
		struct Label* prev;
		unsigned long long label;
		unsigned is_goto;
	};

	void clear_labels();
	void add_label(const enum QType qtype, const enum Direction dir);
	void remove_label(const enum QType qtype, const enum Direction dir);
	void gen_label(const enum QType qtype, const enum Direction dir);
	void gt_label(const enum QType qtype);
	void ngt_label(const enum QType qtype, const char* str);  // not goto label

	int yylex(void);
	int yyerror(char* s);
	int check_input_params(int argc, const char** argv);
	int redirect_input(const char* fname);

	static FILE* icgf = NULL;
	static unsigned long long temp_num = 0;
	static unsigned long long label_num = 1;
	static unsigned last_ie = 0;	// jestli byl posledni prikaz if-else nebo ne
	extern int yylineno;

	static struct Label* ieq_head = NULL;  // if-else queue head
	static struct Label* ieq_tail = NULL;  // if-else queue tail

	static struct Label* wq_head = NULL;	// while queue head
	static struct Label* wq_tail = NULL;	// while queue tail
%}

%union { 
	char val[1024];
}

%type <val> promenna vyraz jednoduchy_vyraz terminalni_vyraz faktor
%token <val> PROGRAM VAR INTEGER CHAR BEGIN_TOK END IF THEN ELSE WHILE DO PRIRAZOVACI_OPERATOR DIV_OPERATOR MOD_OPERATOR NEBO_OPERATOR AND_OPERATOR NOT_OPERATOR ID NUM ZNAKOVA_KONSTANTA RELACNI_OPERATOR

%%
program:
prog
deklarace
slozeny_prikaz
'.'
;

prog:
	PROGRAM ID '(' netypovany_seznam_identifikatoru ')' ';'
	| error { yyclearin; }
	;

netypovany_seznam_identifikatoru:
	ID
	| netypovany_seznam_identifikatoru ',' ID
	;	

deklarace:
	deklar_seznam
	| %empty
	;

deklar_seznam:
	VAR seznam_identifikatoru ';'
	| deklar_seznam VAR seznam_identifikatoru ';'
	| deklar_seznam error {  }
	| error {  }
	;

seznam_identifikatoru:
	ID typovany_seznam_identifikatoru
	;

typovany_seznam_identifikatoru:
	',' ID typovany_seznam_identifikatoru
	| ':' typ
	;

typ: 
	standardni_typ
	| %empty
	;

standardni_typ:
	INTEGER
	| CHAR
	;

slozeny_prikaz:
	BEGIN_TOK volitelne_prikazy END
	;

volitelne_prikazy:
	seznam_prikazu
	| %empty
	;

seznam_prikazu:
	prikaz { if (last_ie) { gen_label(IEQ, TAIL); remove_label(IEQ, TAIL); last_ie = 0; } }
	| seznam_prikazu ';' prikaz { if (last_ie) { gen_label(IEQ, TAIL); remove_label(IEQ, TAIL); last_ie = 0; } }
	| seznam_prikazu error {  }
	| error {  }
	;

prikaz:
	promenna PRIRAZOVACI_OPERATOR vyraz	{ fprintf(icgf, "%s = %s\n", $1, $3); temp_num = 0; }
	| slozeny_prikaz
	| IF vyraz { add_label(IEQ, TAIL); ngt_label(IEQ, $2); } THEN prikaz { if (ieq_head && !ieq_head->is_goto) { add_label(IEQ, BEGIN); ieq_head->is_goto=1; } gt_label(IEQ); } else_cast { gt_label(IEQ); last_ie = 1; }  // gt_label() -> bere prvni label v seznamu, ngt_label() -> bere posledni label v seznamu, gen_label() bere posledni prvek v seznamu
	| WHILE { add_label(WQ, BEGIN); gen_label(WQ, BEGIN); } vyraz { add_label(WQ, TAIL); ngt_label(WQ, $3); } DO prikaz { gt_label(WQ); remove_label(WQ, BEGIN); gen_label(WQ, TAIL); remove_label(WQ, TAIL); last_ie = 0; }
	;

else_cast:
	ELSE { gen_label(IEQ, TAIL); remove_label(IEQ, TAIL); } prikaz
	| %empty { gen_label(IEQ, TAIL); remove_label(IEQ, TAIL); }
	;

promenna:
	ID;

vyraz:
	jednoduchy_vyraz	{ strcpy($$, $1); }
	| jednoduchy_vyraz RELACNI_OPERATOR jednoduchy_vyraz { fprintf(icgf, "T%llu = %s %s %s\n", temp_num, $1, $2, $3); snprintf($$, VAL_SIZE, "T%llu", temp_num); temp_num++; }
	;

jednoduchy_vyraz:
	terminalni_vyraz
	| jednoduchy_vyraz '+' terminalni_vyraz				{ fprintf(icgf, "T%llu = %s + %s\n", temp_num, $1, $3); snprintf($$, VAL_SIZE, "T%llu", temp_num); temp_num++; }
	| jednoduchy_vyraz '-' terminalni_vyraz				{ fprintf(icgf, "T%llu = %s - %s\n", temp_num, $1, $3); snprintf($$, VAL_SIZE, "T%llu", temp_num); temp_num++; }
	| jednoduchy_vyraz NEBO_OPERATOR terminalni_vyraz	{ fprintf(icgf, "T%llu = %s | %s\n", temp_num, $1, $3); snprintf($$, VAL_SIZE, "T%llu", temp_num); temp_num++; }
	;

terminalni_vyraz:
	faktor
	| terminalni_vyraz '*' faktor			{ fprintf(icgf, "T%llu = %s * %s\n", temp_num, $1, $3); snprintf($$, VAL_SIZE, "T%llu", temp_num); temp_num++; }
	| terminalni_vyraz '/' faktor			{ fprintf(icgf, "T%llu = %s / %s\n", temp_num, $1, $3); snprintf($$, VAL_SIZE, "T%llu", temp_num); temp_num++; }
	| terminalni_vyraz AND_OPERATOR faktor	{ fprintf(icgf, "T%llu = %s & %s\n", temp_num, $1, $3); snprintf($$, VAL_SIZE, "T%llu", temp_num); temp_num++; }
	| terminalni_vyraz DIV_OPERATOR faktor	{ fprintf(icgf, "T%llu = %s / %s\n", temp_num, $1, $3); snprintf($$, VAL_SIZE, "T%llu", temp_num); temp_num++; }
	| terminalni_vyraz MOD_OPERATOR faktor	{ fprintf(icgf, "T%llu = %s %% %s\n", temp_num, $1, $3); snprintf($$, VAL_SIZE, "T%llu", temp_num); temp_num++; }
	;

faktor:
	ID						{ strcpy($$, $1); }
	| NUM					{ fprintf(icgf, "T%llu = %s\n", temp_num, $1); snprintf($$, VAL_SIZE, "T%llu", temp_num); temp_num++; }
	| ZNAKOVA_KONSTANTA		{ fprintf(icgf, "T%llu = %s\n", temp_num, $1); snprintf($$, VAL_SIZE, "T%llu", temp_num); temp_num++; }
	| '(' vyraz ')'			{ strcpy($$, $2); }
	| '-' faktor			{ fprintf(icgf, "T%llu = -%s\n", temp_num, $2); snprintf($$, VAL_SIZE, "T%llu", temp_num); temp_num++; }
	| NOT_OPERATOR faktor	{ fprintf(icgf, "T%llu = NOT %s\n", temp_num, $2); snprintf($$, VAL_SIZE, "T%llu", temp_num); temp_num++; }
	;

%%


int yyerror(char* s)
{
	fprintf(stderr, "Syntax error: line %d\n", yylineno);
	return 0;
}


void add_label(const enum QType qtype, const enum Direction dir)
{
	struct Label** head = NULL;
	struct Label** tail = NULL;
	if (qtype == IEQ) {
		head = &ieq_head;
		tail = &ieq_tail;
	}
	else if (qtype == WQ){
		head = &wq_head;
		tail = &wq_tail;
	}

	if (*head == NULL)
	{
		*head = (struct Label*) calloc(1, sizeof(struct Label));
		(*head)->label = label_num;
		*tail = *head;
	}

	else
	{
		struct Label* l = (struct Label*) calloc(1, sizeof(struct Label));
		l->label = label_num;

		if (dir == BEGIN) 
		{  
			(*head)->prev = l;
			l->next = *head;
			*head = l;
		}
		else if (dir == TAIL)
		{
			l->prev = *tail;
			(*tail)->next = l;
			*tail = l;
		}
	}

	label_num++;
}


void remove_label(const enum QType qtype, const enum Direction dir)
{
	struct Label** head = NULL;
	struct Label** tail = NULL;
	if (qtype == IEQ) {
		head = &ieq_head;
		tail = &ieq_tail;
	}
	else if (qtype == WQ){
		head = &wq_head;
		tail = &wq_tail;
	}

	if (*head != NULL)
	{
		if (*head == *tail) 
		{
			free(*head);
			*head = *tail = NULL;
		}

		else
		{
			struct Label* l = NULL;
			if (dir == BEGIN)
			{
				l = *head;
				*head = (*head)->next;
				(*head)->prev = NULL;
				free(l);
			}
			else if (dir == TAIL)
			{
				l = *tail;
				*tail = (*tail)->prev;
				(*tail)->next = NULL;
				free(l);
			}
		}
	}
}


void gt_label(const enum QType qtype)
{
	struct Label* head = NULL;
	struct Label* tail = NULL;
	if (qtype == IEQ) {
		head = ieq_head;
		tail = ieq_tail;
	}
	else if (qtype == WQ) {
		head = wq_head;
		tail = wq_tail;
	}

	if (head != NULL)
	{
		fprintf(icgf, "goto L%llu\n", head->label);
	}
}

void ngt_label(const enum QType qtype, const char* str)
{
	struct Label* head = NULL;
	struct Label* tail = NULL;
	if (qtype == IEQ) {
		head = ieq_head;
		tail = ieq_tail;
	}
	else if (qtype == WQ){
		head = wq_head;
		tail = wq_tail;
	}

	if (head != NULL)
	{
		fprintf(icgf, "if not %s goto L%llu\n", str, tail->label);
	}
}


void gen_label(const enum QType qtype, const enum Direction dir)
{
	struct Label* head = NULL;
	struct Label* tail = NULL;
	if (qtype == IEQ) {
		head = ieq_head;
		tail = ieq_tail;
	}
	else if (qtype == WQ){
		head = wq_head;
		tail = wq_tail;
	}

	if (head != NULL)
	{
		if (dir == TAIL) {
			fprintf(icgf, "L%llu:\n", tail->label);
		}
		else if (dir == BEGIN) {
			fprintf(icgf, "L%llu:\n", head->label);
		}
	}
}


void clear_labels()
{
	struct Label* l = NULL;
	while (ieq_head != NULL)
	{
		l = ieq_head;
		ieq_head = ieq_head->next;
		free(l);
	}

	while (wq_head != NULL)
	{
		l = wq_head;
		wq_head = wq_head->next;
		free(l);
	}
}


int check_input_params(int argc, const char** argv)
{
	if (argc == 1)
	{
		printf("Pouziti: <jmeno spustitelneho souboru s prekladacem> <jmeno zdrojoveho souboru>\n");
		return 1;
	}

	if (argc > 2) 
	{
		fprintf(stderr, "Prilis mnoho parametru na vstupu\n");
		return -1;
	}

	return 0;
}

int redirect_input(const char* fname)
{
	int ifile_fd = open(fname, O_RDONLY);
	if (ifile_fd == -1)
	{
		fprintf(stderr, "Nepodarilo se otevrit soubor %s\n", fname);
		return -1;
	}
	
	if (close(STDIN_FILENO) == -1)
	{
		fprintf(stderr, "Nepodarilo se cist ze souboru %s\n", fname);
		close(ifile_fd);
		return -1;
	}
	
	if (dup2(ifile_fd, STDIN_FILENO) == -1)
	{
		fprintf(stderr, "Nepodarilo se presmerovat vstup!\n");
		close(ifile_fd);
		return -1;
	}
	
	close(ifile_fd);

	icgf = fopen(ICGF, "w");
	if (icgf == NULL)
	{
		fprintf(stderr, "Nepodarilo se vytvorit soubor pro TAC!\n");
		close(ifile_fd);
		return -1;
	}
	
	return 0;
}


int main(int argc, const char** argv)
{
#if YYDEBUG
  yydebug = 1;
#endif

	int res;
	if ((res = check_input_params(argc, argv)) == -1) {
		return 1;
	}
	else if (res == 1) {
		return 0;
	}

	if (redirect_input(argv[1]) == -1) {
		return 1;
	}

	if(!yyparse())
	{	
		#if YYDEBUG
			printf("End of input reached\n");
		#endif
	}

	clear_labels();
	fclose(icgf);
		
	return 0;
}

