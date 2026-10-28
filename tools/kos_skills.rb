#!/usr/bin/env ruby
# encoding: utf-8
Encoding.default_external = Encoding::UTF_8

# kos_skills.rb — Skills compartidas entre agentes de IA (Claude Code, Codex y los que lean archivos) dentro de KOS.
# Las skills aprobadas viven en skills/<nombre>/ (formato abierto SKILL.md, agentskills.io).
# Ningún agente las cambia directo: propone en skills/_propuestas/<nombre>/ y una persona de
# skills/config.yaml (aprobadores) aprueba. Cada aprobación deja un sello en CAMBIOS.md; si la skill
# cambia sin pasar por aprobar, kos_validate.rb da error.
#
# Uso: ruby tools/kos_skills.rb <operación> [opciones]   (ayuda: --ayuda)
# Sin dependencias: solo Ruby estándar y git.

require "yaml"
require "date"
require "digest"
require "pathname"
require "fileutils"
require "open3"
require "optparse"
require "tmpdir"

module KosSkills
  NAME_RE = /\A[a-z0-9]+(-[a-z0-9]+)*\z/
  CAMPOS = %w[name description license compatibility metadata].freeze # portables del estándar
  SIN_SELLO = ["CAMBIOS.md", "evals/resultados.md"].freeze # cambian sin pasar por aprobar
  # Señales de riesgo en skills ajenas. Son avisos: los lee una persona antes de aprobar.
  RIESGOS = {
    "descarga y ejecuta código" => /(curl|wget)[^\n|]*\|\s*(ba|z)?sh|\b(npx|pipx|uvx)\s+\S/i,
    "borrado masivo" => /rm\s+-rf?\s+[\/~$]/,
    "usa sudo" => /\bsudo\s/,
    "pide ignorar instrucciones" => /\bignor(e|ar|á)\b.{0,25}(previous|prior|above|instrucciones|anteriores)/i,
    "texto oculto (comentario HTML)" => /<!--.*?-->/m,
    "decodifica base64" => /base64\s+(-d|--decode)/,
    "toca credenciales" => /(\.ssh\/|\.env\b|id_rsa|api[_-]?key|auth\.json)/i
  }.freeze

  module_function

  ORIGENES = %w[propia adaptada tercero].freeze # si config.yaml no los define

  def config(root)
    file = root.join("skills/config.yaml")
    data = file.file? ? (YAML.safe_load(file.read) || {}) : {}
    data["origenes"] = ORIGENES if Array(data["origenes"]).empty?
    data
  rescue StandardError
    { "origenes" => ORIGENES }
  end

  # Enlace simbólico; si queda dentro del mismo KOS, relativo (así sirve en otra máquina).
  def enlazar(dir, link, root)
    destino = link.dirname.expand_path.to_s.start_with?(root.expand_path.to_s + "/") ? dir.relative_path_from(link.dirname.expand_path) : dir
    File.symlink(destino, link)
  end

  def frontmatter(file)
    text = file.read
    m = text.match(/\A---\s*\n(.*?)\n---\s*(\n|\z)/m)
    return [nil, "falta el bloque YAML inicial (--- ... ---)"] unless m
    data = YAML.safe_load(m[1])
    data.is_a?(Hash) ? [data, nil] : [nil, "el bloque YAML no es un mapa"]
  rescue StandardError => e
    [nil, "YAML inválido: #{e.message.lines.first.strip}"]
  end

  # Archivos que forman la skill (los que entran al sello), relativos a su carpeta.
  def archivos(dir)
    Dir.glob("**/*", File::FNM_DOTMATCH, base: dir.to_s)
       .reject { |r| r.split("/").any? { |p| p.start_with?(".") } || r.end_with?(".kos-new") } # .kos-new: lo deja kos_update
       .select { |r| dir.join(r).file? }
       .sort
  end

  def sello(dir)
    d = Digest::SHA256.new
    (archivos(dir) - SIN_SELLO).reject { |r| r == "PROPUESTA.md" }.each { |r| d << r << "\0" << dir.join(r).binread << "\0" }
    d.hexdigest[0, 16]
  end

  def ultimo_sello(dir)
    f = dir.join("CAMBIOS.md")
    f.file? ? f.read.scan(/^- sello: `?([0-9a-f]{16})`?/).flatten.last : nil
  end

  # Revisa una carpeta de skill. Devuelve [[código, mensaje], ...] de errores y de avisos.
  def revisar_skill(dir, nombre, origenes)
    errores = []
    avisos = []
    md = dir.join("SKILL.md")
    return [[["skill-sin-skill-md", "falta SKILL.md"]], []] unless md.file?

    data, problema = frontmatter(md)
    return [[["skill-frontmatter", problema]], []] if problema

    errores << ["skill-nombre", "name '#{data["name"]}' no coincide con la carpeta '#{nombre}'"] if data["name"] != nombre
    errores << ["skill-nombre", "'#{nombre}': solo minúsculas, números y guiones simples, hasta 64"] unless nombre.match?(NAME_RE) && nombre.size <= 64
    desc = data["description"].to_s.strip
    errores << ["skill-descripcion", "description vacía o de más de 1024 caracteres"] if desc.empty? || desc.size > 1024
    (data.keys - CAMPOS).each do |k|
      avisos << ["skill-campo-no-portable", "campo '#{k}': otros agentes lo ignoran; usalo solo si hace falta"]
    end
    meta = data["metadata"].is_a?(Hash) ? data["metadata"] : {}
    origen = meta["origen"].to_s
    errores << ["skill-origen", "metadata.origen debe ser uno de: #{origenes.join(", ")}"] unless origenes.include?(origen)
    errores << ["skill-fuente", "origen '#{origen}': falta metadata.fuente (de dónde viene)"] if origen != "propia" && !origen.empty? && meta["fuente"].to_s.strip.empty?
    errores << ["skill-licencia", "skill de un tercero sin license: no se puede usar sin permiso del autor"] if origen == "tercero" && data["license"].to_s.strip.empty?
    errores << ["skill-version", "falta metadata.version (texto, ej. \"1.0\")"] if meta["version"].to_s.strip.empty?
    errores << ["skill-sin-evals", "falta evals/casos.md (pedidos de prueba y qué debe salir)"] unless dir.join("evals/casos.md").file?
    avisos << ["skill-con-scripts", "tiene scripts/: revisalos a mano antes de aprobar"] if dir.join("scripts").exist?
    riesgos(dir).each { |r| avisos << ["skill-riesgo", r] }
    [errores, avisos]
  end

  # Busca señales de RIESGOS en los archivos de texto de la skill (sin evals ni historial).
  def riesgos(dir)
    (archivos(dir) - SIN_SELLO - ["PROPUESTA.md"]).reject { |r| r.start_with?("evals/") }.flat_map do |r|
      text = (dir.join(r).read rescue "")
      next [] unless text.valid_encoding?
      RIESGOS.filter_map { |motivo, re| "#{r}: #{motivo}" if text.match?(re) }
    end
  end

  # ¿La skill de esa carpeta es de otra persona? Devuelve las señales que lo indican (vacío = propia).
  def senales_de_tercero(dir)
    data, = frontmatter(dir.join("SKILL.md"))
    return ["SKILL.md sin bloque YAML válido"] unless data
    meta = data["metadata"].is_a?(Hash) ? data["metadata"] : {}
    senales = []
    senales << "metadata.origen es '#{meta["origen"]}'" if meta["origen"] && meta["origen"] != "propia"
    senales << "no dice que sea propia (sin metadata.origen)" unless meta["origen"]
    senales << "autor: #{meta["author"]}" if meta["author"]
    senales << "licencia: #{data["license"]}" if data["license"]
    senales << "trae archivo de licencia" if Dir.glob("{LICENSE,LICENSE.*,COPYING}*", base: dir.to_s).any?
    senales
  end

  # Revisión completa de skills/ para kos_validate.rb. Devuelve [errores, avisos] como [código, ruta, mensaje].
  def revisar(root)
    errores = []
    avisos = []
    base = root.join("skills")
    return [errores, avisos] unless base.directory?

    cfg = config(root)
    origenes = Array(cfg["origenes"]).map(&:to_s)
    avisos << ["skills-sin-aprobadores", "skills/config.yaml", "falta la lista 'aprobadores': nadie puede aprobar skills"] if Array(cfg["aprobadores"]).empty?

    base.children.select(&:directory?).sort.each do |dir|
      nombre = dir.basename.to_s
      next if nombre.start_with?(".")
      if nombre == "_propuestas"
        dir.children.select(&:directory?).sort.each do |prop|
          e, a = revisar_skill(prop, prop.basename.to_s, origenes)
          (e + a).each { |c, m| avisos << [c, "skills/_propuestas/#{prop.basename}", m] }
          avisos << ["skill-propuesta-sin-nota", "skills/_propuestas/#{prop.basename}", "falta PROPUESTA.md (usá 'entregar')"] unless prop.join("PROPUESTA.md").file?
        end
        next
      end
      next if nombre.start_with?("_")

      rel = "skills/#{nombre}"
      e, a = revisar_skill(dir, nombre, origenes)
      e.each { |c, m| errores << [c, rel, m] }
      a.each { |c, m| avisos << [c, rel, m] }
      esperado = ultimo_sello(dir)
      if esperado.nil?
        errores << ["skill-sin-aprobar", rel, "no tiene CAMBIOS.md con sello: entra solo con 'proponer' + 'aprobar'"]
      elsif esperado != sello(dir)
        errores << ["skill-cambiada-sin-aprobar", rel, "cambió después de la última aprobación (sello #{esperado}); deshacé el cambio o pasalo por 'proponer' + 'aprobar'"]
      end
    end
    [errores, avisos]
  end
