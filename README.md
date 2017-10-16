# pony-spooked

pony-spooked is a Neo4j Bolt driver for the Pony programming language.

## Status

[![Build Status](https://travis-ci.org/patternspandemic/pony-spooked.svg?branch=master)](https://travis-ci.org/patternspandemic/pony-spooked)

Development of pony-spooked has only just begun.

## Installation

* Install [pony-stable](https://github.com/ponylang/pony-stable)
* Update your `bundle.json`

```json
{ 
  "type": "github",
  "repo": "patternspandemic/pony-spooked"
}
```

* `stable fetch` to fetch your dependencies
* `use "spooked"` to include this package
* `stable env ponyc` to compile your application
