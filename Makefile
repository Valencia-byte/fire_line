JAVAC = javac
JAVA = java
JFLAGS = --release 11 -d bin
SOURCES = FirelineSerial.java FirelineParallel.java FireMap.java FireMapParallel.java FireTask.java TerrainType.java
ARGS ?= 300 300 42 wildfire output/fireline
JAVA_OPTS ?=
 
.PHONY: all run run-parallel clean
 
all:
	mkdir -p bin
	$(JAVAC) $(JFLAGS) $(SOURCES)
 
run-serial: all
	$(JAVA) -cp bin FirelineSerial $(ARGS)
 
run: all
	$(JAVA) $(JAVA_OPTS) -cp bin FirelineParallel $(ARGS)
 
clean:
	rm -rf bin output