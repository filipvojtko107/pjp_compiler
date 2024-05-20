CC = gcc
CFLAGS =
LEX = flex
BISON = bison
LDLIBS = -lfl

# pjp
PJP_L_SRC = pjp.l
PJP_Y_SRC = pjp.y
PJP_LL_SRC := $(patsubst %.l, %.yy.c, $(PJP_L_SRC))
PJP_YY_SRC := $(patsubst %.y, %.tab.c, $(PJP_Y_SRC))
TARGET_PJP = pjp


TARGETS = $(TARGET_PJP)

.PHONY: all
all: $(TARGETS)


$(TARGET_PJP): $(PJP_YY_SRC) $(PJP_LL_SRC)
	$(CC) $(CFLAGS) $^ -o $@ $(LDLIBS)
	
%.tab.c: %.y
	$(BISON) -d -o $@ $<


%.yy.c: %.l
	$(LEX) -o $@ $<
	
	
.PHONY: clean
clean:
	rm -f *.yy.c
	rm -f *.tab.h
	rm -f *.tab.c
	rm -f *.tac
	rm -f $(TARGETS)
	
	
