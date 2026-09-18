# Sprockets builds `file-digest://` URIs containing the absolute project path.
# When that path contains a raw space (e.g. "/home/user/docs backup/..."),
# Ruby's RFC 3986 URI parser rejects it. Patch the URI helpers to percent-encode
# spaces before parsing.
#
# Safe to remove once the project is moved to a path without spaces.

require 'sprockets/uri_utils'

module SprocketsSpaceInPathFix
  def split_file_uri(uri)
    super(uri.to_s.gsub(' ', '%20'))
  end

  def parse_file_digest_uri(uri)
    super(uri.to_s.gsub(' ', '%20'))
  end

  def parse_asset_uri(uri)
    super(uri.to_s.gsub(' ', '%20'))
  end
end

Sprockets::URIUtils.singleton_class.prepend(SprocketsSpaceInPathFix)
Sprockets::URIUtils.prepend(SprocketsSpaceInPathFix)
Rails.logger.info("[sprockets_space_in_path_fix] patch applied: #{Sprockets::URIUtils.singleton_class.ancestors.first(3).inspect}") if defined?(Rails.logger)
