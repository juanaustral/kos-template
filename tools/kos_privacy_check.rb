#!/usr/bin/env ruby
# encoding: utf-8
Encoding.default_external = Encoding::UTF_8
ARGV.map! { |a| a.dup.force_encoding(Encoding::UTF_8) }

# kos_privacy_check.rb — Busca términos prohibidos antes de compartir o publicar un KOS.
#
# Uso: ruby tools/kos_privacy_check.rb --denylist <archivo> [--historial] [RAIZ]
#   <archivo>: un término por línea (nombres, mails, rutas, clientes). Líneas con # se ignoran.
#   Líneas que empiezan con "!": frase exacta permitida (ej.: el titular en la licencia); se quita antes de buscar.
#   --historial: revisa también todo el historial de Git (git log -p --all).
# Coincide palabras completas, sin distinguir mayúsculas ni tildes. Sale con 1 si encuentra algo.

require "optparse"
require "pathname"
require "open3"

opts = {}
OptionParser.new do |o|
  o.on("--denylist ARCHIVO") { |v| opts[:denylist] = v }
  o.on("--historial") { opts[:historial] = true }
end.parse!
abort "Falta --denylist <archivo>" unless opts[:denylist] && File.file?(opts[:denylist])
root = Pathname.new(ARGV[0] || ".").expand_path
deny_path = Pathname.new(opts[:denylist]).expand_path

def fold(text) = text.unicode_normalize(:nfd).gsub(/\p{Mn}/, "").downcase

lines = File.readlines(deny_path, encoding: "utf-8").map(&:strip).reject { |l| l.empty? || l.start_with?("#") }
allowed = lines.select { |l| l.start_with?("!") }.map { |l| fold(l[1..].strip) }.reject(&:empty?)
terms = lines.reject { |l| l.start_with?("!") }
patterns = terms.to_h { |t| [t, /(?<![[:alnum:]])#{Regexp.escape(fold(t))}(?![[:alnum:]])/] }
hits = []

check = lambda do |label, text|
  text.each_line.with_index(1) do |line, n|
    folded = allowed.reduce(fold(line.scrub)) { |acc, phrase| acc.gsub(phrase, " ") }
    patterns.each { |term, re| hits << "#{label}:#{n}: «#{term}»" if folded.match?(re) }
  end
end

files = Dir.glob(root.join("**/*").to_s, File::FNM_DOTMATCH).select { |p| File.file?(p) }
files.reject! { |p| p.include?("/.git/") || Pathname.new(p).expand_path == deny_path }
files.each do |p|
  text = File.read(p, encoding: "utf-8") rescue next
  next unless text.valid_encoding?
  check.(Pathname.new(p).relative_path_from(root).to_s, text)
  check.("(nombre de archivo) #{Pathname.new(p).relative_path_from(root)}", Pathname.new(p).relative_path_from(root).to_s)
end

if opts[:historial] && root.join(".git").exist?
  out, _err, _st = Open3.capture3("git", "-C", root.to_s, "log", "-p", "--all", "--format=commit %h %an <%ae> %s")
  check.("historial", out.force_encoding(Encoding::UTF_8))
end

puts "Chequeo de privacidad: #{terms.size} términos, #{files.size} archivos#{opts[:historial] ? " + historial" : ""}"
if hits.empty?
  puts "OK — 0 coincidencias."
  exit 0
end
puts "#{hits.size} coincidencias:"
hits.first(200).each { |h| puts "  #{h}" }
exit 1
