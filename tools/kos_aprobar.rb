#!/usr/bin/env ruby
# encoding: utf-8
Encoding.default_external = Encoding::UTF_8
# kos_aprobar.rb — Aprobación de cambios críticos por email, con código de un solo uso y PIN.
#
#   La IA pide:     ruby tools/kos_aprobar.rb solicitar --descripcion "qué y por qué" (--patch cambio.diff | --comando "...")
#                   El servidor (no la IA) le manda al titular el cambio exacto y un código. La IA recibe solo el número de solicitud.
#   El titular aprueba: ruby tools/kos_aprobar.rb aplicar --id <solicitud>     (en una terminal real; pide código y PIN sin eco)
#   Otras:          estado | probar-correo | cancelar --id <solicitud>
#
# El cambio queda fijado en el momento de pedirlo: se guarda aparte y se aplica ese, no otro. El código vence a los 15 minutos,
# sirve una vez y se anula a los 3 intentos fallidos; 5 fallos en una hora traban todo una hora.
# Mientras las IA corran con acceso a /var/lib/kos (root), esto es una barrera de procedimiento; la separación real es la fase 4.
require_relative "lib/kos_aprobacion"
require_relative "lib/kos_como_servicio"
require "net/smtp"
require "base64"
require "cgi"
require "tmpdir"
K = KosAprobacion

def uso(msg = nil)
  warn msg if msg
  warn "Uso: kos_aprobar.rb solicitar --descripcion T (--patch F | --comando C) | aplicar --id ID | estado | cancelar --id ID"
  exit 2
end

def opcion(nombre) = (i = ARGV.index(nombre)) ? ARGV[i + 1] : nil
def pend_path(id) = K::ESTADO.join("pend-#{id}.json")
def carga_path(id) = K::ESTADO.join("pend-#{id}.carga")

def config
  c = K.leer_json(K::CONFIG, nil) or abort("Falta #{K::CONFIG} (destinatario y correo_env). Ver operations/aprobacion-por-email.md.")
  abort("#{K::CONFIG} necesita destinatario y correo_env") unless c["destinatario"] && c["correo_env"]
  c
end

def enviar(config, asunto, cuerpo, html = nil)
  if ENV["KOS_CORREO"] # pruebas: el mail se escribe en un archivo en vez de enviarse
    File.write(ENV["KOS_CORREO"], "Para: #{config["destinatario"]}\nAsunto: #{asunto}\n\n#{cuerpo}")
    File.write("#{ENV["KOS_CORREO"]}.html", html) if html
    return
  end
  env = File.readlines(config["correo_env"]).map(&:chomp).reject { |l| l.empty? || l.start_with?("#") }.to_h { |l| l.split("=", 2) }
  host, user, pass = env.values_at("SMTP_HOST", "SMTP_USER", "SMTP_PASS")
  abort("El correo no está configurado (#{config["correo_env"]})") unless host && user && pass
  puerto = (env["SMTP_PORT"] || 587).to_i
  limite = "kos-#{SecureRandom.hex(8)}"
  parte = ->(tipo, texto) { "--#{limite}\r\nContent-Type: #{tipo}; charset=UTF-8\r\nContent-Transfer-Encoding: base64\r\n\r\n#{Base64.encode64(texto)}" }
  cabecera = <<~MAIL.gsub("\n", "\r\n")
    From: KOS <#{user}>
    To: #{config["destinatario"]}
    Subject: =?UTF-8?B?#{Base64.strict_encode64(asunto)}?=
    Date: #{Time.now.rfc2822}
    MIME-Version: 1.0
    Content-Type: multipart/alternative; boundary="#{limite}"

  MAIL
  mensaje = cabecera + parte.call("text/plain", cuerpo) + (html ? parte.call("text/html", html) : "") + "--#{limite}--\r\n"
  smtp = Net::SMTP.new(host, puerto)
  env["SMTP_SECURE"] == "true" ? smtp.enable_tls : smtp.enable_starttls_auto
  smtp.start("localhost", user, pass, :plain) { |c| c.send_message(mensaje, user, config["destinatario"]) }
end

