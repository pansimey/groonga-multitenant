require 'active_model'
require 'active_support/inflector'
require 'active_support/time'
require 'groonga/client/multiple_databases'
require 'groonga/multitenant/tenant'
require 'groonga/multitenant/client'
require 'groonga/multitenant/base'
require 'groonga/multitenant/relation'
require 'groonga/multitenant/version'

GM = Groonga::Multitenant