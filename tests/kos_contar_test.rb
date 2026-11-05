#!/usr/bin/env ruby
# encoding: utf-8
Encoding.default_external = Encoding::UTF_8

# Prueba de kos_contar.rb sobre directorios temporales; no toca el repo.
# Uso: ruby tests/kos_contar_test.rb

require "tmpdir"
require "fileutils"
require "open3"

SCRIPT = File.expand_path("../tools/kos_contar.rb", __dir__)
$failures = []

def check(cond, message) = ($failures << message unless cond)

def contar(lifecycles)
  Dir.mktmpdir("kos-contar-test-") do |tmp|
    unless lifecycles.nil?
      FileUtils.mkdir_p(File.join(tmp, "registry"))
      items = lifecycles.each_with_index.map { |l, i| "  - id: p#{i}\n    lifecycle: #{l}\n" }.join
      body = lifecycles.empty? ? "projects: []\n" : "projects:\n#{items}"
      File.write(File.join(tmp, "registry/projects.yaml"), "schema_version: 1\n#{body}")
    end
    return Open3.capture3("ruby", SCRIPT, tmp)
  end
end

out, _, st = contar(%w[active active paused archived])
check(out == "active: 2\npaused: 1\narchived: 1\n" && st.success?, "conteo básico: #{out.inspect}")

out, _, st = contar([])
check(out == "active: 0\npaused: 0\narchived: 0\n" && st.success?, "registro vacío: #{out.inspect}")

out, err, st = contar(nil)
check(!st.success? && !err.strip.empty?, "sin registry debe fallar con mensaje en stderr")

out, _, st = contar(%w[active finished])
check(out == "active: 1\npaused: 0\narchived: 0\nfinished: 1\n" && st.success?, "finished: #{out.inspect}")

if $failures.empty?
  puts "kos_contar_test: OK"
else
  puts $failures.map { |f| "FALLA: #{f}" }
  exit 1
end
