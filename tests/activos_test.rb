#!/usr/bin/env ruby
# encoding: utf-8
# Prueba de kos_activos.rb: filtra por lifecycle, ordena por prioridad, caso vacío y project.md faltante.
require "tmpdir"
require "open3"
require "fileutils"
raiz = File.expand_path("..", __dir__)
fallas = []
run = ->(dir) { Open3.capture2e("ruby", File.join(raiz, "tools", "kos_activos.rb"), dir) }
Dir.mktmpdir("kos-activos-test") do |t|
  FileUtils.mkdir_p(File.join(t, "registry"))
  FileUtils.mkdir_p(File.join(t, "projects/b"))
  File.write(File.join(t, "projects/b/project.md"), "# B\n\n## Próxima acción\nHacer B.\n\n## Otra\nx\n")
  File.write(File.join(t, "registry/projects.yaml"), <<~Y)
    projects:
      - {id: a, name: Alfa, lifecycle: active, priority: 3, path: projects/a}
      - {id: b, name: Beta, lifecycle: active, priority: 1, path: projects/b}
      - {id: c, name: Gamma, lifecycle: paused, priority: 1, path: projects/c}
      - {id: d, name: Delta, lifecycle: archived, priority: 2, path: projects/d}
  Y
  out, st = run.(t)
  fallas << "sale con error" unless st.success?
  fallas << "muestra no activos" if out =~ /Gamma|Delta/
  fallas << "orden incorrecto" unless out.index("Beta") && out.index("Alfa") && out.index("Beta") < out.index("Alfa")
  fallas << "falta próxima acción" unless out.include?("Hacer B.")
  fallas << "falta '-' sin project.md" unless out =~ /Alfa\s*\|\s*3\s*\|\s*-$/
  File.write(File.join(t, "registry/projects.yaml"), "projects:\n  - {id: c, name: Gamma, lifecycle: paused, priority: 1}\n")
  out, st = run.(t)
  fallas << "caso vacío mal" unless st.success? && out.include?("No hay proyectos activos")
end
if fallas.empty? then puts "activos_test: OK (5 casos)"; exit 0
else puts "activos_test FALLÓ:\n- #{fallas.join("\n- ")}"; exit 1 end
