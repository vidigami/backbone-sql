#!/bin/sh

set -e
# for database_parameter in test/parameters_* ; do
for database_parameter in test/parameters_postgres test/parameters_mysql ; do
  for app_framework_parameter in node_modules/backbone-rest/test/parameters_* ; do
    echo node_modules/.bin/mocha --require \""$database_parameter"\" --require \""$app_framework_parameter"\" \''node_modules/backbone-rest/test/spec/**/*.tests.coffee'\' --grep \'\'
    node_modules/.bin/mocha --require "$database_parameter" --require "$app_framework_parameter" 'node_modules/backbone-rest/test/spec/**/*.tests.coffee' --grep ''
  done
done