# Mail en HTML con estilos en línea (los clientes de correo no leen hojas de estilo): tarjeta, cambio coloreado y código grande.
def html_aprobacion(id:, desc:, huella:, tipo:, rutas:, detalle:, codigo:, vence:)
  e = ->(t) { CGI.escapeHTML(t.to_s) }
  cuerpo =
    if tipo == "patch"
      detalle.lines.map do |l|
        estilo = case l
                 when /\A(\+\+\+|---)/ then "color:#6b7280;"
                 when /\A\+/ then "background:#e6f6ea;color:#14532d;"
                 when /\A-/ then "background:#fdecec;color:#7f1d1d;"
                 when /\A@@/ then "background:#eef2ff;color:#3730a3;"
                 else "color:#374151;"
                 end
        "<div style=\"#{estilo}white-space:pre-wrap;word-break:break-word;padding:0 10px;\">#{e.(l.chomp)}&#8203;</div>"
      end.join
    else
      "<div style=\"color:#111827;white-space:pre-wrap;word-break:break-word;padding:2px 10px;\">#{e.(detalle)}</div>"
    end
  chips = rutas.map { |r| "<span style=\"display:inline-block;background:#eef2f7;color:#1f2937;border-radius:6px;padding:3px 8px;margin:2px 4px 2px 0;font:12px ui-monospace,Menlo,Consolas,monospace;\">#{e.(r)}</span>" }.join
  <<~HTML
    <!doctype html><html lang="es"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"></head>
    <body style="margin:0;padding:0;background:#f3f4f6;">
    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#f3f4f6;"><tr><td align="center" style="padding:24px 12px;">
    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:600px;background:#ffffff;border-radius:14px;border:1px solid #e5e7eb;font:15px/1.5 -apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;color:#111827;">
      <tr><td style="padding:22px 26px 0 26px;">
        <div style="font-size:12px;letter-spacing:.08em;text-transform:uppercase;color:#b45309;font-weight:700;">KOS &middot; aprobaci&oacute;n pendiente</div>
        <div style="font-size:21px;line-height:1.3;font-weight:700;margin-top:6px;">#{e.(desc)}</div>
        <div style="font-size:13px;color:#6b7280;margin-top:4px;">Una IA pidi&oacute; un cambio cr&iacute;tico. Debe leerse completo antes de aprobar.</div>
      </td></tr>
      <tr><td style="padding:16px 26px 0 26px;">
        <div style="font-size:12px;font-weight:700;color:#6b7280;text-transform:uppercase;letter-spacing:.06em;">#{tipo == "patch" ? "Archivos que toca" : "Acci&oacute;n en el servidor"}</div>
        <div style="margin-top:6px;">#{tipo == "patch" ? chips : "<span style=\"color:#6b7280;\">un comando, tal cual aparece abajo</span>"}</div>
      </td></tr>
      <tr><td style="padding:14px 26px 0 26px;">
        <div style="border:1px solid #e5e7eb;border-radius:10px;overflow:hidden;font:12.5px/1.55 ui-monospace,Menlo,Consolas,monospace;background:#fafafa;padding:8px 0;">#{cuerpo}</div>
      </td></tr>
      <tr><td style="padding:22px 26px 0 26px;">
        <div style="background:#111827;border-radius:12px;text-align:center;padding:18px 12px;">
          <div style="color:#9ca3af;font-size:12px;letter-spacing:.08em;text-transform:uppercase;">Tu c&oacute;digo</div>
          <div style="color:#ffffff;font:700 34px/1.2 ui-monospace,Menlo,Consolas,monospace;letter-spacing:.28em;margin-top:6px;">#{e.(codigo)}</div>
          <div style="color:#fbbf24;font-size:13px;margin-top:6px;">Vence a las #{e.(vence)} &middot; sirve una sola vez</div>
        </div>
      </td></tr>
      <tr><td style="padding:20px 26px 0 26px;">
        <div style="font-size:12px;font-weight:700;color:#6b7280;text-transform:uppercase;letter-spacing:.06em;">C&oacute;mo aprobar</div>
        <ol style="margin:8px 0 0 18px;padding:0;color:#374151;">
          <li>Entrar por SSH al servidor (no desde el chat de una IA).</li>
          <li>Correr este comando:</li>
        </ol>
        <div style="margin:8px 0 0 0;background:#0b1220;color:#e5e7eb;border-radius:8px;padding:10px 12px;font:13px ui-monospace,Menlo,Consolas,monospace;word-break:break-all;">ruby #{K::ROOT}/tools/kos_aprobar.rb aplicar --id #{e.(id)}</div>
        <ol start="3" style="margin:8px 0 0 18px;padding:0;color:#374151;"><li>Escribir el c&oacute;digo de arriba y el PIN. No se ven mientras se tipean.</li></ol>
      </td></tr>
      <tr><td style="padding:20px 26px 24px 26px;">
        <div style="border-top:1px solid #e5e7eb;padding-top:12px;font-size:12px;color:#6b7280;">
          Si no reconoc&eacute;s este pedido, ignor&aacute; el mail: vence solo. El PIN nunca se comparte con una IA.<br>
          Solicitud <span style="font-family:ui-monospace,Menlo,monospace;">#{e.(id)}</span> &middot; huella <span style="font-family:ui-monospace,Menlo,monospace;">#{e.(huella[0, 16])}</span>
        </div>
      </td></tr>
    </table></td></tr></table></body></html>
  HTML
end

