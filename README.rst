bookme
======

A handy helper for acquiring the textbooks made `freely available by Springer`__ during Covid 19

__ https://link.springer.com/search?package=mat-covid19_textbooks&facet-content-type=%22Book%22&showAll=false

.. note:: At this time, all but one of Springer's Covid 19 package of books has
   been made unavailable, so this isn't as useful as it once was.
   But this project does still facilitate access to Springer's Open Access collection.

.. code:: console

  $ ./bookme.zsh -h
  Usage: bookme [--procs <number of simultaneous downloads>] [--format epub|pdf|both] [--folder <path>] [<textbooks.csv>]
  $ ./bookme.zsh

Just run it without arguments for interactive menus.

.. image:: https://gist.githubusercontent.com/AndydeCleyre/8fd1110b324df7d5ab84454d14f2b86e/raw/926a65e3ced0c871999fa03b0a1ef33bbd3d52e1/bookme.svg?sanitize=true

Dependencies
------------

- fzf>=0.19.0
- GNU wget
- zsh

On macOS? I recommend installing homebrew__ and running:

.. code:: console

  $ brew install fzf wget

__ https://brew.sh/
