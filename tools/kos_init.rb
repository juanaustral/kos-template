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
# In English:        ruby tools/kos_init.rb --lang en   (module: --only-module lists)
# Ver opciones:      ruby tools/kos_init.rb --ayuda

require "optparse"
require "pathname"
require "fileutils"
require "date"
require "yaml"

ROOT = Pathname.new(__dir__).join("..").expand_path
# Módulos por idioma: clave => archivos y textos que instala.
LANGS = {
  "es" => {
    recipes: "ONBOARDING/RECETAS.md", marker: "módulo",
    lists: { key: "listas", src: "modules/listas/lists",
             files: { "movies.md" => "Películas", "series.md" => "Series", "books.md" => "Libros" } },
    finance: { key: "finanzas", src: "modules/finanzas/proyecto", id: "finanzas", name: "Finanzas",
               row: "| Finanzas | activo | 3 | `projects/finanzas` | datos en `projects/finanzas/data/` |" }
  },
  "en" => {
    recipes: "ONBOARDING/RECIPES.md", marker: "module",
    lists: { key: "lists", src: "modules/lists/lists",
             files: { "movies.md" => "Movies", "series.md" => "Series", "books.md" => "Books" } },
    finance: { key: "finance", src: "modules/finance/project", id: "finance", name: "Finance",
               row: "| Finance | active | 3 | `projects/finance` | data in `projects/finance/data/` |" }
  }
}.freeze
MODULE_ALIASES = { "listas" => :lists, "lists" => :lists, "finanzas" => :finance, "finance" => :finance }.freeze
MODULES = MODULE_ALIASES.keys.freeze
IAS = %w[claude-code claude-ai chatgpt codex cursor gemini].freeze
TEXT_EXT = %w[.md .yaml .yml .mdc .csv .txt].freeze
SKIP_DIRS = %w[.git tools tests docs backups i18n].freeze

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
  o.on("--solo-modulo NOMBRE", "--only-module NAME", "Instalar solo un módulo en un KOS ya instalado") { |v| opts[:solo_modulo] = v }
  o.on("--lang IDIOMA", "es (por defecto) o en (English)") { |v| opts[:lang] = v }
  o.on("--forzar", "Volver a correr aunque ya esté instalado") { opts[:forzar] = true }
  o.on("--ayuda", "Mostrar esta ayuda") { puts o; exit }
end.parse!

def say(text) = puts(text)

TEXTS = {
  "es" => {
    welcome: "\nBienvenido a KOS. Voy a hacerte unas preguntas para adaptarlo a ti.\n(Enter acepta lo que está entre corchetes.)\n\n",
    nombre: "¿Cómo quieres que te llamen las IAs?", idioma: "¿En qué idioma te responden?",
    trato: "¿Trato? (tú, vos, usted)", estilo: "¿Estilo de respuesta?",
    areas: "Áreas de tu vida o trabajo (separadas por coma)", modulos: "Módulos opcionales (listas, finanzas; vacío = ninguno)",
    ias: "IAs que usas", defaults: ["Dueño", "español", "tú", "directo y breve, sin relleno ni emojis", "Trabajo,Personal"],
    done: "Listo.", errors: "Hay errores: revísalos arriba.",
    next: "Próximos pasos:\n1. Guarda este estado:  git add -A && git commit -m \"KOS instalado\"\n2. Conecta tu primera IA: docs/manual/03-conectar-tus-ias.md\n3. Pídele: \"Lee AGENTS.md y resúmeme KOS en cinco líneas.\""
  },
  "en" => {
    welcome: "\nWelcome to KOS. I'll ask you a few questions to tailor it to you.\n(Enter accepts what's in brackets.)\n\n",
    nombre: "What should AIs call you?", idioma: "Which language should they answer in?",
    trato: "Form of address? (informal, formal)", estilo: "Answer style?",
    areas: "Areas of your life or work (comma-separated)", modulos: "Optional modules (lists, finance; empty = none)",
    ias: "AIs you use", defaults: ["Owner", "English", "informal", "direct and brief, no fluff or emojis", "Work,Personal"],
    done: "Done.", errors: "There are errors: see above.",
    next: "Next steps:\n1. Save this state:  git add -A && git commit -m \"KOS installed\"\n2. Connect your first AI: docs/manual/03-connect-your-ais.md\n3. Ask it: \"Read AGENTS.md and summarize KOS in five lines.\""
  }
}.freeze

# Reemplaza los archivos en español por los de i18n/<lang>/ y borra los que no tienen par.
def apply_locale(lang)
  src = ROOT.join("i18n", lang)
  return unless src.directory?
  remove = src.join("_remove.txt")
  if remove.file?
    remove.read.lines.map(&:strip).reject { |l| l.empty? || l.start_with?("#") }.each { |rel| FileUtils.rm_rf(ROOT.join(rel)) }
  end
  Dir.glob(src.join("**/*").to_s, File::FNM_DOTMATCH).select { |p| File.file?(p) }.each do |file|
    rel = Pathname.new(file).relative_path_from(src)
    next if rel.to_s == "_remove.txt"
    FileUtils.mkdir_p(ROOT.join(rel).dirname)
    FileUtils.cp(file, ROOT.join(rel))
  end
end

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

def append_recipes(lang, key, values)
  cfg = LANGS[lang]
  recipes = ROOT.join(cfg[:recipes])
  extra_file = Dir[ROOT.join("modules/#{key}/{recetas,recipes}.md").to_s].first or return
  extra = fill(File.read(extra_file, encoding: "utf-8"), values)
  current = File.read(recipes, encoding: "utf-8")
  File.write(recipes, current.rstrip + "\n" + extra) unless current.include?("(#{cfg[:marker]} #{key})")
