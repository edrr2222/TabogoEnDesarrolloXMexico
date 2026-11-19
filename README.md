# ¿Qué hay dentro de la maleta?

**Prototipo de maleta multimedia interactiva**
Multimedia Experimental · Fundación Universitaria Compensar
Espacio colaborativo internacional *Museografías Indisciplinadas*

---

## ¿Qué es?

Una maleta que no se abre con llave, sino con el cuerpo, la distancia y la voz.

Dentro de la maleta están los materiales del trabajo de campo que estudiantes de Antropología de la **Universidad Nacional Autónoma de México (UNAM)** realizaron en el **Museo Nacional de Antropología** de Ciudad de México: ensayos fotográficos, paisajes sonoros y videos que miran críticamente cómo el museo construye el relato nacional.

Mientras la maleta está cerrada, todo ese contenido pasa a la vez: las imágenes corren, las voces saltan entre emisoras con estática y un video se reproduce de fondo. Cada gesto del visitante **detiene ese flujo y fija un fragmento**. Con cinco fragmentos fijados, la maleta se desbloquea y muestra **una interpretación de la interacción física y sonora** de esa persona: cuánto se movió, cuánto se acercó, si usó su voz y con qué ritmo.

Los materiales son los mismos para todos, pero cada visitante arma un relato distinto. Por eso la maleta plantea la pregunta que guió el trabajo de campo de la UNAM: **¿quién narra Mesoamérica?**

## Cómo funciona

| Gesto del visitante | Sensor | Pin Arduino | Qué provoca |
|---|---|---|---|
| **I** · Inclinar la maleta | Inclinación (salida digital) | D3 | Fija la imagen y la voz del momento; cambia al video de *movimiento* |
| **P** · Acercar la mano | Infrarrojo de proximidad | D4 | Fija la imagen y la voz del momento; cambia al video de *cercanía* |
| **S** · Hablar | Sonido (salida analógica) | A0 | Fija la imagen y la voz del momento; cambia al video de *voz* |
| **F** · Aplaudir o sonido fuerte | Sonido (salida analógica) | A0 | Igual que S, registrado como sonido intenso |

**Flujo:** Gesto → Sensor → Arduino (lee y envía los datos por USB) → Processing (convierte las lecturas en gestos y fija el contenido) → Patrón (5 fragmentos y su ritmo) → Interpretación.

- Si pasan más de 5 segundos sin gestos, lo fijado se libera y hay que empezar de nuevo.
- Con cada gesto aumenta la estática, como al girar el dial de un radio. Al desbloquearse, la estática se disuelve y queda la última voz atrapada.
- La interpretación combina el tipo de gesto dominante, el ritmo (rápido o pausado), la intensidad del sonido, el tiempo total y la cantidad de miradas y voces distintas que se fijaron.

## Circuito

Arduino Uno conectado por USB al computador, a 115200 baudios. Todos los sensores se alimentan con 5 V y comparten GND.

| Sensor | Pines del módulo | Conexión |
|---|---|---|
| Sonido | VCC · GND · AO · DO | 5V · GND · **A0** · (DO opcional en D2) |
| Inclinación | G · VCC · S · L | **G → GND** · VCC → 5V · **S → D3** · L sin conectar |
| Infrarrojo | VCC · GND · OUT | 5V · GND · **OUT → D4** |

El Arduino envía una línea cada ~45 ms con el formato `sonido,inclinacion,proximidad`.

## Estructura del repositorio

```
index.html        Simulación web del prototipo (este sitio)
img/              30 fotografías de los ensayos (1.jpg … 30.jpg) + creditos.txt
aud/              7 audios (1.mp3 … 7.mp3) + creditos.txt
video/            3 videos (1.mp4 … 3.mp4) + creditos.txt
```

La versión para la maleta física (Processing + Arduino) está en `La_maleta_Proyecto.zip`:

