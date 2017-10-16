build/spooked: build spooked/*.pony
	ponyc spooked -o build --debug

build:
	mkdir build

test: build/spooked
	build/spooked

clean:
	rm -rf build

.PHONY: clean test
