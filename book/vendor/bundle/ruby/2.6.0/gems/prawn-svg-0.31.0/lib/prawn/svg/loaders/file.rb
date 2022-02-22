require 'addressable/uri'

#
# Load a file from disk.
#
# WINDOWS
# =======
# Windows is supported, but must use URLs in the modern structure like:
#   file:///x:/path/to/the/file.png
# or as a relative path:
#   directory/file.png
# or as an absolute path from the current drive:
#   /path/to/the/file.png
#
# Ruby's URI parser does not like backslashes, nor can it handle filenames as URLs starting
# with a drive letter as it thinks you're giving it a scheme.
#
# URL ENCODING
# ============
# This module assumes the URL that is passed in has been URL-encoded.  If for some reason
# you're passing in a filename that hasn't been taken from an XML document's attribute,
# you will want to URL encode it before you pass it in.
#
# FILES READ AS BINARY
# ====================
# At the moment, prawn-svg uses this class only to load graphical files, which are binary.
# This class therefore uses IO.binread to read file data.  If it is ever used in the future
# to load text files, it will have to be taught about what kind of file it's expecting to
# read, and adjust the file read function accordingly.
#
module Prawn::SVG::Loaders
  class File
    attr_reader :root_path

    def initialize(root_path)
      if root_path.empty?
        raise ArgumentError, "An empty string is not a valid root path.  Use '.' if you want the current working directory."
      end

      @root_path = ::File.expand_path(root_path)

      raise ArgumentError, "#{root_path} is not a directory" unless Dir.exist?(@root_path)
    end

    def from_url(url)
      uri = build_uri(url)

      if uri && uri.scheme.nil? && uri.path
        load_file(uri.path)

      elsif uri && uri.scheme == 'file'
        assert_valid_file_uri!(uri)
        path = windows? ? fix_windows_path(uri.path) : uri.path
        load_file(path)
      end
    end

    private

    def load_file(path)
      path = Addressable::URI.unencode(path)
      path = build_absolute_and_expand_path(path)
      assert_valid_path!(path)
      assert_file_exists!(path)
      IO.binread(path)
    end

    def build_uri(url)
      begin
        URI(url)
      rescue URI::InvalidURIError
      end
    end

    def assert_valid_path!(path)
      # TODO : case sensitive comparison, but it's going to be a bit of a headache
      # making it dependent on whether the file system is case sensitive or not.
      # Leaving it like this until it's a problem for someone.

      if !path.start_with?("#{root_path}#{::File::SEPARATOR}")
        raise Prawn::SVG::UrlLoader::Error, "file path is not inside the root path of #{root_path}"
      end
    end

    def build_absolute_and_expand_path(path)
      ::File.expand_path(path, root_path)
    end

    def assert_valid_file_uri!(uri)
      unless uri.host.nil? || uri.host.empty?
        raise Prawn::SVG::UrlLoader::Error, "prawn-svg does not suport file: URLs with a host. Your URL probably doesn't start with three slashes, and it should."
      end
    end

    def assert_file_exists!(path)
      if !::File.exist?(path)
        raise Prawn::SVG::UrlLoader::Error, "File #{path} does not exist"
      end
    end

    def fix_windows_path(path)
      if matches = path.match(%r(\A/[a-z]:/)i)
        path[1..-1]
      else
        path
      end
    end

    def windows?
      !!(RbConfig::CONFIG['host_os'] =~ /mswin|msys|mingw|cygwin|bccwin|wince|emc/)
    end
  end
end