def rutas_del_patch(patch)
  out, = K.git("apply", "--numstat", input: patch)
  out.lines.map { |l| l.split("\t", 3)[2].to_s.strip }.reject(&:empty?)
end

# Aplica el patch en una copia descartable de HEAD y corre el validador: no se pide aprobar algo que rompe KOS.
def valida_patch(patch)
  _, err, st = K.git("apply", "--check", input: patch)
  return "el patch no aplica sobre HEAD: #{err.lines.first.to_s.strip}" unless st.success?
  Dir.mktmpdir("kos-aprob") do |tmp|
    dir = File.join(tmp, "wt")
    _, e, s = K.git("worktree", "add", "-q", "--detach", dir, "HEAD")
    return "no pude armar la copia de prueba: #{e.strip}" unless s.success?
    begin
      Open3.capture3("git", "-C", dir, "apply", stdin_data: patch, binmode: true)
      v, = Open3.capture2e("ruby", K::ROOT.join("tools/kos_validate.rb").to_s, dir)
      errores = v[/Errores: (\d+)/, 1].to_i
      return "el validador marca #{errores} errores con este cambio: #{v.lines.grep(/\AERROR/).first.to_s.strip[0, 140]}" if errores.positive?
    ensure
      K.git("worktree", "remove", "--force", dir)
    end
  end
  nil
end

def solicitar
  desc = opcion("--descripcion") or uso("Falta --descripcion")
  archivo, comando = opcion("--patch"), opcion("--comando")
  uso("Pasá --patch o --comando, uno solo") unless archivo.nil? ^ comando.nil?
  abort("La zona crítica todavía no está activada: el titular tiene que correr tools/kos_pin.rb primero.") unless K.activa?
  cfg = config
  if archivo
    patch = File.binread(archivo)
    abort("El patch está vacío") if patch.empty?
    abort("El patch pesa más de 100 KB: dividirlo: el titular tiene que poder leerlo completo en el mail.") if patch.bytesize > 100_000
    if (problema = valida_patch(patch))
      abort("No se envió la solicitud: #{problema}")
    end
    tipo, carga, detalle = "patch", patch, "Archivos: #{rutas_del_patch(patch).join(", ")}\n\n#{patch.dup.force_encoding('UTF-8').scrub}"
  else
    tipo, carga, detalle = "comando", comando.b, "Comando que se ejecutaría en el servidor, tal cual:\n\n  #{comando}"
  end
  id = SecureRandom.hex(4)
  codigo = format("%06d", SecureRandom.random_number(1_000_000))
  huella = Digest::SHA256.hexdigest("#{tipo}\0#{carga}")
  K.escribir_privado(pend_path(id), "id" => id, "tipo" => tipo, "huella" => huella, "descripcion" => desc, "creada" => Time.now.utc.iso8601,
                     "vence" => (Time.now + K::VIDA_CODIGO).utc.iso8601, "intentos" => 0, "mac" => K.mac(id, huella, codigo))
  File.binwrite(carga_path(id), carga)
  File.chmod(0o600, carga_path(id).to_s)
  vence = (Time.now + K::VIDA_CODIGO).strftime("%H:%M")
  rutas = tipo == "patch" ? rutas_del_patch(carga) : []
  cuerpo = <<~TXT
    KOS · APROBACIÓN PENDIENTE
    #{"=" * 40}
    #{desc}

    Una IA pidió un cambio CRÍTICO. Debe leerse completo antes de aprobar.
    Solicitud: #{id}   Huella: #{huella[0, 16]}

    #{detalle}

    #{"-" * 40}
    TU CÓDIGO
    Código: #{codigo}
    Vence a las #{vence} y sirve una sola vez.
    #{"-" * 40}

    CÓMO APROBAR
      1. Entrar por SSH al servidor (no desde el chat de una IA).
      2. Correr:  ruby #{K::ROOT}/tools/kos_aprobar.rb aplicar --id #{id}
      3. Escribir el código y el PIN (no se ven mientras se tipean).

    Si no se reconoce este pedido, se ignora el mail: vence solo.
    El PIN nunca se comparte con una IA.
  TXT
  html = html_aprobacion(id: id, desc: desc, huella: huella, tipo: tipo, rutas: rutas, detalle: tipo == "patch" ? carga.dup.force_encoding("UTF-8").scrub : comando, codigo: codigo, vence: vence)
  enviar(cfg, "KOS · Aprobación pendiente: #{desc[0, 70]}", cuerpo, html)
  puts "Solicitud #{id} enviada al titular, que debe aprobarla desde una terminal del servidor; vence en 15 minutos."
end

