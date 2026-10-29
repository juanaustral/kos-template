#!/usr/bin/env ruby
# encoding: utf-8
# Prueba del pre-push: un push normal pasa; force y borrado de rama se bloquean.
require "tmpdir"
require "open3"
require "fileutils"
root = File.expand_path("..", __dir__)
fallas = []
def sh(dir, *cmd) = Open3.capture2e(*cmd, chdir: dir)
Dir.mktmpdir do |t|
  remoto = File.join(t, "remoto.git")
  a = File.join(t, "a")
  sh(t, "git", "init", "-q", "--bare", "-b", "main", remoto)
  sh(t, "git", "init", "-q", "-b", "main", a)
  FileUtils.mkdir_p(File.join(a, "tools"))
  FileUtils.cp_r(File.join(root, "tools/hooks"), File.join(a, "tools/hooks"))
  [%w[config user.name t], %w[config user.email t@t], %w[config core.hooksPath tools/hooks], ["remote", "add", "origin", remoto]].each { |c| sh(a, "git", *c) }
  commit = ->(n) { File.write(File.join(a, "f.txt"), n); sh(a, "git", "add", "f.txt"); sh(a, "git", "commit", "-q", "-m", n) }
  commit.("1"); commit.("2")
  _, st = sh(a, "git", "push", "-q", "origin", "main")
  fallas << "push normal bloqueado" unless st.success?
  commit.("3")
  _, st = sh(a, "git", "push", "-q", "origin", "main")
  fallas << "push que avanza bloqueado" unless st.success?
  sh(a, "git", "reset", "-q", "--hard", "HEAD~2"); commit.("otro")
  out, st = sh(a, "git", "push", "-q", "--force", "origin", "main")
  fallas << "force push NO bloqueado" if st.success?
  fallas << "mensaje sin explicar" unless out.include?("necesita la aprobación")
  sh(a, "git", "push", "-q", "origin", "main:rama2") # rama nueva: permitida (se crea antes de probar el borrado)
  _, st = sh(a, "git", "push", "origin", ":rama2")
  fallas << "borrado de rama NO bloqueado" if st.success?
  _, st = sh(a, "git", "push", "--no-verify", "--force", "origin", "main")
  fallas << "--no-verify del titular no funciona" unless st.success?
end
if fallas.empty? then puts "hooks_test: OK (5 casos)"; exit 0
else puts "hooks_test FALLÓ:\n- #{fallas.join("\n- ")}"; exit 1 end
