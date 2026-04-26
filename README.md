- [Introduction](#orga462d10)
- [Reading Keys](#org64156e4)
- [Alerts](#org38ad970)

#+PROPERTY: header-args:ruby :results value :colnames no :hlines yes :exports both :dir "./"
#+PROPERTY: header-args:ruby+ :wrap example :session fatty_session :eval yes
#+PROPERTY: header-args:ruby+ :prologue "$:.unshift('./lib') unless $:.first == './lib'; require 'fatty'"
#+PROPERTY: header-args:ruby+ :ruby "bundle exec irb"
#+PROPERTY: header-args:sh :exports code :eval no
#+PROPERTY: header-args:bash :exports code :eval no

[![CI](https://github.com/ddoherty03/fatty/actions/workflows/main.yml/badge.svg?branch=master)](https://github.com/ddoherty03/fatty/actions/workflows/main.yml)


<a id="orga462d10"></a>

# Introduction


<a id="org64156e4"></a>

# Reading Keys

Shift/Ctrl/Meta F-keys are normalized when ncurses provides distinct constants.


<a id="org38ad970"></a>

# Alerts

Alerts are short-lived, non-scrolling messages shown below the input line. They are intended for user-visible conditions that require attention.
