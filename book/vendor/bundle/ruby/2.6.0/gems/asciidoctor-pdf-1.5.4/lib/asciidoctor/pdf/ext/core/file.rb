# frozen_string_literal: true

class File
  # NOTE: remove once minimum required Ruby version is at least 2.7
  def self.absolute_path? path
    (::Pathname.new path).absolute?
  end unless respond_to? :absolute_path?
end
