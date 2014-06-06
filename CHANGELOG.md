# Changes

## v0.3.1

* Add CodeClimate badge to `README.md`.
* Correct email address in `README.md` and `code_statistics.gemspec`.
* Switch to secure RubyGems URL.
* Rename gem to `code_counter` so it can be published to RubyGems.
* Improve documentation generation.
* Remove use of `test-construct` in favor of simpler fixture directories.
* Switch to `rspec`.
* Begin adding tests for CLI.
* Fix an uninitialized variable bug.
* Paths listed in `ADDITIONAL_SOURCE_DIRECTORIES` don't need to be relative to
  the current directory anymore.
* Add support for `.rake` files.
* Add support for files with arbitrary extensions in binary directories.
* Make `bin`, `script`, and `scripts` be binary directories by default.
* Add `ADDITIONAL_BINARY_DIRECTORIES` var for adding binary directory mappings
  to the CLI.


## v0.3.0

* Modernize project to work well with newer Rake, and in the world of Bundler.
* Formalize development environment, and fix broken tasks.
* Don't leave file handles open needlessly.
* Make all path additions recursive.  (Incl. allowing more-specific
  definitions earlier on to override definitions later on...)
* Allow specifying multiple paths to be grouped into one line item.
* Normalized mechanism for configuring things.
* Substantially simplify code.
* Add a proper changelog.
* Don't add development-dependencies to gem; let people use `git clone` for
  that.
* Improve Cucumber support by treating `Given`/`When`/`Then` matcher blocks as
  methods.  (Analogous to how `should`/`it` methods were already treated.)
* Reduce namespace pollution in both `rake` task namespace, and Ruby global
  namespace.


## v0.2.13

* Initial fork from devver's repo.
