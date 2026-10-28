#!/usr/bin/env ruby
# encoding: utf-8
Encoding.default_external = Encoding::UTF_8

# kos_skills.rb — Skills compartidas entre agentes de IA (Claude Code, Codex y los que lean archivos) dentro de KOS.
# Shared skills for every AI agent in a KOS (Claude Code, Codex and any agent that reads files).
#
# Las skills aprobadas viven en skills/<nombre>/ (formato abierto SKILL.md, agentskills.io).
# Ningún agente las cambia directo: propone en skills/_propuestas/<nombre>/ y una persona de
# skills/config.yaml (aprobadores) aprueba. Cada aprobación deja un sello en CAMBIOS.md; si la skill
# cambia sin pasar por aprobar, kos_validate.rb da error.
#
# Idioma: el de kos.yaml (lang: en → inglés; si no, español). En inglés cambian los mensajes y los
# nombres de archivos (_proposals/, CHANGES.md, evals/cases.md, approvers, origin…). Los comandos y
# opciones se aceptan en los dos idiomas.
#
# Uso / Usage: ruby tools/kos_skills.rb <operación|command> [opciones|options]   (--ayuda / --help)
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

  # Nombres de archivos, claves y valores según el idioma del KOS.
  NOMBRES = {
    "es" => { propuestas: "_propuestas", casos: "evals/casos.md", resultados: "evals/resultados.md", cambios: "CAMBIOS.md",
              nota: "PROPUESTA.md", aprobadores: "aprobadores", origenes: "origenes", origen: "origen", fuente: "fuente",
              propia: "propia", adaptada: "adaptada", tercero: "tercero", sello: "sello", agente: "agente", motivo: "motivo" },
    "en" => { propuestas: "_proposals", casos: "evals/cases.md", resultados: "evals/results.md", cambios: "CHANGES.md",
              nota: "PROPOSAL.md", aprobadores: "approvers", origenes: "origins", origen: "origin", fuente: "source",
              propia: "own", adaptada: "adapted", tercero: "third-party", sello: "seal", agente: "agent", motivo: "reason" }
  }.freeze

  # Señales de riesgo en skills ajenas. Son avisos: los lee una persona antes de aprobar.
  RIESGOS = {
    ["descarga y ejecuta código", "downloads and runs code"] => /(curl|wget)[^\n|]*\|\s*(ba|z)?sh|\b(npx|pipx|uvx)\s+\S/i,
    ["borrado masivo", "mass deletion"] => /rm\s+-rf?\s+[\/~$]/,
    ["usa sudo", "uses sudo"] => /\bsudo\s/,
    ["pide ignorar instrucciones", "asks to ignore instructions"] => /\bignor(e|ar|á)\b.{0,25}(previous|prior|above|instrucciones|anteriores)/i,
    ["texto oculto (comentario HTML)", "hidden text (HTML comment)"] => /<!--.*?-->/m,
    ["decodifica base64", "decodes base64"] => /base64\s+(-d|--decode)/,
    ["toca credenciales", "touches credentials"] => /(\.ssh\/|\.env\b|id_rsa|api[_-]?key|auth\.json)/i
  }.freeze

  module_function

  # Fija el idioma a partir de kos.yaml de ese KOS (o a mano: "es" / "en").
  def idioma!(root_o_lang)
    @lang = if %w[es en].include?(root_o_lang.to_s)
              root_o_lang.to_s
            else
              (File.read(Pathname.new(root_o_lang).join("kos.yaml"))[/^lang:\s*(\w+)/, 1] == "en" rescue false) ? "en" : "es"
            end
  end

  def lang = (@lang ||= "es")
  def n = NOMBRES.fetch(lang)
  def t(es, en) = lang == "en" ? en : es
  def sin_sello = [n[:cambios], n[:resultados]] # cambian sin pasar por aprobar

  def config(root)
    file = root.join("skills/config.yaml")
    data = file.file? ? (YAML.safe_load(file.read) || {}) : {}
    { "aprobadores" => Array(data[n[:aprobadores]] || data["aprobadores"] || data["approvers"]).map(&:to_s),
      "origenes" => Array(data[n[:origenes]]).map(&:to_s).then { |o| o.empty? ? [n[:propia], n[:adaptada], n[:tercero]] : o } }
  rescue StandardError
    { "aprobadores" => [], "origenes" => [n[:propia], n[:adaptada], n[:tercero]] }
  end

  # Enlace simbólico; si queda dentro del mismo KOS, relativo (así sirve en otra máquina).
  def enlazar(dir, link, root)
    destino = link.dirname.expand_path.to_s.start_with?(root.expand_path.to_s + "/") ? dir.relative_path_from(link.dirname.expand_path) : dir
    File.symlink(destino, link)
  end

  def frontmatter(file)
    text = file.read
    m = text.match(/\A---\s*\n(.*?)\n---\s*(\n|\z)/m)
    return [nil, t("falta el bloque YAML inicial (--- ... ---)", "missing the opening YAML block (--- ... ---)")] unless m
    data = YAML.safe_load(m[1])
    data.is_a?(Hash) ? [data, nil] : [nil, t("el bloque YAML no es un mapa", "the YAML block is not a map")]
  rescue StandardError => e
    [nil, t("YAML inválido: ", "invalid YAML: ") + e.message.lines.first.strip]
  end

  def meta(data) = data.is_a?(Hash) && data["metadata"].is_a?(Hash) ? data["metadata"] : {}

  # Archivos que forman la skill (los que entran al sello), relativos a su carpeta.
  def archivos(dir)
    Dir.glob("**/*", File::FNM_DOTMATCH, base: dir.to_s)
       .reject { |r| r.split("/").any? { |p| p.start_with?(".") } || r.end_with?(".kos-new") } # .kos-new: lo deja kos_update
       .select { |r| dir.join(r).file? }
       .sort
  end

  def sello(dir)
    d = Digest::SHA256.new
    (archivos(dir) - sin_sello - [n[:nota]]).each { |r| d << r << "\0" << dir.join(r).binread << "\0" }
    d.hexdigest[0, 16]
  end

  def ultimo_sello(dir)
    f = dir.join(n[:cambios])
    f.file? ? f.read.scan(/^- (?:sello|seal): `?([0-9a-f]{16})`?/).flatten.last : nil
  end

  # Revisa una carpeta de skill. Devuelve [[código, mensaje], ...] de errores y de avisos.
  def revisar_skill(dir, nombre, origenes)
    errores = []
    avisos = []
    md = dir.join("SKILL.md")
    return [[["skill-sin-skill-md", t("falta SKILL.md", "missing SKILL.md")]], []] unless md.file?

    data, problema = frontmatter(md)
    return [[["skill-frontmatter", problema]], []] if problema

    errores << ["skill-nombre", t("name '#{data["name"]}' no coincide con la carpeta '#{nombre}'", "name '#{data["name"]}' does not match the folder '#{nombre}'")] if data["name"] != nombre
    errores << ["skill-nombre", t("'#{nombre}': solo minúsculas, números y guiones simples, hasta 64", "'#{nombre}': lowercase letters, digits and single hyphens only, up to 64")] unless nombre.match?(NAME_RE) && nombre.size <= 64
    desc = data["description"].to_s.strip
    errores << ["skill-descripcion", t("description vacía o de más de 1024 caracteres", "description empty or longer than 1024 characters")] if desc.empty? || desc.size > 1024
    (data.keys - CAMPOS).each do |k|
      avisos << ["skill-campo-no-portable", t("campo '#{k}': otros agentes lo ignoran; úsalo solo si hace falta", "field '#{k}': other agents ignore it; use it only if needed")]
    end
    m = meta(data)
    origen = m[n[:origen]].to_s
    errores << ["skill-origen", t("metadata.#{n[:origen]} debe ser uno de: ", "metadata.#{n[:origen]} must be one of: ") + origenes.join(", ")] unless origenes.include?(origen)
    if origen != n[:propia] && !origen.empty? && m[n[:fuente]].to_s.strip.empty?
      errores << ["skill-fuente", t("origen '#{origen}': falta metadata.#{n[:fuente]} (de dónde viene)", "origin '#{origen}': missing metadata.#{n[:fuente]} (where it comes from)")]
    end
    if origen == n[:tercero] && data["license"].to_s.strip.empty?
      errores << ["skill-licencia", t("skill de otra persona sin license: no se puede usar sin permiso del autor", "someone else's skill without license: it cannot be used without the author's permission")]
    end
    errores << ["skill-version", t("falta metadata.version (texto, ej. \"1.0\")", "missing metadata.version (text, e.g. \"1.0\")")] if m["version"].to_s.strip.empty?
    errores << ["skill-sin-evals", t("falta #{n[:casos]} (pedidos de prueba y qué debe salir)", "missing #{n[:casos]} (test requests and what must come out)")] unless dir.join(n[:casos]).file?
    avisos << ["skill-con-scripts", t("tiene scripts/: revísalos a mano antes de aprobar", "has scripts/: read them by hand before approving")] if dir.join("scripts").exist?
    riesgos(dir).each { |r| avisos << ["skill-riesgo", r] }
    [errores, avisos]
  end

  # Busca señales de RIESGOS en los archivos de texto de la skill (sin evals ni historial).
  def riesgos(dir)
    (archivos(dir) - sin_sello - [n[:nota]]).reject { |r| r.start_with?("evals/") }.flat_map do |r|
      text = (dir.join(r).read rescue "")
      next [] unless text.valid_encoding?
      RIESGOS.filter_map { |(es, en), re| "#{r}: #{t(es, en)}" if text.match?(re) }
    end
  end

  # ¿La skill de esa carpeta es de otra persona? Devuelve las señales que lo indican (vacío = propia).
  # Una skill propia de un KOS en el otro idioma también cuenta como propia.
  def senales_de_tercero(dir)
    data, = frontmatter(dir.join("SKILL.md"))
    return [t("SKILL.md sin bloque YAML válido", "SKILL.md without a valid YAML block")] unless data
    m = meta(data)
    origen = m["origen"] || m["origin"]
    senales = []
    senales << t("metadata.origen es '#{origen}'", "metadata.origin is '#{origen}'") if origen && !%w[propia own].include?(origen)
    senales << t("no dice que sea propia (sin metadata.origen)", "it does not say it is your own (no metadata.origin)") unless origen
    senales << t("autor: ", "author: ") + m["author"].to_s if m["author"]
    senales << t("licencia: ", "license: ") + data["license"].to_s if data["license"]
    senales << t("trae archivo de licencia", "comes with a license file") if Dir.glob("{LICENSE,LICENSE.*,COPYING}*", base: dir.to_s).any?
    senales
  end

  # Revisión completa de skills/ para kos_validate.rb. Devuelve [errores, avisos] como [código, ruta, mensaje].
  def revisar(root)
    idioma!(root)
    errores = []
    avisos = []
    base = root.join("skills")
    return [errores, avisos] unless base.directory?

    cfg = config(root)
    origenes = cfg["origenes"]
    if cfg["aprobadores"].empty?
      avisos << ["skills-sin-aprobadores", "skills/config.yaml", t("falta la lista '#{n[:aprobadores]}': nadie puede aprobar skills", "missing the '#{n[:aprobadores]}' list: nobody can approve skills")]
    end

    base.children.select(&:directory?).sort.each do |dir|
      nombre = dir.basename.to_s
      next if nombre.start_with?(".")
      if nombre == n[:propuestas]
        dir.children.select(&:directory?).sort.each do |prop|
          rel = "skills/#{n[:propuestas]}/#{prop.basename}"
          e, a = revisar_skill(prop, prop.basename.to_s, origenes)
          (e + a).each { |c, msg| avisos << [c, rel, msg] }
          avisos << ["skill-propuesta-sin-nota", rel, t("falta #{n[:nota]} (usa 'entregar')", "missing #{n[:nota]} (use 'submit')")] unless prop.join(n[:nota]).file?
        end
        next
      end
      next if nombre.start_with?("_")

      rel = "skills/#{nombre}"
      e, a = revisar_skill(dir, nombre, origenes)
      e.each { |c, msg| errores << [c, rel, msg] }
      a.each { |c, msg| avisos << [c, rel, msg] }
      esperado = ultimo_sello(dir)
      if esperado.nil?
        errores << ["skill-sin-aprobar", rel, t("no tiene #{n[:cambios]} con sello: entra solo con 'proponer' + 'aprobar'", "no #{n[:cambios]} with a seal: it only gets in through 'propose' + 'approve'")]
      elsif esperado != sello(dir)
        errores << ["skill-cambiada-sin-aprobar", rel, t("cambió después de la última aprobación (sello #{esperado}); deshaz el cambio o pásalo por 'proponer' + 'aprobar'",
                                                         "changed after its last approval (seal #{esperado}); undo the change or send it through 'propose' + 'approve'")]
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
  KosSkills.idioma!(ROOT)
  N = KosSkills.n
  SKILLS = ROOT.join("skills")
  PROPUESTAS = SKILLS.join(N[:propuestas])
  LOCK_FILE = ROOT.join(".git/kos-write.lock") # el mismo candado que kos_write.rb y kos_sync.rb
  TODAY = Date.today.iso8601
  DESTINOS = { "claude" => "~/.claude/skills", "codex" => "~/.agents/skills" }.freeze
  # Comandos en inglés → nombre interno.
  ALIAS = { "status" => "estado", "validate" => "validar", "propose" => "proponer", "import" => "importar", "submit" => "entregar",
            "approve" => "aprobar", "reject" => "rechazar", "link" => "enlazar" }.freeze
  EN = KosSkills.lang == "en"

  def t(es, en) = KosSkills.t(es, en)
  def cmd(es, en) = EN ? en : es # nombre del comando para mostrar

  class KosError < StandardError
    attr_reader :code

    def initialize(msg, code = 1)
      super(msg)
      @code = code
    end
  end

  def git(*args, env: {}, stdin: nil, ok: true)
    out, err, st = Open3.capture3(env, "git", "-C", ROOT.to_s, *args, stdin_data: stdin.to_s, binmode: true)
    raise KosError, t("git #{args.first} falló: ", "git #{args.first} failed: ") + err.strip[0, 300] if ok && !st.success?
    [out.force_encoding(Encoding::UTF_8), st.success?]
  end

  def with_lock(timeout = 120)
    File.open(LOCK_FILE, File::RDWR | File::CREAT, 0o664) do |f|
      File.chmod(0o664, LOCK_FILE) rescue nil
      deadline = Time.now + timeout
      until f.flock(File::LOCK_EX | File::LOCK_NB)
        raise KosError, t("KOS ocupado más de #{timeout}s (candado #{LOCK_FILE})", "KOS busy for more than #{timeout}s (lock #{LOCK_FILE})") if Time.now > deadline
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
    raise KosError, t("HEAD cambió tres veces seguidas; prueba de nuevo", "HEAD changed three times in a row; try again")
  end

  def borrar_vacias(dir)
    Dir.glob("#{dir}/**/").sort_by { |d| -d.size }.each { |d| Dir.rmdir(d) if Dir.empty?(d) rescue nil }
  end

  def nombre!(nom)
    raise KosError.new(t("Falta el nombre de la skill", "Missing the skill name"), 2) if nom.to_s.empty?
    raise KosError.new(t("Nombre inválido '#{nom}': minúsculas, números y guiones", "Invalid name '#{nom}': lowercase letters, digits and hyphens"), 2) unless nom.match?(KosSkills::NAME_RE)
    nom
  end

  def chequear!(dir, nombre)
    errores, avisos = KosSkills.revisar_skill(dir, nombre, KosSkills.config(ROOT)["origenes"])
    avisos.each { |c, m| warn "#{t("Aviso", "Warning")} [#{c}] #{m}" }
    raise KosError, t("La skill no pasa la validación:\n", "The skill does not pass validation:\n") + errores.map { |c, m| "  [#{c}] #{m}" }.join("\n") unless errores.empty?
  end

  def yaml_skill(data, cuerpo) = data.to_yaml + "---\n" + cuerpo

  def plantilla_skill(nombre)
    yaml_skill({ "name" => nombre,
                 "description" => t("Qué hace y cuándo usarla (con palabras que el pedido va a tener).", "What it does and when to use it (with the words the request will contain)."),
                 "metadata" => { N[:origen] => N[:propia], "version" => "1.0" } },
               t("\n# #{nombre}\n\n## Pasos\n1. \n\n## Formato de salida\n- \n\n## Autochequeo antes de entregar\n- [ ] \n",
                 "\n# #{nombre}\n\n## Steps\n1. \n\n## Output format\n- \n\n## Self-check before delivering\n- [ ] \n"))
  end

  def casos_vacios(nombre)
    t("# Casos de prueba: #{nombre}\n\nCompletar antes de entregar: de 3 a 5 pedidos reales y qué tiene que salir.\n\n## Caso 1\nPedido: …\nDebe salir: …\n",
      "# Test cases: #{nombre}\n\nFill in before submitting: 3 to 5 real requests and what must come out.\n\n## Case 1\nRequest: …\nMust come out: …\n")
  end

  opts = { agente: ENV["KOS_AGENTE"].to_s }
  banner = if EN
             <<~TXT
               kos_skills.rb — Shared skills in KOS (skills/). Approved skills are never edited by hand.

               Usage: ruby tools/kos_skills.rb <command> [options]
                 status                                   approved skills, pending proposals and this user's links
                 validate                                 checks skills/ (format, test cases, seals); exits 1 on errors
                 propose NAME [--from FOLDER]             draft in skills/_proposals/NAME/ (copy of the approved one, of your
                                                          own FOLDER, or empty if new). No commit.
                 import FOLDER [--mode as-is|adapt] [--as NAME] [--source URL]
                                                          someone else's skill: shows author, license and risks and asks
                                                          whether it goes in as is or adapted to KOS. Leaves the draft in _proposals/.
                 submit NAME --agent X --reason "…"       validates the draft, adds PROPOSAL.md and commits it
                 diff NAME                                differences between the approved skill and the proposal
                 approve NAME --by PERSON                 approvers in skills/config.yaml only: replaces the approved skill,
                                                          records it in CHANGES.md with a seal and deletes the proposal (one commit)
                 reject NAME --by PERSON --reason "…"     deletes the proposal and records it (one commit)
                 link claude|codex [--dest DIR]           symlinks of each approved skill in ~/.claude/skills or ~/.agents/skills
                                                          (other agents are not linked: they read skills/ in KOS)
               Spanish command and option names also work.
             TXT
           else
             <<~TXT
               kos_skills.rb — Skills compartidas en KOS (skills/). Ninguna skill aprobada se cambia a mano.

               Uso: ruby tools/kos_skills.rb <operación> [opciones]
                 estado                                   skills aprobadas, propuestas pendientes y enlaces de este usuario
                 validar                                  revisa skills/ (formato, casos, sellos); sale con 1 si hay errores
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
               También funcionan los comandos y opciones en inglés.
             TXT
           end
  parser = OptionParser.new do |o|
    o.banner = banner
    o.on("--agente NOMBRE", "--agent NAME") { |v| opts[:agente] = v }
    o.on("--motivo TEXTO", "--reason TEXT") { |v| opts[:motivo] = v }
    o.on("--por PERSONA", "--by PERSON") { |v| opts[:por] = v }
    o.on("--desde CARPETA", "--from FOLDER") { |v| opts[:desde] = v }
    o.on("--destino DIR", "--dest DIR") { |v| opts[:destino] = v }
    o.on("--modo MODO", "--mode MODE") { |v| opts[:modo] = v }
    o.on("--como NOMBRE", "--as NAME") { |v| opts[:como] = v }
    o.on("--fuente URL", "--source URL") { |v| opts[:fuente] = v }
    o.on("--ayuda", "--help", "-h") { puts o.banner; exit 0 }
  end

  begin
    args = parser.parse(ARGV)
    op, nombre = args
    op = ALIAS.fetch(op, op)

    case op
    when "validar"
      errores, avisos = KosSkills.revisar(ROOT)
      aprobadas = SKILLS.directory? ? SKILLS.children.count { |d| d.directory? && !d.basename.to_s.start_with?("_", ".") } : 0
      puts "Skills: #{aprobadas} | #{t("Errores", "Errors")}: #{errores.size} | #{t("Avisos", "Warnings")}: #{avisos.size}"
      errores.each { |c, f, m| puts "ERROR [#{c}] #{f} — #{m}" }
      avisos.each { |c, f, m| puts "WARN  [#{c}] #{f} — #{m}" }
      exit(errores.empty? ? 0 : 1)

    when "estado"
      errores, = KosSkills.revisar(ROOT)
      (SKILLS.directory? ? SKILLS.children : []).select(&:directory?).reject { |d| d.basename.to_s.start_with?("_", ".") }.sort.each do |dir|
        data, = KosSkills.frontmatter(dir.join("SKILL.md")) rescue nil
        meta = KosSkills.meta(data)
        mal = errores.any? { |_, f, _| f == "skills/#{dir.basename}" }
        lugares = DESTINOS.transform_values { |d| Pathname.new(File.expand_path(d)) }
        lugares = { "claude-kos" => ROOT.join(".claude/skills") }.merge(lugares) if ROOT.join(".claude/skills").directory?
        enlaces = lugares.map do |agente, d|
          link = d.join(dir.basename)
          ok = link.symlink? && File.realpath(link) == File.realpath(dir) rescue false
          "#{agente}:#{ok ? t("sí", "yes") : "no"}"
        end
        puts "#{dir.basename} v#{meta["version"]} (#{meta[N[:origen]]}) #{mal ? t("CON ERRORES", "WITH ERRORS") : "ok"} · #{enlaces.join(" ")}"
      end
      pend = PROPUESTAS.directory? ? PROPUESTAS.children.select(&:directory?) : []
      lista = pend.map { |p| p.basename.to_s + (p.join(N[:nota]).file? ? "" : t(" (borrador sin entregar)", " (draft not submitted)")) }
      puts t("Propuestas pendientes: ", "Pending proposals: ") + (lista.empty? ? t("ninguna", "none") : lista.join(", "))

    when "proponer"
      nombre!(nombre)
      dest = PROPUESTAS.join(nombre)
      raise KosError, t("Ya hay una propuesta para #{nombre} en #{dest.relative_path_from(ROOT)}; sigue editándola", "There is already a proposal for #{nombre} in #{dest.relative_path_from(ROOT)}; keep editing it") if dest.exist?
      origen = opts[:desde] ? Pathname.new(File.expand_path(opts[:desde])) : SKILLS.join(nombre)
      if opts[:desde] && origen.join("SKILL.md").file? && !(senales = KosSkills.senales_de_tercero(origen)).empty?
        raise KosError, t("Parece una skill de otra persona (#{senales.join("; ")}). Usa: ", "It looks like someone else's skill (#{senales.join("; ")}). Use: ") +
                        "ruby tools/kos_skills.rb #{cmd("importar", "import")} #{opts[:desde]}"
      end
      FileUtils.mkdir_p(dest)
      if origen.directory?
        KosSkills.archivos(origen).each do |r|
          next if KosSkills.sin_sello.include?(r)
          FileUtils.mkdir_p(dest.join(r).dirname)
          FileUtils.cp(origen.join(r), dest.join(r))
        end
      elsif opts[:desde]
        raise KosError, t("No existe la carpeta #{origen}", "Folder #{origen} does not exist")
      else
        dest.join("evals").mkpath
        File.write(dest.join("SKILL.md"), plantilla_skill(nombre))
        File.write(dest.join(N[:casos]), casos_vacios(nombre))
      end
      FileUtils.chmod_R("g+w", dest) rescue nil
      puts t("Borrador listo en #{dest.relative_path_from(ROOT)}/. Edítalo y después: ", "Draft ready in #{dest.relative_path_from(ROOT)}/. Edit it and then: ") +
           "ruby tools/kos_skills.rb #{cmd("entregar", "submit")} #{nombre} #{cmd("--agente", "--agent")} <#{t("tu-nombre", "your-name")}> #{cmd("--motivo", "--reason")} \"…\""

    when "importar"
      raise KosError.new(t("Falta la carpeta de la skill (si está en GitHub, primero git clone a /tmp)", "Missing the skill folder (if it is on GitHub, git clone it to /tmp first)"), 2) if nombre.to_s.empty?
      src = Pathname.new(File.expand_path(nombre))
      raise KosError, t("No hay SKILL.md en #{src}", "No SKILL.md in #{src}") unless src.join("SKILL.md").file?
      data, problema = KosSkills.frontmatter(src.join("SKILL.md"))
      raise KosError, "SKILL.md: #{problema}" if problema
      nuevo = nombre!(opts[:como] || data["name"].to_s)
      senales = KosSkills.senales_de_tercero(src)
      if senales.empty?
        raise KosError, t("#{nuevo} dice ser propia. Usa: ", "#{nuevo} says it is your own. Use: ") +
                        "ruby tools/kos_skills.rb #{cmd("proponer", "propose")} #{nuevo} #{cmd("--desde", "--from")} #{nombre}"
      end
      raise KosError, t("Ya existe skills/#{nuevo}. Elige otro nombre con --como", "skills/#{nuevo} already exists. Pick another name with --as") if SKILLS.join(nuevo).exist?
      dest = PROPUESTAS.join(nuevo)
      raise KosError, t("Ya hay una propuesta para #{nuevo}", "There is already a proposal for #{nuevo}") if dest.exist?
      meta = KosSkills.meta(data)
      remoto, = Open3.capture2("git", "-C", src.to_s, "remote", "get-url", "origin", err: File::NULL)
      fuente = opts[:fuente] || (remoto.strip.empty? ? src.to_s : "#{remoto.strip} (#{src.basename})")
      licencia = data["license"].to_s.strip
      riesgos = KosSkills.riesgos(src)
      puts t("Esta skill es de otra persona.", "This skill is someone else's.")
      puts "  #{t("Nombre", "Name")}: #{data["name"]} | #{t("Autor", "Author")}: #{meta["author"] || t("sin dato", "unknown")} | #{t("Fuente", "Source")}: #{fuente}"
      puts "  #{t("Licencia", "License")}: #{licencia.empty? ? t("NINGUNA", "NONE") : licencia}"
      puts "  #{t("Señales", "Signals")}: #{senales.join("; ")}"
      puts "  #{t("Archivos", "Files")}: #{KosSkills.archivos(src).size}#{src.join("scripts").exist? ? t(" (trae scripts/: hay que leerlos enteros)", " (has scripts/: read them in full)") : ""}"
      puts riesgos.empty? ? t("  Riesgos detectados: ninguno", "  Risks found: none") : t("  Riesgos detectados:\n", "  Risks found:\n") + riesgos.map { |r| "    - #{r}" }.join("\n")
      raise KosError, t("Sin licencia no se puede usar ni adaptar: es de su autor. Pide permiso o busca una con licencia.",
                        "Without a license it cannot be used or adapted: it belongs to its author. Ask for permission or find a licensed one.") if licencia.empty?

      modo = { "as-is" => "tal-cual", "adapt" => "adaptar" }.fetch(opts[:modo].to_s, opts[:modo])
      if modo.nil?
        pregunta = t("¿La importas tal cual o prefieres adaptarla a nuestro sistema para evitar errores y problemas?",
                     "Do you want to import it as is, or adapt it to our system to avoid errors and problems?")
        unless $stdin.tty?
          raise KosError.new(pregunta + t("\nAgente: pregúntale a la persona y repite con --modo tal-cual o --modo adaptar.",
                                          "\nAgent: ask the person and run it again with --mode as-is or --mode adapt."), 3)
        end
        print pregunta + t("\n  1) tal cual\n  2) adaptarla (recomendado)\nElige 1 o 2 [2]: ", "\n  1) as is\n  2) adapt it (recommended)\nChoose 1 or 2 [2]: ")
        modo = $stdin.gets.to_s.strip == "1" ? "tal-cual" : "adaptar"
      end
      raise KosError.new(t("--modo es tal-cual o adaptar", "--mode is as-is or adapt"), 2) unless %w[tal-cual adaptar].include?(modo)

      FileUtils.mkdir_p(dest.join("evals"))
      if modo == "tal-cual"
        KosSkills.archivos(src).each do |r|
          FileUtils.mkdir_p(dest.join(r).dirname)
          FileUtils.cp(src.join(r), dest.join(r))
        end
        cuerpo = src.join("SKILL.md").read.sub(/\A---\s*\n.*?\n---\s*\n?/m, "")
        data["name"] = nuevo
        data["metadata"] = meta.merge(N[:origen] => N[:tercero], N[:fuente] => fuente, "version" => (meta["version"] || "1.0").to_s)
        File.write(dest.join("SKILL.md"), yaml_skill(data, cuerpo))
        File.write(dest.join(N[:casos]), casos_vacios(nuevo)) unless dest.join(N[:casos]).file?
        puts t("Copiada tal cual en #{dest.relative_path_from(ROOT)}/ (solo cambió el bloque YAML: origen, fuente, nombre).",
               "Copied as is into #{dest.relative_path_from(ROOT)}/ (only the YAML block changed: origin, source, name).")
      else
        KosSkills.archivos(src).each do |r| # el original queda aparte, solo como referencia: no se commitea
          FileUtils.mkdir_p(dest.join(".original", r).dirname)
          FileUtils.cp(src.join(r), dest.join(".original", r))
        end
        desc = data["description"].to_s.strip.gsub(/\s+/, " ")
        File.write(dest.join("SKILL.md"),
                   yaml_skill({ "name" => nuevo, "description" => desc, "license" => licencia,
                                "metadata" => { N[:origen] => N[:adaptada], N[:fuente] => fuente, "version" => "1.0" } },
                              t("\n# #{nuevo}\n\nAdaptada de #{fuente} (#{licencia}).\n\n## Pasos\n1. \n\n## Formato de salida\n- \n\n## Autochequeo antes de entregar\n- [ ] \n",
                                "\n# #{nuevo}\n\nAdapted from #{fuente} (#{licencia}).\n\n## Steps\n1. \n\n## Output format\n- \n\n## Self-check before delivering\n- [ ] \n")))
        File.write(dest.join(N[:casos]), casos_vacios(nuevo))
        puts t("Borrador para adaptar en #{dest.relative_path_from(ROOT)}/. El original está en .original/ (no se commitea).",
               "Draft to adapt in #{dest.relative_path_from(ROOT)}/. The original is in .original/ (not committed).")
        puts t("Reescribe SKILL.md con el formato de KOS (pasos, formato de salida, autochequeo). No copies scripts sin revisarlos.",
               "Rewrite SKILL.md in KOS format (steps, output format, self-check). Do not copy scripts without reviewing them.")
      end
      FileUtils.chmod_R("g+w", dest) rescue nil
      puts t("Después: completa #{N[:casos]} y ", "Then: fill in #{N[:casos]} and ") +
           "ruby tools/kos_skills.rb #{cmd("entregar", "submit")} #{nuevo} #{cmd("--agente", "--agent")} <#{t("tu-nombre", "your-name")}> #{cmd("--motivo", "--reason")} \"…\""

    when "entregar"
      nombre!(nombre)
      raise KosError.new(t("Falta --agente", "Missing --agent"), 2) if opts[:agente].empty?
      raise KosError.new(t("Falta --motivo", "Missing --reason"), 2) if opts[:motivo].to_s.strip.empty?
      dir = PROPUESTAS.join(nombre)
      raise KosError, t("No hay borrador en skills/#{N[:propuestas]}/#{nombre}/ (usa 'proponer')", "No draft in skills/#{N[:propuestas]}/#{nombre}/ (use 'propose')") unless dir.directory?
      chequear!(dir, nombre)
      base = KosSkills.ultimo_sello(SKILLS.join(nombre)) || t("skill nueva", "new skill")
      nota = t("# Propuesta: #{nombre}\n\n- agente: #{opts[:agente]}\n- fecha: #{TODAY}\n- motivo: #{opts[:motivo].strip}\n- base: #{base}\n",
               "# Proposal: #{nombre}\n\n- agent: #{opts[:agente]}\n- date: #{TODAY}\n- reason: #{opts[:motivo].strip}\n- base: #{base}\n")
      File.write(dir.join(N[:nota]), nota)
      with_lock do
        escribir = KosSkills.archivos(dir).to_h { |r| ["skills/#{N[:propuestas]}/#{nombre}/#{r}", dir.join(r).binread] }
        puts commit(escribir, [], opts[:agente], t("skills: propuesta de #{nombre} (#{opts[:agente]})", "skills: proposal for #{nombre} (#{opts[:agente]})"))
      end
      puts t("Propuesta entregada. Falta que la apruebe alguien de skills/config.yaml.", "Proposal submitted. Someone listed in skills/config.yaml has to approve it.")

    when "diff"
      nombre!(nombre)
      a = SKILLS.join(nombre)
      b = PROPUESTAS.join(nombre)
      raise KosError, t("No hay propuesta para #{nombre}", "No proposal for #{nombre}") unless b.directory?
      puts t("Skill nueva.", "New skill.") unless a.directory?
      lados = EN ? %w[approved proposal] : %w[aprobada propuesta]
      Dir.mktmpdir("kos-skills-diff-") do |tmp| # solo lo que forma la skill: sin historial, resultados ni nota
        lados.zip([a, b]).each do |lado, dir|
          FileUtils.mkdir_p(File.join(tmp, lado))
          next unless dir.directory?
          (KosSkills.archivos(dir) - KosSkills.sin_sello - [N[:nota]]).each do |r|
            FileUtils.mkdir_p(File.join(tmp, lado, File.dirname(r)))
            FileUtils.cp(dir.join(r), File.join(tmp, lado, r))
          end
        end
        out, = Open3.capture2("git", "diff", "--no-index", "--stat", "--patch", "--", *lados, chdir: tmp)
        puts out.empty? ? t("Sin diferencias.", "No differences.") : out
      end

    when "aprobar", "rechazar"
      nombre!(nombre)
      raise KosError.new(t("Falta --por", "Missing --by"), 2) if opts[:por].to_s.empty?
      aprobadores = KosSkills.config(ROOT)["aprobadores"]
      unless aprobadores.include?(opts[:por])
        raise KosError, t("#{opts[:por]} no está en aprobadores (skills/config.yaml: #{aprobadores.join(", ")})",
                          "#{opts[:por]} is not an approver (skills/config.yaml: #{aprobadores.join(", ")})")
      end
      prop = PROPUESTAS.join(nombre)
      raise KosError, t("No hay propuesta para #{nombre}", "No proposal for #{nombre}") unless prop.directory?
      nota = prop.join(N[:nota]).file? ? prop.join(N[:nota]).read : ""
      agente = nota[/^- (?:agente|agent): (.+)$/, 1] || t("sin dato", "unknown")
      motivo = nota[/^- (?:motivo|reason): (.+)$/, 1] || t("sin dato", "unknown")
      skill = SKILLS.join(nombre)
      viejos = skill.directory? ? KosSkills.archivos(skill) : []
      cambios_prev = if skill.join(N[:cambios]).file?
                       skill.join(N[:cambios]).read
                     else
                       t("# Cambios de #{nombre}\n\nCada aprobación deja un sello. Lo genera tools/kos_skills.rb; no se edita a mano.\n",
                         "# Changes to #{nombre}\n\nEach approval leaves a seal. Written by tools/kos_skills.rb; never edit by hand.\n")
                     end
      borrar = KosSkills.archivos(prop).map { |r| "skills/#{N[:propuestas]}/#{nombre}/#{r}" }

      if op == "rechazar"
        raise KosError.new(t("Falta --motivo", "Missing --reason"), 2) if opts[:motivo].to_s.strip.empty?
        escribir = {}
        if skill.directory?
          entrada = t("\n## #{TODAY} — propuesta rechazada\n- propuso: #{agente}\n- motivo de la propuesta: #{motivo}\n- rechazó: #{opts[:por]} (#{opts[:motivo].strip})\n",
                      "\n## #{TODAY} — proposal rejected\n- proposed by: #{agente}\n- reason for the proposal: #{motivo}\n- rejected by: #{opts[:por]} (#{opts[:motivo].strip})\n")
          escribir["skills/#{nombre}/#{N[:cambios]}"] = cambios_prev + entrada
        end
        with_lock { puts commit(escribir, borrar, opts[:por], t("skills: propuesta de #{nombre} rechazada (#{opts[:por]})", "skills: proposal for #{nombre} rejected (#{opts[:por]})")) }
        FileUtils.rm_rf(prop)
        puts t("Propuesta rechazada y borrada.", "Proposal rejected and deleted.")
      else
        chequear!(prop, nombre)
        data, = KosSkills.frontmatter(prop.join("SKILL.md"))
        version = data.dig("metadata", "version").to_s
        Dir.mktmpdir("kos-skills-nueva-") do |tmp|
          nueva = Pathname.new(tmp)
          KosSkills.archivos(prop).each do |r|
            next if r == N[:nota]
            FileUtils.mkdir_p(nueva.join(r).dirname)
            FileUtils.cp(prop.join(r), nueva.join(r))
          end
          resultados = skill.join(N[:resultados])
          if resultados.file?
            FileUtils.mkdir_p(nueva.join("evals"))
            FileUtils.cp(resultados, nueva.join(N[:resultados]))
          end
          s = KosSkills.sello(nueva)
          entrada = t("\n## #{TODAY} — versión #{version}\n- propuso: #{agente}\n- motivo: #{motivo}\n- aprobó: #{opts[:por]}\n- sello: `#{s}`\n",
                      "\n## #{TODAY} — version #{version}\n- proposed by: #{agente}\n- reason: #{motivo}\n- approved by: #{opts[:por]}\n- seal: `#{s}`\n")
          File.write(nueva.join(N[:cambios]), cambios_prev + entrada)
          nuevos = KosSkills.archivos(nueva)
          escribir = nuevos.to_h { |r| ["skills/#{nombre}/#{r}", nueva.join(r).binread] }
          quitar = (viejos - nuevos).map { |r| "skills/#{nombre}/#{r}" } + borrar
          with_lock { puts commit(escribir, quitar, opts[:por], t("skills: #{nombre} #{version} aprobada (#{opts[:por]})", "skills: #{nombre} #{version} approved (#{opts[:por]})")) }
        end
        FileUtils.rm_rf(prop)
        FileUtils.chmod_R("g+w", skill) rescue nil
        # Enlaza la skill nueva donde ya hay skills enlazadas: en este KOS (.claude/skills) y en la carpeta del usuario.
        ([ROOT.join(".claude/skills")] + DESTINOS.values.map { |d| Pathname.new(File.expand_path(d)) }).each do |dir|
          link = dir.join(nombre)
          KosSkills.enlazar(skill, link, ROOT) if dir.directory? && !link.exist? && !link.symlink?
        end
        puts t("#{nombre} #{version} aprobada. Claude Code (y Codex si está) ya la ven; los demás agentes la leen de skills/.",
               "#{nombre} #{version} approved. Claude Code (and Codex if present) already see it; other agents read it from skills/.")
      end
      borrar_vacias(PROPUESTAS)
      Dir.rmdir(PROPUESTAS) if PROPUESTAS.directory? && Dir.empty?(PROPUESTAS)

    when "enlazar"
      raise KosError.new(t("Di a qué agente: ", "Say which agent: ") + DESTINOS.keys.join(t(" o ", " or ")), 2) unless DESTINOS.key?(nombre)
      destino = Pathname.new(File.expand_path(opts[:destino] || DESTINOS[nombre]))
      FileUtils.mkdir_p(destino)
      (SKILLS.directory? ? SKILLS.children : []).select(&:directory?).reject { |d| d.basename.to_s.start_with?("_", ".") }.sort.each do |dir|
        link = destino.join(dir.basename)
        if link.symlink? && File.realpath(link) == File.realpath(dir)
          puts t("ya enlazada: ", "already linked: ") + link.to_s
        elsif link.exist? || link.symlink?
          puts t("OCUPADO, no la toco: #{link} (muévela a un respaldo y vuelve a correr)", "TAKEN, left alone: #{link} (move it to a backup and run again)")
        else
          KosSkills.enlazar(dir, link, ROOT)
          puts t("enlazada: ", "linked: ") + "#{link} -> #{File.readlink(link)}"
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
