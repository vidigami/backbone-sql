Please refer to the following release notes when upgrading your version of BackboneSQL.

### 0.5.10
* Simplified database_tools and made compatible with the latest knex.

### 0.5.9
* Update knex due to bluebird dependency breaking.

### 0.5.8
* Fix for $ne: null in find queries

### 0.5.7
* Compatability fix for Backbone 1.1.1

### 0.5.6
* Knex bug fix for count
* Lock Backbone.js to 1.1.0 until new release compatibility issues fixed

### 0.5.5
* Updated to latest Knex (still outstanding problems with consistent Date support in Knex - not all mysql sqlite tests passing for dates)

### 0.5.4
* $nin bug fix

### 0.5.3
* $nin support

### 0.5.2
* Handle null hasMany relations in _joinedResultsToJSON

### 0.5.1
* db.ensureSchema not complain when running lots of operations

### 0.5.0
* Initial release
