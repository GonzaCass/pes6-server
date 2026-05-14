# PES6 server con Sixserver y STUN

Guia para levantar un servidor de PES6 usando `fiveserver/sixserver`.

Hay dos formas practicas de hacerlo:

- VPN tipo Hamachi, Radmin VPN o ZeroTier. Es el camino mas simple.
- Servidor publico por Internet, con port forwarding, STUN propio y hairpin NAT si tambien jugas desde la misma red del servidor.

Los ejemplos usan placeholders como `<PUBLIC_IP>`, `<SERVER_LAN_IP>`, `<PORTAL_DOMAIN>` y `<DB_PASSWORD>`. No subas tu IP real ni passwords al repo.

## Indice

1. [Como elegir el modo](#como-elegir-el-modo)
2. [Puertos](#puertos)
3. [Preparar el codigo base](#preparar-el-codigo-base)
4. [Modo VPN](#modo-vpn)
5. [Modo publico con STUN propio](#modo-publico-con-stun-propio)
6. [Publicar portal y stats](#publicar-portal-y-stats)
7. [Configurar clientes](#configurar-clientes)
8. [Comandos de administracion](#comandos-de-administracion)
9. [Problemas comunes](#problemas-comunes)
10. [Creditos](#creditos)

## Como elegir el modo

Usa VPN si:

- no queres tocar el router;
- tu ISP te da CG-NAT;
- solo vas a jugar con amigos conocidos;
- queres algo facil de mantener.

Usa modo publico si:

- tenes IP publica o DDNS;
- podes configurar port forwarding;
- queres que entren jugadores desde cualquier red;
- queres portal de registro publico.

## Puertos

Sixserver usa TCP:

```text
8190          registro / portal
8191          admin
8192          API de stats, si lo expones
10881         game list
20200-20203   servicios de red, login y menu
```

STUN y juego usan UDP:

```text
3478          STUN principal
3479          STUN alternativo
5739          puerto UDP del cliente PES6
```

En `settings.exe` de PES6 conviene cerrar el juego, entrar a `Online Mode`, desmarcar `Auto` y usar el puerto UDP `5739`.

## Preparar el codigo base

Los ejemplos de este repo son templates. El servidor real sale del repo de Juce:

```bash
mkdir -p ~/pes6-server
cd ~/pes6-server
git clone https://github.com/juce/fiveserver.git
cd fiveserver
```

Instala Docker y Docker Compose si no los tenes:

```bash
docker --version
docker compose version
```

Copia los ejemplos que vayas a usar dentro del repo `fiveserver`:

```bash
# desde este repo de guia
cp examples/sixserver.yaml ~/pes6-server/fiveserver/etc/conf/sixserver.yaml
cp examples/docker-compose.public.yml ~/pes6-server/fiveserver/docker-compose.yml
cp -r examples/stund ~/pes6-server/fiveserver/examples/
```

Edita los placeholders:

```bash
cd ~/pes6-server/fiveserver
grep -R "<.*>" -n docker-compose.yml etc/conf/sixserver.yaml examples/stund || true
```

Reemplaza como minimo:

```text
<PUBLIC_IP>
<SERVER_LAN_IP>
<SERVER_LAN_ALT_IP>
<PORTAL_DOMAIN>
<DB_PASSWORD>
<DB_ROOT_PASSWORD>
```

## Modo VPN

Este modo evita casi todo el trabajo de NAT.

1. Todos instalan la misma VPN: Hamachi, Radmin VPN, ZeroTier, etc.
2. Todos se unen a la misma red.
3. Busca la IP VPN del host que corre el servidor. Ejemplo: `<SERVER_VPN_IP>`.
4. Configura `sixserver.yaml`:

```yaml
ServerIP: <SERVER_VPN_IP>
```

5. Usa el compose simple:

```bash
cp examples/docker-compose.vpn.yml docker-compose.yml
docker compose up -d --build
docker compose ps
```

6. En cada cliente, agrega al archivo `hosts`:

```text
<SERVER_VPN_IP> pes6gate-ec.winning-eleven.net
<SERVER_VPN_IP> we9stun.winning-eleven.net
```

7. Proba desde el navegador:

```text
http://<SERVER_VPN_IP>:8190/
```

Si la VPN enruta bien UDP entre pares, no deberias necesitar reglas en el router.

## Modo publico con STUN propio

Este modo sirve para que entren amigos desde Internet y tambien para jugar desde la LAN del server.

### 1. Configurar sixserver

En `etc/conf/sixserver.yaml`:

```yaml
ServerIP: <PUBLIC_IP>
```

El archivo de ejemplo esta en [examples/sixserver.yaml](examples/sixserver.yaml).

### 2. Preparar IP secundaria para STUN

El STUN clasico necesita una direccion alternativa. En Linux podes agregar una segunda IP local en la misma interfaz.

Ejemplo conceptual con netplan:

```yaml
network:
  ethernets:
    eth0:
      addresses:
        - <SERVER_LAN_IP>/24
        - <SERVER_LAN_ALT_IP>/24
```

Aplica el cambio segun tu distro. Despues verifica:

```bash
ip addr show
```

### 3. Construir STUN

El Dockerfile de ejemplo esta en [examples/stund/Dockerfile](examples/stund/Dockerfile).

Ese Dockerfile descarga `stund_0.96_Aug13.tgz` desde SourceForge, lo compila y aplica un patch para que el servidor anuncie la IP publica con `STUN_PUBLIC_IP`.

La fuente original historica figura como Vovida STUN 0.96. FreeBSD mantiene el port `net/stund` y lista el distfile `stund_0.96_Aug13.tgz` con mirrors de SourceForge.

Comandos:

```bash
mkdir -p examples
cp -r /ruta/a/este/repo/examples/stund ./examples/stund
docker build \
  --build-arg STUND_URL="https://downloads.sourceforge.net/project/stun/stun/0.96/stund_0.96_Aug13.tgz" \
  -t pes6-stund:0.96 \
  ./examples/stund
```

Proba que la imagen exista:

```bash
docker image ls pes6-stund
```

### 4. Levantar todo

Usa el compose publico:

```bash
cp examples/docker-compose.public.yml docker-compose.yml
```

Edita `docker-compose.yml` y reemplaza placeholders. Despues:

```bash
docker compose up -d --build
docker compose ps
```

Logs:

```bash
docker compose logs -f sixserver
docker compose logs -f stun
```

### 5. Abrir firewall local

Ejemplo con UFW:

```bash
cp examples/ufw-public.sh /tmp/ufw-pes6.sh
sed -i 's/<TRAEFIK_DOCKER_SUBNET>/172.19.0.0\/16/g' /tmp/ufw-pes6.sh
sudo sh /tmp/ufw-pes6.sh
sudo ufw status numbered
```

Si no usas Traefik o no expones stats, podes borrar la regla de `8192`.

### 6. Configurar router

Redirige al host del servidor:

```text
TCP 8190,8191,10881,20200-20203 -> <SERVER_LAN_IP>
UDP 3478,3479                   -> <SERVER_LAN_IP>
```

Si jugas desde la misma LAN:

```text
UDP 5739 -> <GAME_PC_LAN_IP>
```

Para MikroTik hay una plantilla en [examples/mikrotik-pes6.rsc](examples/mikrotik-pes6.rsc). Edita las variables antes de aplicarla:

```routeros
:global PublicIP "<PUBLIC_IP>"
:global ServerLanIP "<SERVER_LAN_IP>"
:global GamePcLanIP "<GAME_PC_LAN_IP>"
:global LanSubnet "<LAN_SUBNET_CIDR>"
```

Despues pegala en `New Terminal` de WinBox o RouterOS.

## Publicar portal y stats

El portal de registro vive en:

```text
http://<SERVER_LAN_IP>:8190/
```

El admin vive en:

```text
http://<SERVER_LAN_IP>:8191/
```

El API de stats vive en:

```text
http://<SERVER_LAN_IP>:8192/stats
http://<SERVER_LAN_IP>:8192/users/online
http://<SERVER_LAN_IP>:8192/profiles
```

Si usas Traefik y queres que el portal consulte `/public/...`, el compose publico trae dos servicios:

- `portal`: proxya `8190`.
- `public-api`: proxya `8192` y usa `StripPrefix('/public')`.

Queda asi:

```text
https://<PORTAL_DOMAIN>/public/stats        -> http://host:8192/stats
https://<PORTAL_DOMAIN>/public/users/online -> http://host:8192/users/online
https://<PORTAL_DOMAIN>/public/profiles     -> http://host:8192/profiles
```

## Configurar clientes

En Windows, abrir Notepad como Administrador y editar:

```text
C:\Windows\System32\drivers\etc\hosts
```

Modo publico:

```text
<PUBLIC_IP> pes6gate-ec.winning-eleven.net
<PUBLIC_IP> we9stun.winning-eleven.net
```

Modo VPN:

```text
<SERVER_VPN_IP> pes6gate-ec.winning-eleven.net
<SERVER_VPN_IP> we9stun.winning-eleven.net
```

Limpia cache DNS:

```powershell
ipconfig /flushdns
ping pes6gate-ec.winning-eleven.net
ping we9stun.winning-eleven.net
```

### Si usas Kitserver

Algunos parches o instalaciones con Kitserver pueden ignorar el archivo `hosts` o tener su propia configuracion de red.

En la carpeta `kitserver` donde esta instalado el juego, modifica o crea este archivo:

```text
roster.cfg
```

Contenido para modo publico:

```ini
# Roster configuration file

server = <PUBLIC_IP>
stun-server = <PUBLIC_IP>
debug = 1
```

Contenido para modo VPN:

```ini
# Roster configuration file

server = <SERVER_VPN_IP>
stun-server = <SERVER_VPN_IP>
debug = 1
```

Despues reinicia el juego. Si estas probando cambios de red, tambien conviene cerrar `pes6.exe` antes de tocar `settings.exe` o `roster.cfg`.

En PES6:

1. Abrir `settings.exe`.
2. Ir a `Online Mode`.
3. Desmarcar `Auto`.
4. Puerto UDP: `5739`.
5. Abrir el juego y entrar a red.

Registro:

- Crear usuario desde `http://<SERVER_IP>:8190/` o desde tu dominio.
- El serial puede repetirse; el username no.
- En el campo `Password` del juego se ingresa `usuario-password`.

Ejemplo:

```text
pepe-1234
```

## Comandos de administracion

Estado:

```bash
docker compose ps
```

Logs:

```bash
docker compose logs -f sixserver
docker compose logs -f stun
docker compose logs -f db
```

Reiniciar:

```bash
docker compose restart sixserver
docker compose restart stun
```

Probar API:

```bash
curl http://127.0.0.1:8192/users/online
curl http://127.0.0.1:8192/stats
```

Ver usuarios:

```bash
docker compose exec -T db mariadb -u sixserver -p<DB_PASSWORD> sixserver \
  -e "SELECT id, username, serial, deleted, updated_on FROM users ORDER BY id;"
```

Ver perfiles:

```bash
docker compose exec -T db mariadb -u sixserver -p<DB_PASSWORD> sixserver \
  -e "SELECT id, user_id, name, rank, points, disconnects FROM profiles ORDER BY id;"
```

Ver partidos guardados:

```bash
docker compose exec -T db mariadb -u sixserver -p<DB_PASSWORD> sixserver \
  -e "SELECT * FROM matches ORDER BY id DESC LIMIT 10; SELECT * FROM matches_played ORDER BY id DESC LIMIT 20;"
```

Eliminar un usuario de prueba:

```bash
docker compose exec -T db mariadb -u sixserver -p<DB_PASSWORD> sixserver \
  -e "DELETE FROM users WHERE LOWER(username) = 'usuario_prueba';"
```

## Problemas comunes

### No pudo transmitir usando el puerto UDP 5739

El cliente llego al STUN, pero la IP o el puerto que recibe no le sirve.

Revisar:

- `we9stun.winning-eleven.net` resuelve a donde corresponde.
- STUN responde por UDP `3478` y `3479`.
- El firewall permite UDP.
- En LAN, hairpin NAT conserva el puerto origen `5739`.
- El STUN anuncia `<PUBLIC_IP>`, no una IP privada.

### Se queda cargando al elegir division

Suelen faltar puertos TCP de sixserver:

```text
10881
20200-20203
```

Revisar port forwarding, firewall local y `ServerIP`.

### La web muestra 0 conectados

Proba directo:

```bash
curl http://127.0.0.1:8192/users/online
```

Si ahi aparecen jugadores pero la web muestra cero, el problema esta en el reverse proxy o en la ruta del frontend.

### El partido se juega pero no queda en la base

Puede pasar si alguien cierra o corta antes de que PES6 mande el resultado final. Para probar stats, terminar el partido y volver al lobby normalmente antes de cerrar.

## Creditos

El servidor base no es parte de este repo. `fiveserver/sixserver` fue creado por Juce y colaboradores:

```text
https://github.com/juce/fiveserver
```

Este repo solamente documenta una forma de desplegarlo con Docker, STUN y reglas de red para jugar PES6 por VPN o por Internet.
