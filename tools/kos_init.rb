#!/usr/bin/env ruby
# encoding: utf-8
Encoding.default_external = Encoding::UTF_8
ARGV.map! { |a| a.dup.force_encoding(Encoding::UTF_8) }

# kos_init.rb — Asistente de instalación de KOS.
#
# Uso interactivo:   ruby tools/kos_init.rb
# Sin preguntas:     ruby tools/kos_init.rb --si --nombre "Ana" --trato tú \
#                      --areas "Trabajo,Salud" --modulos listas,finanzas --ias claude-code,cursor
# Agregar un módulo: ruby tools/kos_init.rb --solo-modulo listas
# Ver opciones:      ruby tools/kos_init.rb --ayuda

require "optparse"
require "pathname"
require "fileutils"
require "date"
require "yaml"

ROOT = Pathname.new(__dir__).join("..").expand_path
MODULES = %w[listas finanzas].freeze
IAS = %w[claude-code claude-ai chatgpt codex cursor gemini].freeze
TEXT_EXT = %w[.md .yaml .yml .mdc .csv .txt].freeze
SKIP_DIRS = %w[.git tools tests docs backups].freeze

opts = {}
OptionParser.new do |o|
  o.banner = "Uso: ruby tools/kos_init.rb [opciones]"
  o.on("--nombre NOMBRE", "Cómo te llaman las IAs") { |v| opts[:nombre] = v }
  o.on("--idioma IDIOMA", "Idioma de las respuestas (por defecto: español)") { |v| opts[:idioma] = v }
  o.on("--trato TRATO", "tú, vos o usted (por defecto: tú)") { |v| opts[:trato] = v }
  o.on("--estilo ESTILO", "Estilo de respuesta") { |v| opts[:estilo] = v }
  o.on("--areas LISTA", "Áreas separadas por coma (ej.: Trabajo,Salud)") { |v| opts[:areas] = v }
  o.on("--modulos LISTA", "Módulos: #{MODULES.join(", ")}") { |v| opts[:modulos] = v }
  o.on("--ias LISTA", "IAs: #{IAS.join(", ")}") { |v| opts[:ias] = v }
  o.on("--si", "No preguntar; usar opciones y valores por defecto") { opts[:si] = true }
  o.on("--solo-modulo NOMBRE", "Instalar solo un módulo en un KOS ya instalado") { |v| opts[:solo_modulo] = v }
  o.on("--forzar", "Volver a correr aunque ya esté instalado") { opts[:forzar] = true }
  o.on("--ayuda", "Mostrar esta ayuda") { puts o; exit }
end.parse!

def say(text) = puts(text)

def ask(question, default, opts)
  return default if opts[:si] || !$stdin.tty?
  print "#{question} [#{default}]: "
  answer = $stdin.gets.to_s.strip
  answer.empty? ? default : answer
end

def list(value) = value.to_s.split(",").map(&:strip).reject(&:empty?)

def slug(text)
  text.unicode_normalize(:nfd).gsub(/\p{Mn}/, "").downcase.gsub(/[^a-z0-9]+/, "-").gsub(/\A-|-\z/, "")
end

def text_files(dir)
  Dir.glob(dir.join("**/*").to_s, File::FNM_DOTMATCH).select do |p|
    rel = Pathname.new(p).relative_path_from(ROOT).to_s
    File.file?(p) && TEXT_EXT.include?(File.extname(p)) && !SKIP_DIRS.include?(rel.split("/").first)
  end
end

def fill(text, values)
  values.reduce(text) { |t, (k, v)| t.gsub("{{#{k}}}", v.to_s) }
end

def fill_file(path, values)
  text = File.read(path, encoding: "utf-8")
  filled = fill(text, values)
  File.write(path, filled) if filled != text
end

def copy_filled(src, dest, values)
  FileUtils.mkdir_p(File.dirname(dest))
  File.write(dest, fill(File.read(src, encoding: "utf-8"), values))
end

