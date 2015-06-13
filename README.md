# A Idris Mode for Atom

A work-in-progress Idris Mode for Atom.

It supports:

 - Case-splitting (ctrl-alt-a s)
 - Clause-adding (ctrl-alt-a a)
 - Proof-search (ctrl-alt-a p)
 - Showing the types of variables (ctrl-alt-a t)
 - Show the doc of a variable (ctrl-alt-a d)

## Usage

The package should work after installation. The only thing you might need to
set is the path to the `idris` executable in the config of this package.
If it doesn't work it's probably a bug.

There is a tutorial on how to use the editor under [`documentation/tutorial.md`](https://github.com/idris-hackers/atom-language-idris/blob/master/documentation/tutorial.md).

## Todo

 - Add better support for drawing attention to error-messages
 - Improve the syntax-highlighting (the current is base on the Sublime plugin)
 - Add autocompletion
 - Add a REPL
 - ...

## Development

To work on this plugin you need to clone it into your atom directory
and rename the folder to `language-idris` or the package settings won't get picked up.
Then you need an `apm install` from the `language-idris` folder to install the dependencies.
