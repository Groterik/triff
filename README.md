# triff
Tree diff library and tools.

# Building
Run ```dub build``` for building project as library.
Run ```dub build --config=diff-dirs``` or ```dub build --config=diff-json```
to build tools for producing directories entries diff or json entries diff.

#Usage
User defined tree nodes must implement the minimal generic interface, i.e. ```isDiffNode(T) == true```.
Node must have method ```label()``` and method ```children()``` with iterable result. 
As a result of ```diff``` function array of ```Operation``` will be created that describes the sequence
of operation for transforming firts tree to the second one.
