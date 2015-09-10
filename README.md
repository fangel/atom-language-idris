# A Idris Mode for Atom

A work-in-progress Idris Mode for Atom.

It supports:

 - Typechecking (ctrl-alt-r)
 - Case-splitting (ctrl-alt-c)
 - Clause-adding (ctrl-alt-a)
 - Proof-search (ctrl-alt-s)
 - Showing the types of a variable (ctrl-alt-t)
 - Show the doc for a variable (ctrl-alt-d)
 - make-with (ctrl-alt-w)
 - make-case (ctrl-alt-m)
 - make-lemma (ctrl-alt-l)
 - Showing holes

## Usage

The package should work after installation. The only thing you might need to
set is the path to the `idris` executable in the config of this package.
If it doesn't work it's probably a bug.

There is a tutorial on how to use the editor under [`documentation/tutorial.md`](https://github.com/idris-hackers/atom-language-idris/blob/master/documentation/tutorial.md).

## Todo

 - Add better support for drawing attention to error-messages
 - Improve the syntax-highlighting (the current is based on the Sublime plugin)
 - Add autocompletion
 - Add a REPL
 - ...

## Development

To work on this plugin you need to clone it into your atom directory
and rename the folder to `language-idris` or the package settings won't get picked up.
Then you need an `apm install` from the `language-idris` folder to install the dependencies.


## Books

[Type-Driven Development with Idris](https://www.manning.com/books/type-driven-development-with-idris) by Edwin Brady (Manning Publications). [Chapter 1](https://manning-content.s3.amazonaws.com/download/8/99b07b5-ad1d-4272-860b-c323b3f5bf4c/Brady_TDDwithIdris_MEAP_ch1.pdf)