```
Proyecto/Proyecto.pde                    Programa principal en Processing 4
Proyecto/img, aud, video                 Los mismos medios (imágenes en PNG)
arduino_sensores/arduino_sensores.ino    Código del Arduino Uno
```

## Cómo usar la simulación web

Abre el sitio y haz un clic en la página para activar el sonido.

| Tecla | Acción |
|---|---|
| I · P · S · F | Simular inclinar, acercar, sonido y sonido fuerte |
| D | Demo automática con dos visitantes |
| R | Reiniciar |
| A | Mostrar u ocultar el panel del Arduino |
| H | Ocultar los controles (para grabar) |
| F11 | Pantalla completa |

**Probarla en local:** dentro de la carpeta ejecuta `python -m http.server 8000` y abre `http://localhost:8000`. Si abres el `index.html` con doble clic, el navegador bloquea la carga de los créditos y se muestran imágenes de ejemplo.

**Publicarla en Render:** New → Static Site → conecta este repositorio. Deja vacío el *Build Command* y usa `.` como *Publish Directory*.

## Cómo ejecutar la maleta física

1. Instala **Processing 4** y, desde *Sketch → Import Library → Manage Libraries*, las librerías **Video** y **Sound**.
2. Sube `arduino_sensores.ino` al Arduino Uno desde Arduino IDE y cierra el Monitor Serie.
3. Abre `Proyecto/Proyecto.pde` y cambia `PUERTO_ARDUINO` por el puerto de tu placa.
4. Ejecuta con **Run**. Sin Arduino conectado funciona en modo teclado (`i`, `p`, `s`, `f`). La tecla `d` muestra el panel de calibración.

**Calibración:** si el ruido del lugar dispara gestos solos, sube `UMBRAL_BAJO`. Si la proximidad funciona al revés, cambia `IR_ACTIVO_EN_LOW` a `false`.

## Créditos

**Materiales del trabajo de campo** — Estudiantes de la asignatura *Etnografía de Mesoamérica y el Norte de México*, UNAM, con el profesor Hugo Chávez Carvajal:

- Aline Denni Zarco Ruiz — *La construcción del relato nacional en el MNA* (ensayo fotográfico)
- Amelia Erhard Cabrera Carlin — *Miradas críticas al relato nacional* (ensayo fotográfico)
- Erick Alexis Rodríguez Escobar — *Ecosistema glamouroso mesoaméricamente* (ensayo fotográfico)
- Fernanda Sofía Domínguez Cortázar — *Así en la tierra como en el cielo…* (ensayo fotográfico)
- Santiago Jiménez Hernández — Ensayo fotográfico sobre los hogares indígenas en el MNA
- *La construcción nacionalista de México a través del patrimonio arqueológico y etnográfico* (ensayo fotográfico)
- Fernanda Elide Gómez Bolaños — *Ambiente sonoro: Museo Nacional de Antropología*
- Ixe Ibarra — *¿Quién cabe en Mesoamérica?* (video)
- Fragmentos sonoros de la conversación sobre el relato nacional, de estudiantes de la UNAM

Los videos *Mirada cercana* y *Voces del museo* son montajes hechos para la maleta a partir de estas fotografías y de este paisaje sonoro.

**Diseño y desarrollo del prototipo** — Estudiantes de Multimedia Experimental, Fundación Universitaria Compensar, campus Avenida 68.
<!-- Agrega aquí los nombres del equipo -->

**Marco colaborativo** — *Museografías Indisciplinadas*, con la UNAM (Ciudad de México), la Universidad de Guadalajara, la Universidad Nacional de Colombia (Bogotá) y el artista intermedial Esteban Rey Torres, cuya propuesta de dispositivo intermedial basado en una maleta dio origen a este prototipo.

---

*Proyecto académico sin fines comerciales. Los materiales del trabajo de campo pertenecen a sus autores y se usan con fines educativos dentro del espacio colaborativo.*
