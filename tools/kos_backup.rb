#!/usr/bin/env ruby
# encoding: utf-8
Encoding.default_external = Encoding::UTF_8
ARGV.map! { |a| a.dup.force_encoding(Encoding::UTF_8) }

# kos_backup.rb — Respaldo verificable de KOS.
#
# Uso:
#   ruby tools/kos_backup.rb [RAIZ] [DESTINO]
#       Crea <DESTINO>/kos-<fecha>.tar.gz (por defecto en backups/) y su SHA256.
#       Si KOS está en Git, el respaldo incluye kos-historial.bundle con todo el historial
#       (para recuperarlo: git clone kos-historial.bundle kos).
#   ruby tools/kos_backup.rb --verify <respaldo.tar.gz>
#       Comprueba el SHA256, extrae a un directorio temporal y corre el validador sobre la copia.

require "pathname"
require "fileutils"
require "digest"
require "time"
require "tmpdir"
require "open3"

def sha256(path) = Digest::SHA256.file(path).hexdigest

if ARGV[0] == "--verify"
  bundle = Pathname.new(ARGV[1].to_s).expand_path
  abort "No existe el respaldo: #{bundle}" unless bundle.file?
  sums = Pathname.new("#{bundle}.sha256")
  if sums.file?
    abort "El respaldo no coincide con su SHA256 (alterado o incompleto)." unless sha256(bundle) == sums.read.split(/\s+/).first
  else
    puts "Aviso: no hay archivo .sha256; solo se prueba la extracción."
  end
  Dir.mktmpdir("kos-restore-") do |tmp|
    abort "No se pudo extraer el respaldo." unless system("tar", "-xzf", bundle.to_s, "-C", tmp)
    stdout, _stderr, status = Open3.capture3("ruby", File.join(tmp, "tools/kos_validate.rb"), tmp)
    puts stdout
    abort "La restauración no pasa la validación." unless status.success?
    hist = File.join(tmp, "kos-historial.bundle")
    if File.file?(hist)
      abort "El historial de Git del respaldo está dañado." unless system("git", "bundle", "verify", "-q", hist, out: File::NULL, err: File::NULL)
      puts "Historial de Git: OK"
    end
    puts "RESTAURACIÓN OK — #{bundle.basename} se extrae y valida."
  end
  exit 0
end

root = Pathname.new(ARGV.shift || ".").expand_path
dest = Pathname.new(ARGV.shift || root.join("backups")).expand_path
FileUtils.mkdir_p(dest)
ENV["COPYFILE_DISABLE"] = "1"
stamp = Time.now.strftime("%Y%m%d-%H%M%S")
bundle = dest.join("kos-#{stamp}.tar.gz")
exclusions = %w[--exclude=./.git --exclude=./backups --exclude=node_modules --exclude=.env --exclude=.env.* --exclude=.DS_Store]
history = root.join("kos-historial.bundle")
if root.join(".git").exist?
  ok = system("git", "-C", root.to_s, "bundle", "create", "-q", history.to_s, "--all", err: File::NULL)
  puts "Aviso: no se pudo guardar el historial de Git (¿sin commits?)." unless ok
end
begin
  abort "Falló la creación del respaldo." unless system("tar", *exclusions, "-czf", bundle.to_s, "-C", root.to_s, ".")
ensure
  FileUtils.rm_f(history)
end
digest = sha256(bundle)
File.write("#{bundle}.sha256", "#{digest}  #{bundle.basename}\n")
puts "Respaldo: #{bundle}"
puts "SHA256:   #{digest}"
puts "Verificar: ruby tools/kos_backup.rb --verify #{bundle}"