end

def install_module(lang, name, values)
  kind = MODULE_ALIASES[name] or abort "Módulo desconocido / unknown module: #{name}. #{MODULES.join(", ")}"
  cfg = LANGS[lang][kind]
  case kind
  when :lists
    cfg[:files].each do |file, label|
      dest = ROOT.join("knowledge/lists", file)
      copy_filled(ROOT.join(cfg[:src], file), dest, values) unless dest.exist?
      append_table_row(ROOT.join("knowledge/lists/README.md"), "| #{label} | `#{file}` |")
    end
  when :finance
    dest = ROOT.join("projects", cfg[:id])
    unless dest.exist?
      Dir[ROOT.join(cfg[:src], "**/*").to_s].select { |p| File.file?(p) }.each do |src|
        copy_filled(src, dest.join(Pathname.new(src).relative_path_from(ROOT.join(cfg[:src]))), values)
      end
    end
    registry = ROOT.join("registry/projects.yaml")
    unless File.read(registry).include?("id: #{cfg[:id]}")
      File.write(registry, File.read(registry).rstrip + "\n  - id: #{cfg[:id]}\n    name: #{cfg[:name]}\n    lifecycle: active\n    priority: 3\n    path: projects/#{cfg[:id]}\n")
    end
    append_table_row(ROOT.join("projects/index.md"), cfg[:row])
  end
  append_recipes(lang, cfg[:key], values)
  set_config_flag(cfg[:key])
  say "  módulo / module #{cfg[:key]} ✓"
end

def set_config_flag(key)
  path = ROOT.join("kos.yaml")
  File.write(path, File.read(path, encoding: "utf-8").sub(/^(\s+#{Regexp.escape(key)}:\s*)false/, '\1true'))
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
  installed = config["instalado"] == true || config["installed"] == true
  abort "Primero instala KOS / install KOS first: ruby tools/kos_init.rb" unless installed
  lang = config["lang"] == "en" ? "en" : "es"
  dueno = config["dueno"] || config["owner"] || {}
  values = { "OWNER_NAME" => dueno["nombre"] || dueno["name"], "IDIOMA" => dueno["idioma"] || dueno["language"],
             "TRATO" => dueno["trato"] || dueno["address"], "ESTILO" => dueno["estilo"] || dueno["style"],
             "FECHA_INSTALACION" => Date.today.iso8601 }
  install_module(lang, opts[:solo_modulo], values)
  exit(system("ruby", ROOT.join("tools/kos_validate.rb").to_s, ROOT.to_s) ? 0 : 1)
end

if (config["instalado"] == true || config["installed"] == true) && !opts[:forzar]
  abort "KOS ya está instalado / already installed. Módulo: --solo-modulo <nombre>. Repetir: --forzar."
end

lang = opts[:lang].to_s.downcase.start_with?("en") ? "en" : "es"
abort "Idioma no disponible / language not available: #{opts[:lang]} (es, en)" if opts[:lang] && !%w[es en english español].include?(opts[:lang].downcase)
apply_locale(lang) if lang != "es"
FileUtils.rm_rf(ROOT.join("i18n"))
FileUtils.rm_f(ROOT.join("README.en.md"))
readme = ROOT.join("README.md")
File.write(readme, readme.read.lines.reject { |l| l.include?("README.en.md") }.join.sub(/\A(# .*\n)\n\n/, "\\1\n"))
config = YAML.load_file(config_path.to_s) || {}
t = TEXTS[lang]
d = t[:defaults]

say t[:welcome]
nombre = ask(t[:nombre], opts[:nombre] || d[0], opts)
idioma = ask(t[:idioma], opts[:idioma] || d[1], opts)
trato = ask(t[:trato], opts[:trato] || d[2], opts)
estilo = ask(t[:estilo], opts[:estilo] || d[3], opts)
areas = list(ask(t[:areas], opts[:areas] || d[4], opts))
modulos = list(ask(t[:modulos], opts[:modulos] || "", opts))
ias = list(ask("#{t[:ias]} (#{IAS.join(", ")})", opts[:ias] || "", opts))
(modulos - MODULES).each { |m| abort "Módulo desconocido: #{m}" }
(ias - IAS).each { |i| abort "IA desconocida: #{i}" }

values = { "OWNER_NAME" => nombre, "IDIOMA" => idioma, "TRATO" => trato, "ESTILO" => estilo,
           "FECHA_INSTALACION" => Date.today.iso8601 }

say "\n..."
text_files(ROOT).each { |p| fill_file(p, values) }

areas.each do |area|
  dest = ROOT.join("knowledge/areas/#{slug(area)}.md")
  next if dest.exist?
  text = File.read(ROOT.join("templates/area.md"), encoding: "utf-8")
               .sub(/# <(Área|Area)>/, "# #{area}").sub(/<(AAAA-MM-DD|YYYY-MM-DD)>/, values["FECHA_INSTALACION"])
  File.write(dest, text)
  say "  #{area} ✓"
end

modulos.each { |m| install_module(lang, m, values) }
ias.each { |i| install_adapter(i) }

config_text = File.read(config_path, encoding: "utf-8")
                  .sub(/^(instalado|installed): false/, '\1: true')
                  .sub(/^(ias|ais): \[\]/, "\\1: [#{ias.join(", ")}]")
File.write(config_path, config_text)

unless ROOT.join(".git").exist?
  system("git", "init", "-q", "-b", "main", ROOT.to_s) && say("  repositorio Git creado")
end

say "\n..."
ok = system("ruby", ROOT.join("tools/kos_validate.rb").to_s, ROOT.to_s)

say "\n#{ok ? t[:done] : t[:errors]} #{t[:next]}"
exit(ok ? 0 : 1)
