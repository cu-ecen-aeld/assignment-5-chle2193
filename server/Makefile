CC = $(CROSS_COMPILE)gcc

#CFLAGS = -Wall -Werror -std=c99 -g

CFLAGS =  -g

TARGET = aesdsocket

SOURCES = aesdsocket.c

OBJECTS = $(SOURCES:.c=.o)

all: $(TARGET)

$(TARGET): $(OBJECTS)
	$(CC) $(CFLAGS) $(OBJECTS) -o $(TARGET)

%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

clean:
	rm -f $(TARGET) $(OBJECTS)

.PHONY: all clean