# Inserta una fila al final de la primera tabla Markdown del archivo.
def append_table_row(path, row)
  lines = File.read(path, encoding: "utf-8").lines
  return if lines.any? { |l| l.strip == row.strip }
  start = lines.index { |l| l.start_with?("|") } or return
  last = start
  last += 1 while lines[last + 1]&.start_with?("|")
  lines.insert(last + 1, "#{row}\n")
  File.write(path, lines.join)
end

def append_recipes(mod, values)
  recipes = ROOT.join("ONBOARDING/RECETAS.md")
  extra = fill(File.read(ROOT.join("modules/#{mod}/recetas.md"), encoding: "utf-8"), values)
  current = File.read(recipes, encoding: "utf-8")
  File.write(recipes, current.rstrip + "\n" + extra) unless current.include?("(módulo #{mod})")
end

def install_module(mod, values)
  case mod
  when "listas"
    { "movies.md" => "Películas", "series.md" => "Series", "books.md" => "Libros" }.each do |file, label|
      dest = ROOT.join("knowledge/lists", file)
      copy_filled(ROOT.join("modules/listas/lists", file), dest, values) unless dest.exist?
      append_table_row(ROOT.join("knowledge/lists/README.md"), "| #{label} | `#{file}` |")
    end
  when "finanzas"
    dest = ROOT.join("projects/finanzas")
    unless dest.exist?
      Dir[ROOT.join("modules/finanzas/proyecto/**/*").to_s].select { |p| File.file?(p) }.each do |src|
        copy_filled(src, dest.join(Pathname.new(src).relative_path_from(ROOT.join("modules/finanzas/proyecto"))), values)
      end
    end
    registry = ROOT.join("registry/projects.yaml")
    unless File.read(registry).include?("id: finanzas")
      File.write(registry, File.read(registry).rstrip + "\n  - id: finanzas\n    name: Finanzas\n    lifecycle: active\n    priority: 3\n    path: projects/finanzas\n")
    end
    append_table_row(ROOT.join("projects/index.md"), "| Finanzas | activo | 3 | `projects/finanzas` | datos en `projects/finanzas/data/` |")
  else
    abort "Módulo desconocido: #{mod}. Disponibles: #{MODULES.join(", ")}"
  end
  append_recipes(mod, values)
  say "  módulo #{mod} instalado"
end

def install_adapter(ia)
  case ia
  when "claude-code"
    FileUtils.cp(ROOT.join("adapters/claude-code/CLAUDE.md"), ROOT.join("CLAUDE.md")) unless ROOT.join("CLAUDE.md").exist?
    FileUtils.mkdir_p(ROOT.join(".claude/skills/kos"))
    FileUtils.cp(ROOT.join("adapters/claude-code/skills/kos/SKILL.md"), ROOT.join(".claude/skills/kos/SKILL.md"))
    say "  Claude Code: CLAUDE.md y .claude/skills/kos/ listos"
  when "cursor"
    FileUtils.mkdir_p(ROOT.join(".cursor/rules"))
    FileUtils.cp(ROOT.join("adapters/cursor/kos.mdc"), ROOT.join(".cursor/rules/kos.mdc"))
    say "  Cursor: .cursor/rules/kos.mdc listo"
  when "gemini"
    FileUtils.cp(ROOT.join("adapters/gemini/GEMINI.md"), ROOT.join("GEMINI.md")) unless ROOT.join("GEMINI.md").exist?
    say "  Gemini CLI: GEMINI.md listo"
  when "codex"
    say "  Codex: lee AGENTS.md directamente, no hace falta nada más"
  when "claude-ai"
    say "  Claude.ai: sigue adapters/claude-ai.md"
  when "chatgpt"
    say "  ChatGPT: sigue adapters/chatgpt.md"
  else
    abort "IA desconocida: #{ia}. Disponibles: #{IAS.join(", ")}"
  end
end

config_path = ROOT.join("kos.yaml")
config = YAML.load_file(config_path.to_s) || {}

