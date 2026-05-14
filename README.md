# PES6 server con Sixserver y STUN

Notas para levantar un servidor de PES6 usando `fiveserver/sixserver`.

Hay dos formas razonables de jugar:

- Con VPN tipo Hamachi/Radmin/ZeroTier. Es lo mas simple si no queres tocar NAT o si tu proveedor usa CG-NAT.
- Publico por Internet, con port forwarding, STUN propio y hairpin NAT si tambien jugas desde la misma LAN del servidor.

Este repo no incluye credenciales, IPs reales ni dominios reales. Los ejemplos usan placeholders como `<PUBLIC_IP>`, `<SERVER_LAN_IP>` y `<PORTAL_DOMAIN>`.

## Componentes

- `sixserver`: maneja login, lobbies, salas, chat y estado de partido.
- `MariaDB`: guarda usuarios, perfiles y estadisticas.
- `STUN`: PES6 lo usa para detectar la IP/puerto UDP visible desde Internet. Sin esto suelen aparecer errores como `No pudo transmitir usando el puerto UDP 5739`.
- Opcional: Traefik o cualquier reverse proxy para publicar la pagina de registro y el API de stats.

## Puertos

PES6 / Sixserver:

```text
TCP 8190          registro / portal
TCP 8191          admin
TCP 8192          API publico de stats, si lo expones
TCP 10881         game list
TCP 20200-20203   servicios de red/login/menu
```

STUN y juego:

```text
UDP 3478          STUN principal
UDP 3479          STUN alternativo
UDP 5739          puerto UDP del cliente PES6
```

En `settings.exe` de PES6 conviene cerrar el juego, ir a `Online Mode`, desmarcar `Auto` y poner `5739`.

## Opcion A: jugar por VPN

Esta opcion evita casi todos los problemas de NAT.

1. Todos instalan la misma VPN: Hamachi, Radmin VPN, ZeroTier, etc.
2. Todos se unen a la misma red.
3. En el servidor, `sixserver.yaml` debe anunciar la IP VPN del host:

```yaml
ServerIP: <SERVER_VPN_IP>
```

4. En el `hosts` de cada jugador:

```text
<SERVER_VPN_IP> pes6gate-ec.winning-eleven.net
<SERVER_VPN_IP> we9stun.winning-eleven.net
```

5. Levantas `sixserver` y MariaDB. Si la VPN enruta UDP bien, normalmente no necesitas abrir puertos en el router.

Si aun usando VPN aparece el error de UDP, revisa firewall local de Windows/Linux y que la VPN permita UDP entre clientes.

## Opcion B: servidor publico con STUN propio

Esta es la configuracion para que entren amigos desde sus casas y tambien puedas jugar desde la misma LAN del server.

### DNS / hosts de los clientes

En Windows, abrir como Administrador:

```text
C:\Windows\System32\drivers\etc\hosts
```

Agregar:

```text
<PUBLIC_IP> pes6gate-ec.winning-eleven.net
<PUBLIC_IP> we9stun.winning-eleven.net
```

Si usas DNS propio en vez de `hosts`, ambos nombres tienen que resolver a la IP publica.

### sixserver.yaml

En modo publico, `sixserver` debe anunciar la IP publica:

```yaml
ServerIP: <PUBLIC_IP>
```

Ejemplo completo en [examples/sixserver.yaml](examples/sixserver.yaml).

### STUN

Con PES6 nos funciono mejor un STUN clasico compatible con el comportamiento viejo del juego.

La idea es:

- correr STUN en `network_mode: host`;
- escuchar en la IP LAN del servidor;
- tener una segunda IP local para el alternate address;
- anunciar siempre la IP publica en `SourceAddress` y `ChangedAddress`.

Ejemplo:

```text
STUN_PUBLIC_IP=<PUBLIC_IP>
stund -v -h <SERVER_LAN_IP> -a <SERVER_LAN_ALT_IP>
```

El punto importante no es el nombre exacto de la variable, sino el resultado: cuando un cliente consulta STUN, las respuestas no deben publicar `192.168.x.x`, `10.x.x.x` ni otra IP privada. Si la implementacion de STUN que uses no permite forzar la IP anunciada, hay que parchearla o usar otra.

En Linux podes agregar una IP secundaria persistente en la misma interfaz. Ejemplo conceptual:

```yaml
network:
  ethernets:
    eth0:
      addresses:
        - <SERVER_LAN_IP>/24
        - <SERVER_LAN_ALT_IP>/24
```

El nombre de la interfaz y el archivo de netplan cambian segun la distro.

### Docker Compose

Hay dos ejemplos:

