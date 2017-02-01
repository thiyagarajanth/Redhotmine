# Ruby Holidays Gem

A set of functions to deal with holidays in Ruby.

Extends Ruby's built-in Date class and supports custom holiday definition lists.

## Installation

To install the gem from RubyGems:

    gem install holidays

The Holidays gem is tested on Ruby 1.8.7, 1.9.2, 1.9.3, 2.0.0, 2.1.0, REE and JRuby.

## Time zones

Time zones are ignored.  This library assumes that all dates are within the same time zone.

## Examples

For more information, see the notes at the top of the Holidays module.

### Using the Holidays class

Get all holidays on April 25, 2008 in Australia.

    date = Date.civil(2008,4,25)

    Holidays.on(date, :au)
    => [{:name => 'ANZAC Day',...}]

Get holidays that are observed on July 2, 2007 in British Columbia, Canada.

    date = Date.civil(2007,7,2)

    Holidays.on(date, :ca_bc, :observed)
    => [{:name => 'Canada Day',...}]

Get all holidays in July, 2008 in Canada and the US.

    from = Date.civil(2008,7,1)
    to = Date.civil(2008,7,31)

    Holidays.between(from, to, :ca, :us)
    => [{:name => 'Canada Day',...}
        {:name => 'Independence Day',...}]

Get informal holidays in February.

    from = Date.civil(2008,2,1)
    to = Date.civil(2008,2,15)

    Holidays.between(from, to, :informal)
    => [{:name => 'Valentine\'s Day',...}]

### Extending Ruby's Date class

Check which holidays occur in Iceland on January 1, 2008.

    d = Date.civil(2008,7,1)

    d.holidays(:is)
    => [{:name => 'Nýársdagur'}...]

Lookup Canada Day in different regions.

    d = Date.civil(2008,7,1)

    d.holiday?(:ca) # Canada
    => true

    d.holiday?(:ca_bc) # British Columbia, Canada
    => true

    d.holiday?(:fr) # France
    => false

### How to contribute

To make changes to any of the definitions, edit the YAML files only.

Tests are also added at the end of the YAML files. Please add tests, it makes the pull requests go around.

After you're satisfied with the YAML file, edit the index.yaml file, run `rake generate`, which will generate the Ruby files that make up the actual code as well as the tests.  Then run `rake test`.

It is also very appreciated if documentation is attached to the pull request.  A simple Wikipedia or government link referencing the change would be perfect.

### Credits and code

* Source: https://github.com/alexdunae/holidays
* Docs: http://rdoc.info/github/alexdunae/holidays/master/frames
* Contributors: https://github.com/alexdunae/holidays/contributors
* Build status: http://travis-ci.org/#!/alexdunae/holidays

Started by [Alex Dunae](http://dunae.ca) (e-mail 'code' at the same domain), 2007-12.
Maintained by [Hana Wang](https://github.com/hahahana), 2013

On Twitter: @MrMrBug.

Made on Vancouver Island. Maintained in the way more beautiful Houston, TX.
