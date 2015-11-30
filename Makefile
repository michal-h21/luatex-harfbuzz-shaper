PKGS = harfbuzz

CFLAGS = `pkg-config --cflags $(PKGS)` `pkg-config --cflags lua`
LDFLAGS = `pkg-config --libs $(PKGS)`

UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Linux)
	LIBFLAGS = -shared 
	STD = --std=gnu99
endif
ifeq ($(UNAME_S),Darwin)
	STD = 
	LIBFLAGS = -dynamiclib -undefined dynamic_lookup
endif

all: luaharfbuzz.so

luaharfbuzz.o: luaharfbuzz.c
	$(CC) -O2 -fpic $(CFLAGS) $(STD) -c luaharfbuzz.c
 
luaharfbuzz.so: luaharfbuzz.o
	$(CC) -O2 -fpic $(LDFLAGS) $(LIBFLAGS) -o luaharfbuzz.so luaharfbuzz.o

test: all
	lua harfbuzz_test.lua notonastaliq.ttf "یہ"

