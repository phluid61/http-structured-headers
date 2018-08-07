
HTTP Structured Headers
=======================

An implementation of the algorithms specified in [draft-ietf-httpbis-header-structure]

Includes a copy of a simple Base32 library I wrote.

The linked `tests` submodule defines a standard corpus of cases against which
implementations like this can test.  See the [structured-header-tests repository][tests].

[draft-ietf-httpbis-header-structure]: https://tools.ietf.org/html/draft-ietf-httpbis-header-structure
[tests]: https://github.com/httpwg/structured-header-tests/

To Do
-----

- [x] more custom types to wrap native types returned by parsers (and accepted by serialisers)
- [x] change 'binary.json' test exception; insetad Base32 when unwrapping binary wrapper ''

