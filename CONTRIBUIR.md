# Cómo agregar fotos, audios o videos a la maleta

La maleta reconoce sola todo lo que haya en la carpeta `medios/`. **No hay que tocar código ni renombrar archivos con números.**

## 1. ¿Dónde va cada cosa?

| Quiero agregar… | Carpeta | Formatos |
|---|---|---|
| Una foto | `medios/imagenes/` | `.jpg` `.png` (también `.webp` y `.gif`, solo para la web) |
| Una voz, entrevista o paisaje sonoro | `medios/audios/` | `.mp3` `.wav` (también `.ogg` y `.m4a`, solo para la web) |
| Un video que aparezca al **inclinar** la maleta | `medios/videos/movimiento/` | `.mp4` |
| Un video que aparezca al **acercarse** | `medios/videos/cercania/` | `.mp4` |
| Un video que aparezca con **sonido o voz** | `medios/videos/voz/` | `.mp4` |

Si hay varios videos en la misma carpeta, la maleta elige uno al azar cada vez que se activa ese sensor.

## 2. Súbelo desde GitHub (sin instalar nada)

1. Entra al repositorio y abre la carpeta que corresponde, por ejemplo `medios/audios`.
2. Haz clic en **Add file → Upload files**.
3. Arrastra tus archivos y escribe un mensaje corto, por ejemplo *"Audio de la sala Mexica"*.
4. Haz clic en **Commit changes**.

En uno o dos minutos:
- una **GitHub Action** actualiza la lista `medios.json`;
- **Render** vuelve a publicar la página con tu contenido.

> **¿No tienes permiso para subir?** Si no eres colaborador del repositorio, GitHub te ofrecerá hacer un *fork* y abrir un **Pull Request**. El equipo lo revisa y lo acepta. También puedes pedir que te agreguen como colaborador.

## 3. Pon tu crédito (recomendado)

Abre `medios/creditos.csv`, haz clic en el lápiz ✏️ y agrega una línea por archivo:

```
archivo,credito
audios/sala-mexica.mp3,Entrevista en la sala Mexica · Nombre Apellido
imagenes/piedra-del-sol.jpg,Nombre Apellido · Título del ensayo
videos/voz/recorrido.mp4,Recorrido sonoro · Nombre Apellido
```

- La primera columna es la ruta dentro de `medios/`. También basta con el nombre del archivo.
- Si el crédito lleva comas, escríbelo entre comillas: `"Ana, Luis y Pedro · Título"`.
- Si no pones crédito, la maleta muestra el nombre del archivo. Por eso conviene usar nombres claros, como `ana-lopez-sala-maya.jpg`.

## 4. Antes de subir

- **Tamaño:** por el navegador de GitHub solo se pueden subir archivos de **hasta 25 MB**.
  - Fotos: con 1200 px de lado basta.
  - Audios: MP3 a 128 kbps.
  - Videos: MP4 (H.264) a 720p o menos, sin audio si la voz ya está en `audios/`.
- **Rostros:** no subas videos o fotos donde se reconozca a una persona sin su permiso.
- **Formatos:** los archivos con formatos no válidos se ignoran, y la Action lo avisa en la pestaña **Actions**.

## 5. Probar en tu computador (opcional)

```bash
python3 generar_medios.py          # actualiza medios.json y muestra avisos
python3 -m http.server 8000        # abre http://localhost:8000
```

Para la maleta física, Processing lee la misma carpeta `medios/` al iniciar. Solo hay que volver a ejecutar `Proyecto/Proyecto.pde`.
