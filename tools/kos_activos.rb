#!/usr/bin/env ruby
# encoding: utf-8
Encoding.default_external = Encoding::UTF_8

# kos_activos.rb — Tabla corta de proyectos activos (lifecycle: active), por prioridad.
# Uso: ruby tools/kos_activos.rb [RAIZ]

require "yaml"
require "date"

ROOT = File.expand_path(ARGV[0] || ENV["KOS_ROOT"] || File.join(__dir__, ".."))

def proxima_accion(root, proyecto)
  ruta = File.join(root, proyecto["path"] || File.join("projects", proyecto["id"].to_s), "project.md")
  return "-" unless File.file?(ruta)
  lineas = File.read(ruta, encoding: "UTF-8").lines
  i = lineas.index { |l| l =~ /^##\s+Pr[oó]xima acci[oó]n\s*$/i }
  return "-" unless i
  texto = lineas[(i + 1)..].take_while { |l| l !~ /^#/ }.map(&:strip).reject(&:empty?).join(" ")
  texto.empty? ? "-" : texto
end

archivo = File.join(ROOT, "registry", "projects.yaml")
datos = File.file?(archivo) ? (YAML.safe_load(File.read(archivo, encoding: "UTF-8"), permitted_classes: [Date, Time, Symbol]) || {}) : {}
activos = Array(datos["projects"]).select { |p| p.is_a?(Hash) && p["lifecycle"].to_s == "active" }
activos = activos.sort_by { |p| [p["priority"].is_a?(Numeric) ? p["priority"] : Float::INFINITY, p["name"].to_s] }

if activos.empty?
  puts "No hay proyectos activos."
  exit 0
end

filas = activos.map { |p| [(p["name"] || p["id"]).to_s, p["priority"].to_s.then { |x| x.empty? ? "-" : x }, proxima_accion(ROOT, p)] }
cab = ["Proyecto", "Prioridad", "Próxima acción"]
ancho = cab.each_index.map { |c| ([cab] + filas).map { |f| f[c].length }.max }
fmt = ->(f) { f.each_with_index.map { |v, c| v.ljust(ancho[c]) }.join(" | ").rstrip }
puts fmt.(cab)
puts ancho.map { |w| "-" * w }.join("-+-")
filas.each { |f| puts fmt.(f) }