end

# ---------------------------------------------------------------------------------------------
# Línea de comandos
# ---------------------------------------------------------------------------------------------
if $PROGRAM_NAME == __FILE__
  $stdout.sync = true # el informe sale antes que el error (que va a stderr)
  ROOT = Pathname.new(ENV["KOS_ROOT"] || File.join(__dir__, "..")).expand_path
  SKILLS = ROOT.join("skills")
  PROPUESTAS = SKILLS.join("_propuestas")
  LOCK_FILE = ROOT.join(".git/kos-write.lock") # el mismo candado que kos_write.rb y kos_sync.rb
  TODAY = Date.today.iso8601
  DESTINOS = { "claude" => "~/.claude/skills", "codex" => "~/.agents/skills" }.freeze

  class KosError < StandardError
    attr_reader :code

    def initialize(msg, code = 1)
      super(msg)
      @code = code
    end
  end

  def git(*args, env: {}, stdin: nil, ok: true)
    out, err, st = Open3.capture3(env, "git", "-C", ROOT.to_s, *args, stdin_data: stdin.to_s, binmode: true)
    raise KosError, "git #{args.first} falló: #{err.strip[0, 300]}" if ok && !st.success?
    [out.force_encoding(Encoding::UTF_8), st.success?]
  end

  def with_lock(timeout = 120)
    File.open(LOCK_FILE, File::RDWR | File::CREAT, 0o664) do |f|
      File.chmod(0o664, LOCK_FILE) rescue nil
      deadline = Time.now + timeout
      until f.flock(File::LOCK_EX | File::LOCK_NB)
        raise KosError, "KOS ocupado más de #{timeout}s (candado #{LOCK_FILE})" if Time.now > deadline
        sleep 0.2
      end
      yield
    end
  end

  def autor(nombre)
    { "GIT_AUTHOR_NAME" => nombre.split(/[\/_-]/).map(&:capitalize).join("/"),
      "GIT_AUTHOR_EMAIL" => "#{nombre.tr("/", "-")}@kos.local" }
  end

  # Commit de solo estas rutas sobre HEAD, con un índice temporal (mismo método que kos_write.rb):
  # no toca el índice compartido ni se lleva cambios de otros agentes.
  # escribir: { "ruta" => contenido_binario }, borrar: ["ruta", ...]
  def commit(escribir, borrar, quien, mensaje)
    3.times do
      head, = git("rev-parse", "HEAD")
      head.strip!
      Dir.mktmpdir("kos-skills-") do |tmp|
        env = { "GIT_INDEX_FILE" => File.join(tmp, "index") }
        git("read-tree", head, env: env)
        escribir.each do |rel, data|
          blob, = git("hash-object", "-w", "--stdin", stdin: data)
          git("update-index", "--add", "--cacheinfo", "100644,#{blob.strip},#{rel}", env: env)
        end
        borrar.each { |rel| git("update-index", "--force-remove", rel, env: env) }
        tree, = git("write-tree", env: env)
        c, = git("commit-tree", tree.strip, "-p", head, "-m", mensaje, env: autor(quien))
        _, movido = git("update-ref", "-m", "kos_skills: #{mensaje[0, 60]}", "HEAD", c.strip, head, ok: false)
        next unless movido

        escribir.each do |rel, data|
          path = ROOT.join(rel)
          FileUtils.mkdir_p(path.dirname)
          File.binwrite(path, data)
          File.chmod(0o664, path) rescue nil
          blob, = git("hash-object", "-w", "--stdin", stdin: data)
          git("update-index", "--add", "--cacheinfo", "100644,#{blob.strip},#{rel}", ok: false)
        end
        borrar.each do |rel|
          FileUtils.rm_f(ROOT.join(rel))
          git("update-index", "--force-remove", rel, ok: false)
        end
        return c.strip
      end
    end
    raise KosError, "HEAD cambió tres veces seguidas; probá de nuevo"
  end

  def borrar_vacias(dir)
    Dir.glob("#{dir}/**/").sort_by { |d| -d.size }.each { |d| Dir.rmdir(d) if Dir.empty?(d) rescue nil }
  end

  def nombre!(n)
    raise KosError.new("Falta el nombre de la skill", 2) if n.to_s.empty?
    raise KosError.new("Nombre inválido '#{n}': minúsculas, números y guiones", 2) unless n.match?(KosSkills::NAME_RE)
    n
  end

  def origenes = Array(KosSkills.config(ROOT)["origenes"]).map(&:to_s)

  def chequear!(dir, nombre)
    errores, avisos = KosSkills.revisar_skill(dir, nombre, origenes)
    avisos.each { |c, m| warn "Aviso [#{c}] #{m}" }
    raise KosError, "La skill no pasa la validación:\n" + errores.map { |c, m| "  [#{c}] #{m}" }.join("\n") unless errores.empty?
  end

  opts = { agente: ENV["KOS_AGENTE"].to_s }
  parser = OptionParser.new do |o|
    o.banner = <<~TXT
      kos_skills.rb — Skills compartidas en KOS (skills/). Ninguna skill aprobada se cambia a mano.

      Uso: ruby tools/kos_skills.rb <operación> [opciones]
        estado                                   skills aprobadas, propuestas pendientes y enlaces de este usuario
        validar                                  revisa skills/ (formato, evals, sellos); sale con 1 si hay errores
        proponer NOMBRE [--desde CARPETA]        borrador en skills/_propuestas/NOMBRE/ (copia de la aprobada,
                                                 de CARPETA propia, o vacío si es nueva). No commitea.
        importar CARPETA [--modo tal-cual|adaptar] [--como NOMBRE] [--fuente URL]
                                                 skill de otra persona: muestra autor, licencia y riesgos y pregunta
                                                 si va tal cual o adaptada a KOS. Deja el borrador en _propuestas/.
        entregar NOMBRE --agente X --motivo "…"  valida el borrador, le agrega PROPUESTA.md y lo commitea
        diff NOMBRE                              diferencias entre la aprobada y la propuesta
        aprobar NOMBRE --por PERSONA             solo aprobadores de skills/config.yaml: reemplaza la aprobada,
                                                 anota en CAMBIOS.md con sello y borra la propuesta (un commit)
        rechazar NOMBRE --por PERSONA --motivo "…"  borra la propuesta y lo anota (un commit)
        enlazar claude|codex [--destino DIR]     symlinks de cada skill aprobada en ~/.claude/skills o ~/.agents/skills
                                                 (los demás agentes no se enlazan: leen skills/ de KOS)
    TXT
    o.on("--agente NOMBRE") { |v| opts[:agente] = v }
    o.on("--motivo TEXTO") { |v| opts[:motivo] = v }
    o.on("--por PERSONA") { |v| opts[:por] = v }
    o.on("--desde CARPETA") { |v| opts[:desde] = v }
    o.on("--destino DIR") { |v| opts[:destino] = v }
    o.on("--modo MODO") { |v| opts[:modo] = v }
    o.on("--como NOMBRE") { |v| opts[:como] = v }
    o.on("--fuente URL") { |v| opts[:fuente] = v }
    o.on("--ayuda", "-h") { puts o.banner; exit 0 }
  end

  begin
    args = parser.parse(ARGV)
    op, nombre = args

    case op
    when "validar"
      errores, avisos = KosSkills.revisar(ROOT)
      aprobadas = SKILLS.directory? ? SKILLS.children.count { |d| d.directory? && !d.basename.to_s.start_with?("_", ".") } : 0
      puts "Skills: #{aprobadas} | Errores: #{errores.size} | Avisos: #{avisos.size}"
      errores.each { |c, f, m| puts "ERROR [#{c}] #{f} — #{m}" }
      avisos.each { |c, f, m| puts "WARN  [#{c}] #{f} — #{m}" }
      exit(errores.empty? ? 0 : 1)

    when "estado"
      errores, = KosSkills.revisar(ROOT)
      SKILLS.children.select(&:directory?).reject { |d| d.basename.to_s.start_with?("_", ".") }.sort.each do |dir|
        data, = KosSkills.frontmatter(dir.join("SKILL.md")) rescue nil
        meta = data.is_a?(Hash) && data["metadata"].is_a?(Hash) ? data["metadata"] : {}
        mal = errores.any? { |_, f, _| f == "skills/#{dir.basename}" }
        lugares = DESTINOS.transform_values { |d| Pathname.new(File.expand_path(d)) }
        lugares = { "claude-kos" => ROOT.join(".claude/skills") }.merge(lugares) if ROOT.join(".claude/skills").directory?
        enlaces = lugares.map do |agente, d|
          link = d.join(dir.basename)
          ok = link.symlink? && File.realpath(link) == File.realpath(dir) rescue false
          "#{agente}:#{ok ? "sí" : "no"}"
        end
        puts "#{dir.basename} v#{meta["version"]} (#{meta["origen"]}) #{mal ? "CON ERRORES" : "ok"} · #{enlaces.join(" ")}"
      end
      pend = PROPUESTAS.directory? ? PROPUESTAS.children.select(&:directory?) : []
      puts pend.empty? ? "Propuestas pendientes: ninguna" : "Propuestas pendientes: #{pend.map { |p| p.basename.to_s + (p.join("PROPUESTA.md").file? ? "" : " (borrador sin entregar)") }.join(", ")}"

    when "proponer"
      nombre!(nombre)
      dest = PROPUESTAS.join(nombre)
      raise KosError, "Ya hay una propuesta para #{nombre} en #{dest.relative_path_from(ROOT)}; seguí editándola" if dest.exist?
      origen = opts[:desde] ? Pathname.new(File.expand_path(opts[:desde])) : SKILLS.join(nombre)
      if opts[:desde] && origen.join("SKILL.md").file? && !(senales = KosSkills.senales_de_tercero(origen)).empty?
        raise KosError, "Parece una skill de otra persona (#{senales.join("; ")}). Usá: ruby tools/kos_skills.rb importar #{opts[:desde]}"
      end
      FileUtils.mkdir_p(dest)
      if origen.directory?
        KosSkills.archivos(origen).each do |r|
          next if r == "CAMBIOS.md" || r == "evals/resultados.md"
          FileUtils.mkdir_p(dest.join(r).dirname)
          FileUtils.cp(origen.join(r), dest.join(r))
        end
      elsif opts[:desde]
        raise KosError, "No existe la carpeta #{origen}"
      else
        dest.join("evals").mkpath
        File.write(dest.join("SKILL.md"), "---\nname: #{nombre}\ndescription: Qué hace y cuándo usarla (con palabras que el pedido va a tener).\nmetadata:\n  origen: propia\n  version: \"1.0\"\n---\n\n# #{nombre}\n\n## Pasos\n1. \n\n## Formato de salida\n- \n\n## Autochequeo antes de entregar\n- [ ] \n")
        File.write(dest.join("evals/casos.md"), "# Casos de prueba: #{nombre}\n\n## Caso 1\nPedido: …\nDebe salir: …\n")
      end
      FileUtils.chmod_R("g+w", dest) rescue nil
      puts "Borrador listo en #{dest.relative_path_from(ROOT)}/. Editalo y después: ruby tools/kos_skills.rb entregar #{nombre} --agente <vos> --motivo \"…\""

    when "importar"
      raise KosError.new("Falta la carpeta de la skill (si está en GitHub, primero git clone a /tmp)", 2) if nombre.to_s.empty?
      src = Pathname.new(File.expand_path(nombre))
      raise KosError, "No hay SKILL.md en #{src}" unless src.join("SKILL.md").file?
      data, problema = KosSkills.frontmatter(src.join("SKILL.md"))
      raise KosError, "SKILL.md inválido: #{problema}" if problema
      nuevo = nombre!(opts[:como] || data["name"].to_s)
      senales = KosSkills.senales_de_tercero(src)
      raise KosError, "#{nuevo} dice ser propia (metadata.origen: propia). Usá: ruby tools/kos_skills.rb proponer #{nuevo} --desde #{nombre}" if senales.empty?
      raise KosError, "Ya existe skills/#{nuevo}. Elegí otro nombre con --como" if SKILLS.join(nuevo).exist?
      dest = PROPUESTAS.join(nuevo)
      raise KosError, "Ya hay una propuesta para #{nuevo}" if dest.exist?
      meta = data["metadata"].is_a?(Hash) ? data["metadata"] : {}
      remoto, = Open3.capture2("git", "-C", src.to_s, "remote", "get-url", "origin", err: File::NULL)
      fuente = opts[:fuente] || (remoto.strip.empty? ? src.to_s : "#{remoto.strip} (#{src.basename})")
      licencia = data["license"].to_s.strip
      riesgos = KosSkills.riesgos(src)
      puts "Esta skill es de otra persona."
      puts "  Nombre: #{data["name"]} | Autor: #{meta["author"] || "sin dato"} | Fuente: #{fuente}"
      puts "  Licencia: #{licencia.empty? ? "NINGUNA" : licencia}"
      puts "  Señales: #{senales.join("; ")}"
      puts "  Archivos: #{KosSkills.archivos(src).size}#{src.join("scripts").exist? ? " (trae scripts/: hay que leerlos enteros)" : ""}"
      puts riesgos.empty? ? "  Riesgos detectados: ninguno" : "  Riesgos detectados:\n" + riesgos.map { |r| "    - #{r}" }.join("\n")
      raise KosError, "Sin licencia no se puede usar ni adaptar: es de su autor. Pedile permiso o buscá una con licencia." if licencia.empty?

      modo = opts[:modo]
      if modo.nil?
        pregunta = "¿La importás tal cual o preferís adaptarla a nuestro sistema para evitar errores y problemas?"
        unless $stdin.tty?
          raise KosError.new("#{pregunta}\nAgente: preguntale a la persona y repetí con --modo tal-cual o --modo adaptar.", 3)
        end
        print "#{pregunta}\n  1) tal cual\n  2) adaptarla (recomendado)\nElegí 1 o 2 [2]: "
        modo = $stdin.gets.to_s.strip == "1" ? "tal-cual" : "adaptar"
      end
      raise KosError.new("--modo es tal-cual o adaptar", 2) unless %w[tal-cual adaptar].include?(modo)

      FileUtils.mkdir_p(dest.join("evals"))
      casos = "# Casos de prueba: #{nuevo}\n\nCompletar antes de entregar: 3 a 5 pedidos reales y qué tiene que salir.\n\n## Caso 1\nPedido: …\nDebe salir: …\n"
      if modo == "tal-cual"
        KosSkills.archivos(src).each do |r|
          FileUtils.mkdir_p(dest.join(r).dirname)
          FileUtils.cp(src.join(r), dest.join(r))
        end
        texto = src.join("SKILL.md").read
        cuerpo = texto.sub(/\A---\s*\n.*?\n---\s*\n?/m, "")
        data["name"] = nuevo
        data["metadata"] = meta.merge("origen" => "tercero", "fuente" => fuente, "version" => (meta["version"] || "1.0").to_s)
        File.write(dest.join("SKILL.md"), data.to_yaml + "---\n" + cuerpo)
        File.write(dest.join("evals/casos.md"), casos) unless dest.join("evals/casos.md").file?
        puts "Copiada tal cual en #{dest.relative_path_from(ROOT)}/ (solo cambió el bloque YAML: origen, fuente, nombre)."
      else
        KosSkills.archivos(src).each do |r| # el original queda aparte, solo como referencia: no se commitea
          FileUtils.mkdir_p(dest.join(".original", r).dirname)
          FileUtils.cp(src.join(r), dest.join(".original", r))
        end
        desc = data["description"].to_s.strip.gsub(/\s+/, " ")
        File.write(dest.join("SKILL.md"), { "name" => nuevo, "description" => desc, "license" => licencia,
                                             "metadata" => { "origen" => "adaptada", "fuente" => fuente, "version" => "1.0" } }.to_yaml +
                                           "---\n\n# #{nuevo}\n\nAdaptada de #{fuente} (#{licencia}).\n\n## Pasos\n1. \n\n## Formato de salida\n- \n\n## Autochequeo antes de entregar\n- [ ] \n")
        File.write(dest.join("evals/casos.md"), casos)
        puts "Borrador para adaptar en #{dest.relative_path_from(ROOT)}/. El original está en .original/ (no se commitea)."
        puts "Reescribí SKILL.md con el formato de KOS (español, pasos, formato de salida, autochequeo). No copies scripts sin revisarlos."
      end
      FileUtils.chmod_R("g+w", dest) rescue nil
      puts "Después: completá evals/casos.md y ruby tools/kos_skills.rb entregar #{nuevo} --agente <vos> --motivo \"…\""

    when "entregar"
      nombre!(nombre)
      raise KosError.new("Falta --agente", 2) if opts[:agente].empty?
      raise KosError.new("Falta --motivo", 2) if opts[:motivo].to_s.strip.empty?
      dir = PROPUESTAS.join(nombre)
      raise KosError, "No hay borrador en skills/_propuestas/#{nombre}/ (usá 'proponer')" unless dir.directory?
      chequear!(dir, nombre)
      nota = "# Propuesta: #{nombre}\n\n- agente: #{opts[:agente]}\n- fecha: #{TODAY}\n- motivo: #{opts[:motivo].strip}\n- base: #{KosSkills.ultimo_sello(SKILLS.join(nombre)) || "skill nueva"}\n"
      File.write(dir.join("PROPUESTA.md"), nota)
      with_lock do
        escribir = KosSkills.archivos(dir).to_h { |r| ["skills/_propuestas/#{nombre}/#{r}", dir.join(r).binread] }
        puts commit(escribir, [], opts[:agente], "skills: propuesta de #{nombre} (#{opts[:agente]})")
      end
      puts "Propuesta entregada. Falta que la apruebe alguien de skills/config.yaml."

    when "diff"
      nombre!(nombre)
      a = SKILLS.join(nombre)
      b = PROPUESTAS.join(nombre)
      raise KosError, "No hay propuesta para #{nombre}" unless b.directory?
      puts "Skill nueva." unless a.directory?
      Dir.mktmpdir("kos-skills-diff-") do |tmp| # solo lo que forma la skill: sin CAMBIOS, resultados ni PROPUESTA
        { "aprobada" => a, "propuesta" => b }.each do |lado, dir|
          FileUtils.mkdir_p(File.join(tmp, lado))
          next unless dir.directory?
          (KosSkills.archivos(dir) - KosSkills::SIN_SELLO - ["PROPUESTA.md"]).each do |r|
            FileUtils.mkdir_p(File.join(tmp, lado, File.dirname(r)))
            FileUtils.cp(dir.join(r), File.join(tmp, lado, r))
          end
        end
        out, = Open3.capture2("git", "diff", "--no-index", "--stat", "--patch", "--", "aprobada", "propuesta", chdir: tmp)
        puts out.empty? ? "Sin diferencias." : out
      end

    when "aprobar", "rechazar"
      nombre!(nombre)
      raise KosError.new("Falta --por", 2) if opts[:por].to_s.empty?
      aprobadores = Array(KosSkills.config(ROOT)["aprobadores"]).map(&:to_s)
      raise KosError, "#{opts[:por]} no está en aprobadores (skills/config.yaml: #{aprobadores.join(", ")})" unless aprobadores.include?(opts[:por])
      prop = PROPUESTAS.join(nombre)
      raise KosError, "No hay propuesta para #{nombre}" unless prop.directory?
      nota = prop.join("PROPUESTA.md").file? ? prop.join("PROPUESTA.md").read : ""
      agente = nota[/^- agente: (.+)$/, 1] || "sin dato"
      motivo = nota[/^- motivo: (.+)$/, 1] || "sin dato"
      skill = SKILLS.join(nombre)
      viejos = skill.directory? ? KosSkills.archivos(skill) : []
      cambios_prev = skill.join("CAMBIOS.md").file? ? skill.join("CAMBIOS.md").read : "# Cambios de #{nombre}\n\nCada aprobación deja un sello. Lo genera tools/kos_skills.rb; no se edita a mano.\n"
      borrar = KosSkills.archivos(prop).map { |r| "skills/_propuestas/#{nombre}/#{r}" }

      if op == "rechazar"
        raise KosError.new("Falta --motivo", 2) if opts[:motivo].to_s.strip.empty?
        escribir = {}
        if skill.directory?
          entrada = "\n## #{TODAY} — propuesta rechazada\n- propuso: #{agente}\n- motivo de la propuesta: #{motivo}\n- rechazó: #{opts[:por]} (#{opts[:motivo].strip})\n"
          escribir["skills/#{nombre}/CAMBIOS.md"] = cambios_prev + entrada
        end
        with_lock { puts commit(escribir, borrar, opts[:por], "skills: propuesta de #{nombre} rechazada (#{opts[:por]})") }
        FileUtils.rm_rf(prop)
        puts "Propuesta rechazada y borrada."
      else
        chequear!(prop, nombre)
        data, = KosSkills.frontmatter(prop.join("SKILL.md"))
        version = data.dig("metadata", "version").to_s
        Dir.mktmpdir("kos-skills-nueva-") do |tmp|
          nueva = Pathname.new(tmp)
          KosSkills.archivos(prop).each do |r|
            next if r == "PROPUESTA.md"
            FileUtils.mkdir_p(nueva.join(r).dirname)
            FileUtils.cp(prop.join(r), nueva.join(r))
          end
          resultados = skill.join("evals/resultados.md")
          if resultados.file?
            FileUtils.mkdir_p(nueva.join("evals"))
            FileUtils.cp(resultados, nueva.join("evals/resultados.md"))
          end
          s = KosSkills.sello(nueva)
          entrada = "\n## #{TODAY} — versión #{version}\n- propuso: #{agente}\n- motivo: #{motivo}\n- aprobó: #{opts[:por]}\n- sello: `#{s}`\n"
          File.write(nueva.join("CAMBIOS.md"), cambios_prev + entrada)
          nuevos = KosSkills.archivos(nueva)
          escribir = nuevos.to_h { |r| ["skills/#{nombre}/#{r}", nueva.join(r).binread] }
          quitar = (viejos - nuevos).map { |r| "skills/#{nombre}/#{r}" } + borrar
          with_lock { puts commit(escribir, quitar, opts[:por], "skills: #{nombre} #{version} aprobada (#{opts[:por]})") }
        end
        FileUtils.rm_rf(prop)
        FileUtils.chmod_R("g+w", skill) rescue nil
        # Enlaza la skill nueva donde ya hay skills enlazadas: en este KOS (.claude/skills) y en la carpeta del usuario.
        ([ROOT.join(".claude/skills")] + DESTINOS.values.map { |d| Pathname.new(File.expand_path(d)) }).each do |dir|
          link = dir.join(nombre)
          KosSkills.enlazar(skill, link, ROOT) if dir.directory? && !link.exist? && !link.symlink?
        end
        puts "#{nombre} #{version} aprobada. Claude Code (y Codex si está) ya la ven; los demás agentes la leen de skills/."
      end
      borrar_vacias(PROPUESTAS)
      Dir.rmdir(PROPUESTAS) if PROPUESTAS.directory? && Dir.empty?(PROPUESTAS)

    when "enlazar"
      raise KosError.new("Decí a qué agente: #{DESTINOS.keys.join(" o ")}", 2) unless DESTINOS.key?(nombre)
      destino = Pathname.new(File.expand_path(opts[:destino] || DESTINOS[nombre]))
      FileUtils.mkdir_p(destino)
      SKILLS.children.select(&:directory?).reject { |d| d.basename.to_s.start_with?("_", ".") }.sort.each do |dir|
        link = destino.join(dir.basename)
        if link.symlink? && File.realpath(link) == File.realpath(dir)
          puts "ya enlazada: #{link}"
        elsif link.exist? || link.symlink?
          puts "OCUPADO, no la toco: #{link} (movela a un respaldo y volvé a correr)"
        else
          KosSkills.enlazar(dir, link, ROOT)
          puts "enlazada: #{link} -> #{File.readlink(link)}"
        end
      end

    else
      raise KosError.new(parser.banner, 2)
    end
  rescue KosError => e
    warn e.message
    exit e.code
  rescue OptionParser::ParseError => e
    warn e.message
    exit 2
  end
end
