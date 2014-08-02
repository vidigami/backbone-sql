_ = require 'underscore'
es = require 'event-stream'

Async = require 'async'
gulp = require 'gulp'
gutil = require 'gulp-util'
coffee = require 'gulp-coffee'
mocha = require 'gulp-spawn-mocha'

gulp.task 'build', buildLibraries = ->
  return gulp.src('./src/**/*.coffee')
    .pipe(coffee({header: true})).on('error', gutil.log)
    .pipe(gulp.dest('./lib'))

gulp.task 'watch', ['build'], ->
  return gulp.watch './src/**/*.coffee', -> buildLibraries()

MOCHA_DATABASE_OPTIONS =
  postgres: {require: ['test/parameters_postgres', 'backbone-rest/test/parameters_express4'], env: {NODE_ENV: 'test'}}
  mysql: {require: ['test/parameters_mysql', 'backbone-rest/test/parameters_express4'], env: {NODE_ENV: 'test'}}
  sqlite3: {require: ['test/parameters_sqlite3', 'backbone-rest/test/parameters_express4'], env: {NODE_ENV: 'test'}}

testFn = (options={}) -> (callback) ->
  tags = ("@#{tag.replace(/^[-]+/, '')}" for tag in process.argv.slice(3)).join(' ')
  gutil.log "Running tests for #{options.protocol} #{tags}"

  gulp.src([
      "node_modules/backbone-orm/test/{issues,spec/sync}/**/*.tests.coffee"
      "#{if tags.indexOf('@quick') >= 0 then '' else '{node_modules/backbone-rest/,}'}test/spec/**/*.tests.coffee"
    ])
    .pipe(mocha(_.extend({reporter: 'dot', grep: tags}, MOCHA_DATABASE_OPTIONS[options.protocol])))
    .pipe es.writeArray callback
  return # promises workaround: https://github.com/gulpjs/gulp/issues/455

gulp.task 'test', ['build'], (callback) ->
  Async.series (testFn({protocol: protocol}) for protocol of MOCHA_DATABASE_OPTIONS), callback
  return # promises workaround: https://github.com/gulpjs/gulp/issues/455
gulp.task 'test-postgres', ['build'], testFn({protocol: 'postgres'})
gulp.task 'test-mysql', ['build'], testFn({protocol: 'mysql'})
gulp.task 'test-sqlite3', ['build'], testFn({protocol: 'sqlite3'})

# gulp.task 'benchmark', ['build'], (callback) ->
#   (require './test/lib/run_benchmarks')(callback)
#   return # promises workaround: https://github.com/gulpjs/gulp/issues/455
