# encoding: utf-8
#
# icon.rb: Prawn icon functionality.
#
# Copyright October 2014, Jesse Doyle. All rights reserved.
#
# This is free software. Please see the LICENSE and COPYING files for details.

require 'pathname'
require_relative 'icon/version'
require_relative 'icon/configuration'
require_relative 'icon/base'
require_relative 'icon/font_data'
require_relative 'icon/parser'
require_relative 'icon/interface'
require_relative 'icon/compatibility'

Prawn::Document.extensions << Prawn::Icon::Interface
