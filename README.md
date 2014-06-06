# code_counter

This is a port of the rails 'rake stat' so it can be used on none rails
projects and have it's features slowly expanded. Please feel free to contact us
if you have any ideas for additional stats that should be added. It in general
tries to have defaults that work better for both rails and non rails projects.
It specifically supports cucumber tests and rspec better than the original
rails stats.


## Requirements

This project requires Ruby 1.9.x or higher.


## Usage

### Rake

Add this to the bottom of your `Rakefile`:

```ruby
require 'code_counter'
```

Then, when you run `rake -T` you'll see a stats task, unless you already had
one defined.  If you have an existing task named `stats`, and want to use this
one, simply make a task of a new name that depends on the `code_counter`
task, like so:

```ruby
task :new_stats => :code_counter
```

To configure the task:

```ruby
task :stats_configuration do
  CodeCounter::Engine.clear!
  CodeCounter::Engine.init!

  # By default, this will recursively add the specified path, and only look for
  # files ending in `.rb`, `.rake`, or `.feature`.
  CodeCounter::Engine.add_path("Some Group", "some/path")

  # Don't add recursively:
  CodeCounter::Engine.add_path("Some Group", "other/path", false)

  # Add recursively, and don't filter by file extension:
  CodeCounter::Engine.add_path("Some Group", "my/script/dir", true, true)
end

# Add a dependency on our config task here so that our config gets loaded when
# we run `rake stats`.
task :code_counter => :stats_configuration
```


### CLI

```bash
code_counter
```

Additionally, you can configure things using some environment variables:

* `ADDITIONAL_SOURCE_DIRECTORIES`: A comma-separated list of directories to
  scan for source files.  You may assign a directory to a named group by
  prefixing the path with a group name and colon.  E.G. `ADDITIONAL_SOURCE_DIRECTORIES='Libraries:my_awesome_code'`
* `ADDITIONAL_BINARY_DIRECTORIES`: A comma-separated list of directories to
  scan for binaries.  You may assign a directory to a named group by prefixing
  the path with a group name and colon.  E.G. `ADDITIONAL_BINARY_DIRECTORIES='Binaries:my_awesome_scripts'`
* `IGNORE_FILE_GLOBS`: A comma-separated list of file globs to ignore.


## TODOs

* make bin accept passed cmd line arguments to run
* stop relying on ENV vars
* count number of total files
* count number of of .rb or passed in filter files
* find todo, perf, bug, hack, etc comments and display them with info about
  them (line number etc)
* reduce duplication between bin and task

[jfrisby@mrjoy.com](mailto:jfrisby@mrjoy.com)


## Note on Patches/Pull Requests

* Fork the project.
* Make your feature addition or bug fix.
* Add tests for it. This is important so I don't break it in a future version
  unintentionally.
* Commit, do not mess with rakefile, version, or history.  (if you want to have
  your own version, that is fine but bump version in a commit by itself I can
  ignore when I pull)
* Send me a pull request. Bonus points for topic branches.


## Copyright

Distributed under the MIT license.  See LICENSE.md for details, including
authorship/ownership.
