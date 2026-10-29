#!/usr/bin/env ruby
# encoding: utf-8
# kos_write.rb no escribe la zona crítica, pero sí el resto. Corre en un KOS descartable.
require "tmpdir"
require "open3"
require "fileutils"
raiz = File.expand_path("..", __dir__)
fallas = []
Dir.mktmpdir("kos-zona-test") do |t|
  kos = File.join(t, "kos")
  FileUtils.mkdir_p(kos)
  system("rsync", "-rl", "--exclude", ".git", "--exclude", "backups", "--exclude", "exports", "--exclude", "__pycache__", "#{raiz}/", "#{kos}/")
  Dir.chdir(kos) { system("git", "init", "-q", "-b", "main", "."); %w[user.name user.email].each { |k| system("git", "config", k, "t") }; system("git", "add", "-A"); system("git", "commit", "-q", "-m", "base") }
  tmp = File.join(t, "x.md"); File.write(tmp, "contenido\n")
  escribe = ->(ruta) { Open3.capture2e({ "KOS_ROOT" => kos }, "ruby", File.join(kos, "tools/kos_write.rb"), "--agente", "prueba", "archivo", "--ruta", ruta, "--archivo", tmp) }
  %w[AGENTS.md tools/kos_write.rb tools/nuevo.rb ONBOARDING/README.md registry/zonas.yaml .claude/settings.json .github/x.yml .gitignore tools/../AGENTS.md ./tools/x.rb].each do |r|
    out, st = escribe.call(r)
    fallas << "dejó escribir #{r}" if st.success?
    fallas << "mensaje sin explicar para #{r}" unless out.include?("zona crítica")
  end
  # la lista que cuenta es la de HEAD: vaciarla en disco no abre la puerta
  File.write(File.join(kos, "registry/zonas.yaml"), "version: 1\ncritica:\n  rutas: []\n")
  _, st = escribe.call("AGENTS.md")
  fallas << "vaciar zonas.yaml en disco abrió la puerta" if st.success?
  system("git", "-C", kos, "checkout", "-q", "registry/zonas.yaml")
  # lo operativo sigue andando
  proyecto = Dir.children(File.join(kos, "projects")).sort.find { |d| File.directory?(File.join(kos, "projects", d)) } # el primero que exista
  ["knowledge/inbox/2026-10-29-prueba.md", "projects/#{proyecto}/nota-prueba.md", "toolsbox/ok.md"].each do |r|
    out, st = escribe.call(r)
    fallas << "bloqueó una ruta libre #{r}: #{out.lines.first}" unless st.success?
  end
end
if fallas.empty? then puts "zona_critica_test: OK"; exit 0
else puts "zona_critica_test FALLÓ:\n- #{fallas.join("\n- ")}"; exit 1 end