- [examples/docker-compose.public.yml](examples/docker-compose.public.yml): modo publico con STUN y portal.
- [examples/docker-compose.vpn.yml](examples/docker-compose.vpn.yml): modo VPN, mas simple.

Antes de usar los ejemplos, reemplaza:

```text
<PUBLIC_IP>
<SERVER_LAN_IP>
<SERVER_LAN_ALT_IP>
<PORTAL_DOMAIN>
<DB_PASSWORD>
<DB_ROOT_PASSWORD>
```

Levantar:

```bash
docker compose -f examples/docker-compose.public.yml up -d --build
```

Los ejemplos asumen que ya tenes el codigo de `fiveserver` en el directorio de trabajo, con su `docker/Dockerfile`, `sql/schema6.sql`, `etc`, `tac`, `lib`, `web6`, etc. Una forma practica es partir del repo original y adaptar encima:

```bash
git clone https://github.com/juce/fiveserver.git
cd fiveserver
```

## Router / NAT

Para modo publico necesitas redirigir al host del servidor:

```text
TCP 8190,8191,10881,20200-20203 -> <SERVER_LAN_IP>
UDP 3478,3479                   -> <SERVER_LAN_IP>
```

Si vos jugas desde la misma LAN del server, tambien necesitas hairpin NAT. En MikroTik hay un ejemplo en [examples/mikrotik-pes6.rsc](examples/mikrotik-pes6.rsc).

Si el jugador local usa el puerto `5739`, normalmente tambien se redirige:

```text
UDP 5739 -> <GAME_PC_LAN_IP>
```

No todos los routers domesticos manejan bien hairpin NAT. Si desde afuera funciona y desde tu casa no, ese es el primer lugar para mirar.

## Registro y login

La pagina de registro de Sixserver pide:

- Serial: puede ser compartido, pero conviene mantener uno consistente.
- Username: unico.
- Password: el que elija el jugador.

En PES6, en el campo `Password`, se escribe:

```text
usuario-password
```

Ejemplo:

```text
pepe-1234
```

## API de conectados y stats

Sixserver sirve stats publicas en el puerto `8192`:

```text
/stats
/users/online
/profiles
```

Si publicas un portal con Traefik y queres que la web consulte `/public/...`, podes rutear:

```text
https://<PORTAL_DOMAIN>/public/stats        -> http://sixserver:8192/stats
https://<PORTAL_DOMAIN>/public/users/online -> http://sixserver:8192/users/online
https://<PORTAL_DOMAIN>/public/profiles     -> http://sixserver:8192/profiles
```

Una forma simple es usar un servicio separado en Docker para el API y un middleware `StripPrefix('/public')`.

## Comandos utiles

Ver servicios:

```bash
docker compose ps
```

Logs de sixserver:

```bash
docker compose logs -f sixserver
```

Probar el API local:

```bash
curl http://127.0.0.1:8192/users/online
curl http://127.0.0.1:8192/stats
```

Consultar usuarios:

```bash
docker compose exec -T db mariadb -u sixserver -p<DB_PASSWORD> sixserver \
  -e "SELECT id, username, serial, deleted, updated_on FROM users ORDER BY id;"
```

Consultar partidos:

```bash
docker compose exec -T db mariadb -u sixserver -p<DB_PASSWORD> sixserver \
  -e "SELECT * FROM matches ORDER BY id DESC LIMIT 10; SELECT * FROM matches_played ORDER BY id DESC LIMIT 20;"
```

## Problemas comunes

### No pudo transmitir usando el puerto UDP 5739

El cliente llego al STUN, pero la IP/puerto que recibe no le sirve.

Revisar:

- `we9stun.winning-eleven.net` resuelve a donde corresponde.
- STUN responde por UDP `3478` y `3479`.
- El firewall permite UDP.
- En LAN, hairpin NAT conserva el puerto origen `5739`.
- El STUN anuncia `<PUBLIC_IP>`, no una IP privada.

### Se queda cargando al elegir division

Suelen faltar los TCP del sixserver:

```text
10881
20200-20203
```

Revisar port forwarding, firewall local y que `ServerIP` anuncie la IP correcta.

### La web muestra 0 conectados

Primero probar directo:

```bash
curl http://127.0.0.1:8192/users/online
```

Si ahi aparecen usuarios pero la web muestra cero, el problema es el reverse proxy o la ruta del frontend.

### El partido se juega pero no queda en la base

Puede pasar si alguno sale o corta antes de que el juego envie el resultado final. Para probar stats, terminar el partido y volver al lobby de forma normal antes de cerrar el juego.
