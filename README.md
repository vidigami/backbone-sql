![logo](https://github.com/vidigami/backbone-sql/raw/master/media/logo.png)

PostgreSQL, MySQL, and SQLite3 storage for BackboneORM.

[BackboneSQL](http://vidigami.github.io/backbone-orm/backbone-http.html) provides an interface for [BackboneORM](http://vidigami.github.io/backbone-orm) models to persist to SQL databases.

Please [checkout the website](http://vidigami.github.io/backbone-orm/) for examples, documentation, and community!

### Schema definition

Fields are specified in the models `schema` property. Each (non-relation) field corresponds to a database column.

Each field must have a type and may be provided with the additional options.

An auto-incrementing field named `id` is automatically created as the primary key for each model.

To supply options the field descriptor is passed as an array, with the first item being the field type and a settings object
as the second.

#### Available types
All types supported by [Knex](http://knexjs.org/#Schema-increments) are available. Add column specific options along
with the settings object for the field.
The first letter of the type name is optionally capitalized, while the remainder must be camelCase.

#### Common field options
These options may be applied to any field. Note that column options are currently only applied when the columns are created.

* `nullable`: Defaults to `true`. Set to false to throw an error on null values.
* `indexed`: Defaults to `false`. Set to true to create an index on the column.
* `unique`: Defaults to `false`. Set to true to create a unique constraint on the column.

###### CoffeeScript schema example

```coffeescript
SQLSync = require('backbone-sql').sync

class Project extends Backbone.Model

  # Database connection and table name are specified with the urlRoot
  urlRoot: 'postgres://username:password@localhost:27017/my_database/projects'

  # Schema defines the fields for the model's table
  schema:
    created_at: 'DateTime'
    type: ['Integer', nullable: false]
    name: ['String', unique: true, indexed: true]

  # Kick it off by setting the model's sync to an SQLSync
  sync: SQLSync(Project)
```

###### JavaScript schema example

```javascript
var SQLSync = require('backbone-sql').sync;

var Project = Backbon.Model.extend({

  // Database connection and table name are specified with the urlRoot
  urlRoot: 'postgres://username:password@localhost:27017/projects',

  // Schema defines the fields for the model's table
  schema: {
    created_at: 'DateTime',
    type: ['Integer', {nullable: false}],
    name: ['String', {unique: true, indexed: true}]
  }
});

// Kick it off by setting the model's sync to an SQLSync
Project.prototype.sync = SQLSync(Project);
```

### For Contributors

To build the library for Node.js:

```
$ npm run
```

Please run tests before submitting a pull request.

```
$ npm test
```
