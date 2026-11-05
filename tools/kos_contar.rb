#!/usr/bin/env ruby
# encoding: utf-8
Encoding.default_external = Encoding::UTF_8
ARGV.map! { |a| a.dup.force_encoding(Encoding::UTF_8) }

# kos_contar.rb — Cuenta cuántos proyectos hay por lifecycle. Sin red y sin IA.
# Uso: ruby tools/kos_contar.rb [RAIZ]

require "yaml"
require "date"
require "pathname"

root = Pathname.new(ARGV[0] || ".").expand_path
file = root.join("registry/projects.yaml")

begin
  data = YAML.load_file(file.to_s, permitted_classes: [Date, Time, Symbol], aliases: true)
rescue SystemCallError, Psych::Exception => e
  warn "kos_contar: no pude leer #{file}: #{e.message}"
  exit 1
end

projects = data.is_a?(Hash) && data["projects"].is_a?(Array) ? data["projects"] : []
counts = Hash.new(0)
projects.each { |p| counts[p["lifecycle"].to_s] += 1 if p.is_a?(Hash) }

%w[active paused archived].each { |l| puts "#{l}: #{counts[l]}" }
puts "finished: #{counts['finished']}" if counts["finished"] > 0
