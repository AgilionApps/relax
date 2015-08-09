# Changelog

## v0.2.2

* Bugfixes:
  * Ensure defining one filter does not override default filter behaviour.

## v0.2.1

* Bugfixes:
  * Fixed ecto dependency when compiling for production.

## v0.2.0

* *Backwards Incompatable changes*
  * Rename `find_all` and `find_one` to `fetch_all` and `fetch_one`.
  * Remove support for `find_many`.
  * Plug.Builder used by default, not Plug.Router.
  * Nested resources now available as filter[parent] instead of just parent.
* Features
  * Adds ecto dependency
  * Actions now can return Ecto.Query and Ecto.Changeset structs instead of conns.
  * `fetchable` added to dry up `fetch_all` and `fetch_one` common overlap.
  * Permitted params added for whitelisting attributes and relationships.
  * Filterable index.

## v0.1.0

* *Backwards Incompatable changes*
  * Move serialization to it's own library JaSerializers
* Features
  * jsonapi.org 1.0 compliance.

## v0.0.2

* Bug fixes

## v0.0.1

* Initial release of relax.
* jsonapi.org RC1 compliance.
