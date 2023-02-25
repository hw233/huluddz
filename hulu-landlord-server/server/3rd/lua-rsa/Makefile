MODNAME=luarsa
MODSO=$(MODNAME).so
OBJS=luarsa.o
#version = 1.0

LUA_VERSION =   5.1

## Linux/BSD
PREFIX ?=          /home/develop/mj_h5/server/3rd/lua

LUA_INCLUDE_DIR ?= $(PREFIX)
LUA_LIB_DIR ?=     $(PREFIX)

OPENSSL_INC_DIR=/usr/include
OPENSSL_LIB_DIR=/usr/lib64


INSTALL ?= install
LUA ?= lua

CFLAGS = -c -Wall -fpic 
LDFLAGS = -shared -L$(OPENSSL_LIB_DIR)
.PHONY: all clean 

CC = gcc 
RM = rm -f

all: $(MODSO) 

%.o : %.c
	$(CC) $(CFLAGS) $< -o $@ -I$(LUA_INC_DIR) -I$(OPENSSL_INC_DIR)


$(MODSO): $(OBJS)
	$(CC) $(LDFLAGS) -o $@ $(OBJS) -lcrypto -lssl

install: 
	$(INSTALL) -d $(LUA_LIB_DIR)
	$(INSTALL) luarsa.so $(LUA_LIB_DIR)

clean:
	$(RM) *.so *.o