def aplicar
  id = opcion("--id") or uso("Falta --id")
  p = K.leer_json(pend_path(id)) or abort("No existe la solicitud #{id} (o ya se usó).")
  if (hasta = K.trabado?)
    abort("Aprobaciones trabadas por intentos fallidos hasta las #{hasta.localtime.strftime('%H:%M')}.")
  end
  if Time.now > Time.parse(p["vence"])
    pend_path(id).delete; carga_path(id).delete
    abort("La solicitud #{id} venció. Que la IA la pida de nuevo.")
  end
  secreto = K.leer_json(K.secreto_path) or abort("No hay PIN creado.")
  codigo = K.pedir("Código del mail: ").gsub(/\s/, "")
  pin = K.pedir("PIN: ")
  carga = File.binread(carga_path(id))
  huella_ok = Digest::SHA256.hexdigest("#{p["tipo"]}\0#{carga}") == p["huella"]
  codigo_ok = OpenSSL.fixed_length_secure_compare(K.mac(id, p["huella"], codigo), p["mac"])
  pin_ok = K.coincide?(pin, secreto["pin"])
  unless huella_ok && codigo_ok && pin_ok
    K.anotar_fallo
    p["intentos"] += 1
    if p["intentos"] >= K::INTENTOS_POR_SOLICITUD
      pend_path(id).delete; carga_path(id).delete
      abort("Datos incorrectos. La solicitud #{id} quedó anulada por demasiados intentos.")
    end
    K.escribir_privado(pend_path(id), p)
    abort(huella_ok ? "Código o PIN incorrectos (intento #{p["intentos"]} de #{K::INTENTOS_POR_SOLICITUD})." : "El cambio guardado no coincide con su huella: solicitud anulada.")
  end
  K.limpiar_fallos
  pend_path(id).delete # una vez usado, no sirve más aunque la aplicación falle
  commit = nil
  File.open(K::ROOT.join(".git/kos-write.lock").to_s, File::RDWR | File::CREAT, KosComoServicio.modo_archivo(K::ROOT)) do |lock|
    lock.flock(File::LOCK_EX)
    if p["tipo"] == "patch"
      rutas = rutas_del_patch(carga)
      sucias = rutas.select { |r| !K.git("status", "--porcelain", "--", r)[0].strip.empty? }
      abort("Hay cambios sin commitear en #{sucias.join(", ")}: no aplico encima.") if sucias.any?
      _, err, st = K.git("apply", "--index", input: carga)
      abort("El patch ya no aplica: #{err.strip}") unless st.success?
      msg = "#{p["descripcion"]}\n\nAprobado-por: titular (solicitud #{id})"
      _, err, st = K.git("commit", "-q", "-m", msg, "--", *rutas)
      abort("No pude commitear: #{err.strip}") unless st.success?
      commit = K.git("rev-parse", "HEAD")[0].strip
    else
      out, st = Open3.capture2e("bash", "-c", carga.dup.force_encoding("UTF-8"), chdir: K::ROOT.to_s)
      puts out.lines.last(15).join
      commit = nil
      abort("El comando terminó con error (código #{st.exitstatus}).") unless st.success?
    end
  end
  KosComoServicio.normalizar_dueno(K::ROOT) # lo que escribió root vuelve a ser de `kos`
  File.open(K.log_path.to_s, "a", 0o600) { |f| f.puts JSON.generate("id" => id, "tipo" => p["tipo"], "huella" => p["huella"], "commit" => commit, "descripcion" => p["descripcion"], "fecha" => Time.now.utc.iso8601) }
  carga_path(id).delete
  puts "Aprobado y aplicado (solicitud #{id}#{commit ? ", commit #{commit[0, 7]}" : ""})."
end

def probar_correo
  cfg = config
  enviar(cfg, "KOS · Prueba de correo de aprobaciones", "Este es un mail de prueba de KOS. Si lo ves, las aprobaciones te van a llegar acá.\nNo trae ningún código ni pide nada.\nSi está en spam, marcarlo como \"no es spam\".")
  puts "Mail de prueba enviado a #{cfg["destinatario"]}."
end

def estado
  pendientes = Dir[K::ESTADO.join("pend-*.json").to_s].filter_map { |f| K.leer_json(Pathname.new(f)) }
  puts "Zona crítica: #{K.activa? ? "activa" : "sin activar (falta el PIN)"}"
  pendientes.each { |x| puts "- #{x["id"]} #{x["tipo"]}: #{x["descripcion"][0, 70]} (vence #{Time.parse(x["vence"]).localtime.strftime('%H:%M')})" }
  puts "Sin solicitudes pendientes." if pendientes.empty?
end

def cancelar
  id = opcion("--id") or uso("Falta --id")
  [pend_path(id), carga_path(id)].each { |f| f.delete if f.file? }
  puts "Solicitud #{id} cancelada."
end

case ARGV.first
when "solicitar" then solicitar
when "aplicar" then aplicar
when "probar-correo" then probar_correo
when "estado" then estado
when "cancelar" then cancelar
else uso
end
