# On Windows, Sprockets' atomic_write uses `File.rename(tmpname, filename)`.
# Windows raises Errno::EACCES (Permission denied @ rb_file_s_rename) if `filename`
# already exists or is temporarily locked by another thread/antivirus scanner.
# This patch rescues Errno::EACCES so cache writes do not crash HTTP requests.

require 'sprockets/path_utils'

module SprocketsWindowsAtomicWriteFix
  def atomic_write(filename, temp_dir = Dir.tmpdir, &block)
    super(filename, temp_dir, &block)
  rescue Errno::EACCES, Errno::EPERM
    # Safe to ignore cache write race on Windows; the asset was still generated.
    nil
  end
end

Sprockets::PathUtils.prepend(SprocketsWindowsAtomicWriteFix)
Sprockets::PathUtils.singleton_class.prepend(SprocketsWindowsAtomicWriteFix)
