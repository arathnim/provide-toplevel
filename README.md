# provide-toplevel
Provides a hook for accessing lisp code from the toplevel, before any macroexpansion. Works both in the repl and loading files.

Currently only works on sbcl, might port to other implementations if the need arises.

## usage
`add-hook [provide-toplevel] function`

The given function must take a single argument, and returns the modified s-expr.

Hooks pushed on to the list later are called first. Modify `provide-toplevel::*toplevel-hooks*` if this becomes an issue.

## dependencies and installation

This project requires quicklisp to run.
To install quicklisp, head over to [quicklisp's website](https://www.quicklisp.org/beta/) and follow 
the instructions there. Make sure you run `(ql:add-to-init-file)`, otherwise quicklisp won't be avaliable 
when you start your interpreter.

To use it, clone this repo into `~/quicklisp/local-projects`, and run `(ql:quickload 'provide-toplevel)`.