# --- Solo un módulo ---
if opts[:solo_modulo]
  abort "Primero instala KOS: ruby tools/kos_init.rb" unless config["instalado"] == true
  dueno = config["dueno"] || {}
  values = { "OWNER_NAME" => dueno["nombre"], "IDIOMA" => dueno["idioma"], "TRATO" => dueno["trato"],
             "ESTILO" => dueno["estilo"], "FECHA_INSTALACION" => Date.today.iso8601 }
  install_module(opts[:solo_modulo], values)
  text = File.read(config_path, encoding: "utf-8").sub(/^(\s+#{Regexp.escape(opts[:solo_modulo])}:\s*)false/, '\1true')
  File.write(config_path, text)
  system("ruby", ROOT.join("tools/kos_validate.rb").to_s, ROOT.to_s)
  exit
end

if config["instalado"] == true && !opts[:forzar]
  abort "KOS ya está instalado. Para agregar un módulo: --solo-modulo <nombre>. Para repetir: --forzar."
end

say "\nBienvenido a KOS. Voy a hacerte unas preguntas para adaptarlo a ti.\n(Enter acepta lo que está entre corchetes.)\n\n"
nombre = ask("¿Cómo quieres que te llamen las IAs?", opts[:nombre] || "Dueño", opts)
idioma = ask("¿En qué idioma te responden?", opts[:idioma] || "español", opts)
trato = ask("¿Trato? (tú, vos, usted)", opts[:trato] || "tú", opts)
estilo = ask("¿Estilo de respuesta?", opts[:estilo] || "directo y breve, sin relleno ni emojis", opts)
areas = list(ask("Áreas de tu vida o trabajo (separadas por coma)", opts[:areas] || "Trabajo,Personal", opts))
modulos = list(ask("Módulos opcionales (#{MODULES.join(", ")}; vacío = ninguno)", opts[:modulos] || "", opts))
ias = list(ask("IAs que usas (#{IAS.join(", ")})", opts[:ias] || "", opts))
(modulos - MODULES).each { |m| abort "Módulo desconocido: #{m}" }
(ias - IAS).each { |i| abort "IA desconocida: #{i}" }

values = { "OWNER_NAME" => nombre, "IDIOMA" => idioma, "TRATO" => trato, "ESTILO" => estilo,
           "FECHA_INSTALACION" => Date.today.iso8601 }

say "\nPersonalizando archivos..."
text_files(ROOT).each { |p| fill_file(p, values) }

areas.each do |area|
  dest = ROOT.join("knowledge/areas/#{slug(area)}.md")
  next if dest.exist?
  text = File.read(ROOT.join("templates/area.md"), encoding: "utf-8")
               .sub("# <Área>", "# #{area}").sub("<AAAA-MM-DD>", values["FECHA_INSTALACION"])
  File.write(dest, text)
  say "  área #{area} creada"
end

modulos.each { |m| install_module(m, values) }
ias.each { |i| install_adapter(i) }

config_text = File.read(config_path, encoding: "utf-8")
                  .sub(/^instalado: false/, "instalado: true")
                  .sub(/^ias: \[\]/, "ias: [#{ias.join(", ")}]")
modulos.each { |m| config_text = config_text.sub(/^(\s+#{m}:\s*)false/, '\1true') }
File.write(config_path, config_text)

unless ROOT.join(".git").exist?
  system("git", "init", "-q", "-b", "main", ROOT.to_s) && say("  repositorio Git creado")
end

say "\nValidando..."
ok = system("ruby", ROOT.join("tools/kos_validate.rb").to_s, ROOT.to_s)

say <<~TXT

  #{ok ? "Listo." : "Hay errores: revísalos arriba."} Próximos pasos:
  1. Guarda este estado:  git add -A && git commit -m "KOS instalado"
  2. Conecta tu primera IA: docs/manual/03-conectar-tus-ias.md
  3. Pídele: "Lee AGENTS.md y resúmeme KOS en cinco líneas."
TXT
exit(ok ? 0 : 1)
