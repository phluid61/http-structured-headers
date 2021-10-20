
HTTP Structured Headers
=======================

An implementation of the algorithms specified in [RFC 8941][RFC8941].

This implementation is not the most efficient or necessarily the most sensible,
instead it is as close as I could get to writing the algorithms from the RFC
directly into Ruby.  This was useful in debugging the algorithms as they were
being written.

Includes a copy of a simple Base32 library I wrote.

The linked `tests` submodule defines a standard corpus of cases against which
implementations like this can test.  See the [structured-header-tests repository][tests].

[RFC8941]: https://datatracker.ietf.org/doc/html/rfc8941
[tests]: https://github.com/httpwg/structured-header-tests/

