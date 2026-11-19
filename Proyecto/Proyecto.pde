import processing.serial.*;
import processing.video.*;
import processing.sound.*;
import java.util.Arrays;
import java.util.Comparator;

// =====================================================
//  LA MALETA - Multimedia Experimental
//  Museografias Indisciplinadas
//
//  Mientras la maleta esta cerrada TODO se reproduce:
//  un video de fondo, imagenes que pasan por la ranura
//  activa de la cerradura y voces que saltan entre
//  emisoras con estatica (ruido blanco).
//
//  Cada gesto que detectan los sensores FIJA lo que
//  estaba pasando en ese instante (imagen + voz) y
//  cambia el video segun el sensor:
//    I = inclinar la maleta   (sensor de inclinacion, D3)
//    P = acercar la mano      (sensor infrarrojo, D4)
//    S = sonido medio         (sensor de sonido, A0)
//    F = sonido fuerte        (sensor de sonido, A0)
//
//  Con 5 fragmentos fijados la maleta se desbloquea y
//  muestra la INTERPRETACION de la interaccion fisica y
//  sonora del visitante.
//
//  Prueba sin Arduino con el teclado: i, p, s, f
//  r = reiniciar    d = panel de calibracion
// =====================================================

// ---------------- MEDIOS ----------------
// Se leen solos al iniciar desde la carpeta medios/ (la misma que usa la web):
//   medios/imagenes/            .jpg .png .gif
//   medios/audios/              .mp3 .wav
//   medios/videos/movimiento/   videos al INCLINAR
//   medios/videos/cercania/     videos al ACERCAR la mano
//   medios/videos/voz/          videos con SONIDO
//   medios/creditos.csv         (opcional) archivo,credito
// Los archivos pueden tener cualquier nombre: basta con copiarlos ahi.
String MEDIOS;
int TOTAL_IMAGENES = 0;
int TOTAL_AUDIOS = 0;
int TOTAL_VIDEOS = 0;

// ---------------- ARDUINO ----------------
// Cambia COM3 por el puerto de tu placa (en Mac: /dev/cu.usbmodem...)
String PUERTO_ARDUINO = "COM3";
final boolean IR_ACTIVO_EN_LOW = true;

// ---------------- PATRON ----------------
final int LARGO_PATRON = 5;
final int TIEMPO_MAX_ENTRE_GESTOS = 5000;
final int LIMITE_RAPIDO_MS = 900;

// ---------------- SONIDO ----------------
int UMBRAL_BAJO = 35;
int UMBRAL_ALTO = 100;
final int VENTANA_SONIDO_MS = 250;
final int PAUSA_SONIDO_MS = 700;

// ---------------- ANTIRREBOTE ----------------
final int PAUSA_INCLINACION_MS = 400;
final int PAUSA_PROXIMIDAD_MS = 400;

// ---------------- TIEMPOS ----------------
final int DURACION_APERTURA_MS = 1800;
final int DURACION_ABIERTA_MS = 45000;
final int CAMBIO_IMAGEN_MS = 140;      // velocidad del flujo de imagenes

// ---------------- ESTADOS ----------------
final int ESPERA = 0;
final int GRABANDO = 1;
final int ABRIENDO = 2;
final int ABIERTA = 3;
int estado = ESPERA;
int inicioEstado = 0;

// ---------------- MEDIOS CARGADOS ----------------
Serial puerto;
boolean arduinoConectado = false;
PImage[] imagenes;
SoundFile[] audios;
Movie[] videos;
int[] categoriaVideo;
String[] creditosImg, creditosAud, creditosVid;

// ---------------- FLUJO DE CONTENIDO ----------------
int imagenFlujo = 0;
int ultimoCambioImagen = 0;
int estacion = 0;
int proximoCambioEstacion = 0;
int estaticaHasta = 0;
int videoFondo = 0;
int cambioVideoMs = -10000;

// ---------------- LO QUE EL VISITANTE FIJO ----------------
char[] gestos = new char[LARGO_PATRON];
char[] ritmos = new char[LARGO_PATRON];
int[] fijImagen = new int[LARGO_PATRON];
int[] fijEstacion = new int[LARGO_PATRON];
float[] fijPico = new float[LARGO_PATRON];
int totalGestos = 0;
int primerGestoMs = 0;
int ultimoGestoMs = 0;
int ultimoGestoVisual = -10000;

// ---------------- RESULTADO ----------------
int videoElegido = 0;
int categoriaElegida = 0;
int audioElegido = 0;
String codigo = "";
String[] lectura = new String[4];
String[] barraNombre = {"Movimiento", "Cercanía", "Voz", "Ritmo", "Intensidad"};
float[] barraValor = new float[5];
String[] barraTexto = new String[5];

// ---------------- SINTONIZACION ----------------
WhiteNoise ruido;
BandPass dial;
float ruidoAmp = 0;
float ruidoObjetivo = 0;
float volAudio = 0.4;
float volObjetivo = 0.4;

// ---------------- DATOS DE ARDUINO ----------------
volatile int nivelSonido = 0;
volatile int estadoInclinacion = -1;
volatile int estadoProximidad = -1;

int inclinacionReposo = -1;
int ultimaInclinacion = -1;
int ultimoCambioInclinacion = 0;

boolean proximidadInicializada = false;
boolean estabaCerca = false;
int ultimoCambioProximidad = 0;

boolean capturandoSonido = false;
int picoSonido = 0;
int inicioSonido = 0;
int ultimoEventoSonido = 0;

// ---------------- INTERFAZ ----------------
boolean mostrarPanel = false;
String mensaje = "";
int mensajeHasta = 0;

color C_I, C_P, C_S, C_F, C_BRONCE;

// =====================================================

void setup() {
  size(1280, 720);
  // Para la instalacion final cambia size() por: fullScreen();
  frameRate(60);

  C_I = color(240, 180, 70);
  C_P = color(90, 200, 220);
  C_S = color(200, 140, 230);
  C_F = color(240, 90, 90);
  C_BRONCE = color(210, 171, 95);

  MEDIOS = buscarCarpetaMedios();
  File[] fImg = listarArchivos(MEDIOS + "/imagenes", new String[] {".jpg", ".jpeg", ".png", ".gif", ".tga"});
  File[] fAud = listarArchivos(MEDIOS + "/audios", new String[] {".mp3", ".wav", ".aif", ".aiff"});
  String[] carpetasVideo = {"movimiento", "cercania", "voz"};
  ArrayList<File> fVid = new ArrayList<File>();
  IntList cats = new IntList();
  for (int c = 0; c < 3; c++) {
    for (File f : listarArchivos(MEDIOS + "/videos/" + carpetasVideo[c], new String[] {".mp4", ".mov", ".webm"})) {
      fVid.add(f);
      cats.append(c);
    }
  }
  TOTAL_IMAGENES = fImg.length;
  TOTAL_AUDIOS = fAud.length;
  TOTAL_VIDEOS = fVid.size();
  println("Medios en " + MEDIOS + ": " + TOTAL_IMAGENES + " imagenes, " + TOTAL_AUDIOS + " audios, " + TOTAL_VIDEOS + " videos");
  if (TOTAL_IMAGENES < 1 || TOTAL_AUDIOS < 1 || TOTAL_VIDEOS < 1) {
    println("Faltan medios: revisa medios/imagenes, medios/audios y medios/videos/(movimiento|cercania|voz)");
    exit();
    return;
  }

  StringDict creditos = leerCreditos(MEDIOS + "/creditos.csv");
  imagenes = new PImage[TOTAL_IMAGENES];
  audios = new SoundFile[TOTAL_AUDIOS];
  videos = new Movie[TOTAL_VIDEOS];
  categoriaVideo = new int[TOTAL_VIDEOS];
  creditosImg = new String[TOTAL_IMAGENES];
  creditosAud = new String[TOTAL_AUDIOS];
  creditosVid = new String[TOTAL_VIDEOS];

  for (int i = 0; i < TOTAL_IMAGENES; i++) {
    imagenes[i] = loadImage(fImg[i].getAbsolutePath());
    if (imagenes[i] == null) println("Error cargando imagen " + fImg[i].getName());
    creditosImg[i] = creditoDe(creditos, "imagenes/" + fImg[i].getName());
  }
  for (int i = 0; i < TOTAL_AUDIOS; i++) {
    audios[i] = new SoundFile(this, fAud[i].getAbsolutePath());
    creditosAud[i] = creditoDe(creditos, "audios/" + fAud[i].getName());
  }
  for (int i = 0; i < TOTAL_VIDEOS; i++) {
    videos[i] = new Movie(this, fVid.get(i).getAbsolutePath());
    categoriaVideo[i] = cats.get(i);
    creditosVid[i] = creditoDe(creditos, "videos/" + carpetasVideo[cats.get(i)] + "/" + fVid.get(i).getName());
  }

  ruido = new WhiteNoise(this);
  dial = new BandPass(this);
  ruido.play();
  ruido.amp(0.001);
  dial.process(ruido, 1200, 600);

  conectarArduino();

  // El contenido empieza a fluir desde el inicio.
  cambiarVideo(0);
  sintonizar(int(random(TOTAL_AUDIOS)));
  proximoCambioEstacion = millis() + 3200;
  cambiarEstado(ESPERA);
}

void conectarArduino() {
  println("Puertos seriales disponibles:");
  printArray(Serial.list());
  try {
    puerto = new Serial(this, PUERTO_ARDUINO, 115200);
    puerto.bufferUntil('\n');
    arduinoConectado = true;
    println("Arduino conectado en " + PUERTO_ARDUINO);
  } catch (Exception e) {
    arduinoConectado = false;
    println("No se pudo abrir " + PUERTO_ARDUINO + ". Modo teclado: i, p, s, f");
  }
}

// =====================================================

void draw() {
  int sonido = nivelSonido;
  int inclinacion = estadoInclinacion;
  int proximidad = estadoProximidad;

  procesarInclinacion(inclinacion);
  procesarProximidad(proximidad);
  procesarSonido(sonido);

  int ahora = millis();
  int t = ahora - inicioEstado;

  if (estado == GRABANDO && ahora - ultimoGestoMs > TIEMPO_MAX_ENTRE_GESTOS) {
    cerrarMaleta();
    mostrarMensaje("Pasaron 5 segundos sin gestos: lo fijado se libera.");
  }
  if (estado == ABRIENDO && t >= DURACION_APERTURA_MS) cambiarEstado(ABIERTA);
  if (estado == ABIERTA && t >= DURACION_ABIERTA_MS) cerrarMaleta();

  // El contenido fluye mientras la maleta esta cerrada.
  if (estado == ESPERA || estado == GRABANDO) {
    if (ahora - ultimoCambioImagen > CAMBIO_IMAGEN_MS) {
      imagenFlujo = (imagenFlujo + 1 + int(random(5))) % TOTAL_IMAGENES;
      ultimoCambioImagen = ahora;
    }
    if (ahora > proximoCambioEstacion) {
      sintonizar(estacion + 1 + int(random(3)));
      proximoCambioEstacion = ahora + 2600 + int(random(1600));
    }
  }

  // Sonido: estatica y volumen de la voz.
  float objetivoRuido = (ahora < estaticaHasta) ? 0.26 : ruidoObjetivo;
  ruidoAmp = lerp(ruidoAmp, objetivoRuido, 0.12);
  ruido.amp(max(0.001, ruidoAmp));
  volAudio = lerp(volAudio, volObjetivo, 0.03);
  audios[estacion].amp(max(0.001, volAudio));

  float abertura = 0;
  if (estado == ABRIENDO) abertura = constrain(t / (float) DURACION_APERTURA_MS, 0, 1);
  if (estado == ABIERTA) abertura = 1;
  float a = suavizar(abertura);

  background(18, 15, 13);
  dibujarFondo(ahora);

  float cw = 820, ch = 390;
  float cx0 = width / 2 - cw / 2, cy0 = 175;
  float x = lerp(cx0, 20, a), y = lerp(cy0, 16, a);
  float w = lerp(cw, width - 40, a), h = lerp(ch, height - 32, a);
  float dx = 0;
  int desde = ahora - ultimoGestoVisual;
  if (desde < 300 && a == 0) dx = sin(desde * 0.09) * 8 * (1 - desde / 300.0);

  if (estado == ESPERA || estado == GRABANDO) dibujarTextosCerrada(ahora);
  if (a > 0) dibujarInterior(x, y, w, h, a, ahora);
  if (a < 1) dibujarTapa(cx0 + dx, cy0 - a * (ch + 320), cw, ch, 1 - a, ahora);

  if (ahora < mensajeHasta) {
    noStroke();
    fill(10, 8, 7, 220);
    rectMode(CENTER);
    textSize(18);
    rect(width / 2, 140, textWidth(mensaje) + 40, 40, 20);
    rectMode(CORNER);
    fill(255, 220, 140);
    textAlign(CENTER, CENTER);
    text(mensaje, width / 2, 139);
  }

  if (mostrarPanel) dibujarPanel(sonido, inclinacion, proximidad);
}

// =====================================================
//  SENSORES -> GESTOS
// =====================================================

void procesarInclinacion(int valor) {
  if (valor < 0) return;
  if (inclinacionReposo < 0) {
    inclinacionReposo = valor;
    ultimaInclinacion = valor;
    return;
  }
  if (valor != ultimaInclinacion &&
      millis() - ultimoCambioInclinacion >= PAUSA_INCLINACION_MS) {
    ultimaInclinacion = valor;
    ultimoCambioInclinacion = millis();
    if (valor != inclinacionReposo) registrarGesto('I', 0);
  }
}

void procesarProximidad(int valor) {
  if (valor < 0) return;
  boolean cerca = IR_ACTIVO_EN_LOW ? valor == 0 : valor == 1;
  if (!proximidadInicializada) {
    estabaCerca = cerca;
    proximidadInicializada = true;
    return;
  }
  if (cerca != estabaCerca &&
      millis() - ultimoCambioProximidad >= PAUSA_PROXIMIDAD_MS) {
    estabaCerca = cerca;
    ultimoCambioProximidad = millis();
    if (cerca) registrarGesto('P', 0);
  }
}

void procesarSonido(int nivel) {
  // Con la maleta abierta no se escucha: el propio audio la activaria.
  if (estado == ABRIENDO || estado == ABIERTA) {
    capturandoSonido = false;
    return;
  }
  if (!capturandoSonido) {
    if (nivel > UMBRAL_BAJO && millis() - ultimoEventoSonido > PAUSA_SONIDO_MS) {
      capturandoSonido = true;
      picoSonido = nivel;
      inicioSonido = millis();
    }
  } else {
    picoSonido = max(picoSonido, nivel);
    if (millis() - inicioSonido >= VENTANA_SONIDO_MS) {
      capturandoSonido = false;
      ultimoEventoSonido = millis();
      registrarGesto(picoSonido >= UMBRAL_ALTO ? 'F' : 'S', picoSonido);
    }
  }
}

// =====================================================
//  FLUJO DE CONTENIDO
// =====================================================

int categoria(char g) {
  if (g == 'I') return 0;
  if (g == 'P') return 1;
  return 2;
}

// Recibe la categoria (0 movimiento, 1 cercania, 2 voz) y elige
// al azar uno de los videos de esa categoria.
void cambiarVideo(int cat) {
  IntList opciones = new IntList();
  for (int k = 0; k < TOTAL_VIDEOS; k++) if (categoriaVideo[k] == cat % 3) opciones.append(k);
  int i = opciones.size() > 0 ? opciones.get(int(random(opciones.size()))) : cat % TOTAL_VIDEOS;
  for (int k = 0; k < TOTAL_VIDEOS; k++) if (k != i) videos[k].pause();
  videoFondo = i;
  videos[i].loop();
  videos[i].volume(0);
  cambioVideoMs = millis();
}

// Cambiar de emisora: rafaga de estatica y otra voz.
void sintonizar(int k) {
  k = ((k % TOTAL_AUDIOS) + TOTAL_AUDIOS) % TOTAL_AUDIOS;
  if (k != estacion) audios[estacion].stop();
  estacion = k;
  estaticaHasta = millis() + 450;
  dial.freq(random(600, 3000));
  SoundFile s = audios[estacion];
  if (!s.isPlaying()) {
    s.loop();
    s.jump(random(0, max(1, s.duration() - 20)));
  }
}

// =====================================================
//  GESTOS: CADA UNO FIJA LO QUE ESTABA PASANDO
// =====================================================

void registrarGesto(char g, float pico) {
  if (estado != ESPERA && estado != GRABANDO) return;
  int ahora = millis();

  if (estado == ESPERA) {
    totalGestos = 0;
    primerGestoMs = ahora;
    cambiarEstado(GRABANDO);
  }

  int dt = totalGestos > 0 ? ahora - ultimoGestoMs : 0;
  ritmos[totalGestos] = totalGestos == 0 ? '-' : (dt < LIMITE_RAPIDO_MS ? 'r' : 'p');
  gestos[totalGestos] = g;
  fijImagen[totalGestos] = imagenFlujo;
  fijEstacion[totalGestos] = estacion;
  fijPico[totalGestos] = pico;
  totalGestos++;

  ultimoGestoMs = ahora;
  ultimoGestoVisual = ahora;

  cambiarVideo(categoria(g));                 // el sensor cambia el video
  ruidoObjetivo = 0.04 + 0.02 * totalGestos;  // la estatica crece
  dial.bw(max(80, 600 - totalGestos * 100));
  proximoCambioEstacion = ahora + 1400;

  println("Gesto " + totalGestos + ": " + nombreGesto(g) +
          "  fija imagen " + (imagenFlujo + 1) + " y voz " + (estacion + 1));

  if (totalGestos >= LARGO_PATRON) abrirMaleta();
}

void abrirMaleta() {
  // Video: tipo de gesto dominante (empate: el que aparecio primero).
  int[] cuenta = new int[3];
  int[] primera = {99, 99, 99};
  for (int i = 0; i < LARGO_PATRON; i++) {
    int c = categoria(gestos[i]);
    cuenta[c]++;
    if (primera[c] == 99) primera[c] = i;
  }
  int mejor = 0;
  for (int c = 1; c < 3; c++) {
    if (cuenta[c] > cuenta[mejor] || (cuenta[c] == cuenta[mejor] && primera[c] < primera[mejor])) mejor = c;
  }
  videoElegido = mejor;
  categoriaElegida = mejor;
  audioElegido = fijEstacion[LARGO_PATRON - 1];   // la ultima voz atrapada

  int hsh = 7;
  for (int i = 0; i < LARGO_PATRON; i++) {
    hsh = hsh * 31 + gestos[i];
    hsh = hsh * 31 + fijImagen[i];
    hsh = hsh * 31 + fijEstacion[i];
  }
  codigo = hex(hsh, 6);

  interpretar();

  cambiarVideo(videoElegido);
  videoElegido = videoFondo;   // indice real del video mostrado
  if (audioElegido != estacion) sintonizar(audioElegido);
  ruidoObjetivo = 0;     // la estatica se disuelve
  estaticaHasta = 0;
  volObjetivo = 1.0;     // la voz atrapada sube

  println("DESBLOQUEADA  codigo " + codigo);
  cambiarEstado(ABRIENDO);
}

void cerrarMaleta() {
  totalGestos = 0;
  ruidoObjetivo = 0.04;
  volObjetivo = 0.4;
  proximoCambioEstacion = millis() + 1500;
  cambiarEstado(ESPERA);
}

void cambiarEstado(int nuevo) {
  estado = nuevo;
  inicioEstado = millis();
}

// Lectura de la interaccion fisica y sonora del visitante.
void interpretar() {
  int nI = 0, nP = 0, nS = 0, nF = 0, rapidos = 0;
  float pico = 0;
  for (int i = 0; i < LARGO_PATRON; i++) {
    if (gestos[i] == 'I') nI++;
    if (gestos[i] == 'P') nP++;
    if (gestos[i] == 'S') nS++;
    if (gestos[i] == 'F') nF++;
    if (ritmos[i] == 'r') rapidos++;
    pico = max(pico, fijPico[i]);
  }
  float seg = (ultimoGestoMs - primerGestoMs) / 1000.0;

  ArrayList<String> autores = new ArrayList<String>();
  ArrayList<Integer> voces = new ArrayList<Integer>();
  for (int i = 0; i < LARGO_PATRON; i++) {
    String a = split(credito(creditosImg, fijImagen[i]), " · ")[0];
    if (!autores.contains(a)) autores.add(a);
    if (!voces.contains(fijEstacion[i])) voces.add(fijEstacion[i]);
  }

  String[] porVideo = {
    "Abriste la maleta con el cuerpo: la inclinaste y la volviste parte de tu recorrido. Tu lectura del museo es un desplazamiento entre salas.",
    "Abriste la maleta acercándote: elegiste mirar de cerca, como quien busca lo que las cédulas no dicen.",
    "Abriste la maleta con tu voz, y el museo te respondió con las voces de sus salas y visitantes."
  };
  lectura[0] = porVideo[categoriaElegida];
  if (rapidos >= 3) lectura[1] = "Tu ritmo fue rápido: saltaste de fragmento en fragmento, como un recorrido que no se detiene.";
  else if (rapidos <= 1) lectura[1] = "Hiciste pausas largas: tu recorrido se detuvo a escuchar y a volver a mirar.";
  else lectura[1] = "Alternaste prisa y pausa: un recorrido que a veces se detiene.";
  if (nF > 0) lectura[2] = "Alzaste la voz al menos una vez: un sonido fuerte rompió el silencio de las vitrinas.";
  else if (nS > 0) lectura[2] = "Hablaste bajo, como se aprende a hablar en un museo.";
  else lectura[2] = "No usaste tu voz: dejaste que hablaran las piezas.";
  lectura[3] = "En " + nf(seg, 0, 1) + " segundos fijaste " + LARGO_PATRON + " imágenes de " + autores.size() +
               " miradas distintas y atrapaste " + voces.size() + (voces.size() == 1 ? " voz" : " voces") +
               ". Esta versión del relato es solo tuya.";

  barraValor[0] = nI / 5.0;  barraTexto[0] = nI + (nI == 1 ? " gesto" : " gestos");
  barraValor[1] = nP / 5.0;  barraTexto[1] = nP + (nP == 1 ? " gesto" : " gestos");
  barraValor[2] = (nS + nF) / 5.0;  barraTexto[2] = (nS + nF) + ((nS + nF) == 1 ? " gesto" : " gestos");
  barraValor[3] = rapidos / 4.0;
  barraTexto[3] = rapidos >= 3 ? "rápido" : (rapidos <= 1 ? "pausado" : "mixto");
  barraValor[4] = constrain(pico / 180.0, 0, 1);
  barraTexto[4] = nF > 0 ? "fuerte" : (nS > 0 ? "media" : "silencio");
}

// =====================================================
//  DIBUJO
// =====================================================

void dibujarFondo(int ahora) {
  Movie v = videos[videoFondo];
  if (v.width > 0) dibujarCubriendo(v, 0, 0, width, height);
  noStroke();
  fill(16, 13, 11, 190);
  rect(0, 0, width, height);
  int d = ahora - cambioVideoMs;
  if (d < 350) estatica(0, 0, width, height, int(1200 * (1 - d / 350.0)), 90);
}

void dibujarTextosCerrada(int ahora) {
  textAlign(CENTER, CENTER);
  fill(240);
  textSize(34);
  text("¿Qué hay dentro de la maleta?", width / 2, 60);
  fill(180);
  textSize(18);
  text("Todo está pasando a la vez. Tus gestos detienen lo que ves y lo que escuchas.", width / 2, 98);

  // Dial de emisoras
  float x0 = width / 2 - 320, x1 = width / 2 + 320, y = 600;
  stroke(210, 171, 95, 130);
  strokeWeight(2);
  line(x0, y, x1, y);
  noStroke();
  for (int i = 0; i < TOTAL_AUDIOS; i++) {
    float xx = lerp(x0, x1, i / (float) max(1, TOTAL_AUDIOS - 1));
    fill(i == estacion ? C_BRONCE : color(210, 171, 95, 110));
    rect(xx - 1, y - 8, 2, 16);
  }
  float jit = ahora < estaticaHasta ? random(-20, 20) : 0;
  float nx = lerp(x0, x1, estacion / (float) max(1, TOTAL_AUDIOS - 1)) + jit;
  fill(C_F);
  rect(nx - 2, y - 16, 4, 32);
  fill(215, 205, 190);
  textSize(16);
  textAlign(CENTER, CENTER);
  text(ahora < estaticaHasta ? "sintonizando..." : "Suena: " + credito(creditosAud, estacion), width / 2, y + 30);

  char[] tipos = {'I', 'P', 'S', 'F'};
  String[] etiquetas = {"inclínala", "acerca tu mano", "haz un sonido", "sonido fuerte"};
  float inicio = width / 2 - 440;
  for (int i = 0; i < 4; i++) {
    float lx = inicio + i * 230;
    dibujarLuz(tipos[i], lx, 668, 24);
    fill(210);
    textAlign(LEFT, CENTER);
    textSize(16);
    text(etiquetas[i], lx + 20, 667);
  }
  fill(140);
  textAlign(CENTER, CENTER);
  textSize(14);
  text("Cada gesto fija un fragmento. Con " + LARGO_PATRON + " fragmentos la maleta se desbloquea.", width / 2, 700);
}

void dibujarTapa(float x, float y, float w, float h, float alfa, int ahora) {
  int al = int(255 * alfa);

  noFill();
  stroke(70, 42, 22, al);
  strokeWeight(18);
  rect(x + w / 2 - 90, y - 60, 180, 78, 24);

  noStroke();
  fill(122, 74, 40, al);
  rect(x, y, w, h, 28);
  noFill();
  stroke(235, 195, 145, al * 0.35);
  strokeWeight(2);
  rect(x + 16, y + 16, w - 32, h - 32, 20);
  noStroke();
  fill(0, 70 * alfa);
  rect(x, y + h * 0.2, w, 6);
  fill(200, 170, 90, al);
  rect(x + w * 0.13 - 32, y + h * 0.2 - 22, 64, 46, 6);
  rect(x + w * 0.87 - 32, y + h * 0.2 - 22, 64, 46, 6);

  // Cerradura con 5 ranuras
  float pw = 640, ph = 168;
  float px = x + w / 2 - pw / 2, py = y + h * 0.6 - ph / 2;
  fill(30, 24, 22, al);
  rect(px, py, pw, ph, 18);
  noFill();
  stroke(210, 171, 95, al);
  strokeWeight(3);
  rect(px, py, pw, ph, 18);

  float sw = 108, sh = 81, gap = 16;
  float sx0 = px + (pw - (5 * sw + 4 * gap)) / 2, sy = py + 16;
  for (int i = 0; i < LARGO_PATRON; i++) {
    float sx = sx0 + i * (sw + gap);
    noStroke();
    fill(13, 11, 10, al);
    rect(sx, sy, sw, sh, 6);
    tint(255, al);
    if (i < totalGestos) {
      dibujarCubriendo(imagenes[fijImagen[i]], sx, sy, sw, sh);
    } else if (i == totalGestos && (estado == ESPERA || estado == GRABANDO)) {
      dibujarCubriendo(imagenes[imagenFlujo], sx, sy, sw, sh);
      estatica(sx, sy, sw, sh, 160, 120);
    } else {
      estatica(sx, sy, sw, sh, 70, 45);
    }
    noTint();
    noFill();
    strokeWeight(i < totalGestos ? 3 : 2);
    if (i < totalGestos) {
      stroke(colorGesto(gestos[i]), al);
      rect(sx, sy, sw, sh, 6);
      dibujarLuz(gestos[i], sx + 12, sy + 12, 22);
      if (i > 0) dibujarRitmo(ritmos[i], sx - gap / 2, sy + sh / 2);
    } else if (i == totalGestos) {
      float b = 0.5 + 0.5 * sin(ahora * 0.012);
      stroke(210, 171, 95, al * (0.4 + 0.6 * b));
      rect(sx, sy, sw, sh, 6);
    }
  }

  String txt = "CERRADA  ·  haz tu primer gesto para fijar lo que pasa";
  if (estado == GRABANDO) txt = totalGestos + " de " + LARGO_PATRON + " fragmentos fijados";
  if (estado == ABRIENDO) txt = "CONTENIDO FIJADO  ·  desbloqueando...";
  noStroke();
  fill(225, 204, 154, al);
  textAlign(CENTER, CENTER);
  textSize(15);
  text(txt, x + w / 2, py + 124);

  if (estado == GRABANDO) {
    float resto = 1 - (millis() - ultimoGestoMs) / (float) TIEMPO_MAX_ENTRE_GESTOS;
    fill(255, 30);
    rect(px + 50, py + 146, pw - 100, 4);
    fill(210, 171, 95, al);
    rect(px + 50, py + 146, (pw - 100) * constrain(resto, 0, 1), 4);
  }
}

void dibujarInterior(float x, float y, float w, float h, float a, int ahora) {
  noStroke();
  fill(42, 26, 18, 245);
  rect(x, y, w, h, 28);
  fill(60, 24, 34, 245);
  rect(x + 12, y + 12, w - 24, h - 24, 20);

  float pad = 24, zona = 60;
  float vx = x + pad, vy = y + pad;
  float vw = (w - pad * 3) * 0.5, vh = h - pad * 2 - zona;
  float rx = vx + vw + pad, ry = vy, rw = w - pad * 3 - vw;
  int t = estado == ABIERTA ? max(0, ahora - inicioEstado) : 0;

  // Video fijado
  fill(11, 9, 8);
  rect(vx, vy, vw, vh, 10);
  Movie v = videos[videoElegido];
  if (v.width > 0) {
    tint(255, 255 * a);
    dibujarAjustado(v, vx, vy, vw, vh);
    noTint();
  }
  if (a >= 1) etiqueta("VIDEO " + (videoElegido + 1) + "  ·  lo abriste con " + nombreCategoria(categoriaElegida), vx + 10, vy + 10);

  if (estado == ABIERTA) {
    fill(240, 230, 216);
    textAlign(LEFT, TOP);
    textSize(24);
    text("Tu interpretación del museo", rx, ry);

    // Imagen grande que recorre los fragmentos fijados
    float iy = ry + 40, ih = 210;
    int k = (t / 2200) % LARGO_PATRON;
    fill(11, 9, 8);
    rect(rx, iy, rw, ih, 8);
    dibujarAjustado(imagenes[fijImagen[k]], rx, iy, rw, ih);
    etiqueta("Foto: " + split(credito(creditosImg, fijImagen[k]), " · ")[0], rx + 6, iy + ih - 34);

    // Tira de miniaturas
    float ty = iy + ih + 8, tw = (rw - 4 * 6) / 5.0, th = 50;
    for (int i = 0; i < LARGO_PATRON; i++) {
      float tx = rx + i * (tw + 6);
      dibujarCubriendo(imagenes[fijImagen[i]], tx, ty, tw, th);
      noFill();
      strokeWeight(i == k ? 3 : 2);
      stroke(i == k ? color(240, 230, 216) : colorGesto(gestos[i]));
      rect(tx, ty, tw, th, 5);
      dibujarLuz(gestos[i], tx + 10, ty + 10, 16);
    }

    // Barras del perfil de interaccion
    float by = ty + th + 16;
    float p = suavizar(constrain((t - 600) / 1200.0, 0, 1));
    color[] colores = {C_I, C_P, C_S, color(230, 207, 156), C_F};
    for (int i = 0; i < 5; i++) {
      noStroke();
      fill(215, 205, 190);
      textAlign(LEFT, CENTER);
      textSize(14);
      text(barraNombre[i], rx, by + 6);
      fill(255, 26);
      rect(rx + 100, by, rw - 200, 12, 6);
      fill(colores[i]);
      rect(rx + 100, by, max(4, (rw - 200) * barraValor[i] * p), 12, 6);
      fill(180, 167, 150);
      textAlign(RIGHT, CENTER);
      text(barraTexto[i], rx + rw, by + 6);
      by += 24;
    }

    // Lectura escrita
    float alfaTexto = constrain((t - 1600) / 900.0, 0, 1);
    fill(240, 230, 216, 255 * alfaTexto);
    textAlign(LEFT, TOP);
    textSize(14);
    textLeading(18);
    String todo = lectura[0] + "\n" + lectura[1] + "\n" + lectura[2] + "\n" + lectura[3];
    text(todo, rx, by + 8, rw, y + h - pad - zona - (by + 8));
  }

  if (a >= 1) {
    float fy = y + h - pad - zona + 10, fh = zona - 10, cy = fy + fh / 2;
    fill(240, 230, 216);
    textAlign(LEFT, CENTER);
    textSize(16);
    text("Tus gestos:", x + pad, cy);
    for (int i = 0; i < LARGO_PATRON; i++) {
      float px = x + pad + 110 + i * 48;
      if (i > 0) dibujarRitmo(ritmos[i], px - 24, cy);
      dibujarLuz(gestos[i], px, cy, 30);
    }
    fill(240, 230, 216);
    textAlign(RIGHT, CENTER);
    textSize(16);
    text("Código " + codigo, x + w - pad, cy - 10);
    fill(201, 180, 138);
    textSize(14);
    text("Voz atrapada: " + credito(creditosAud, audioElegido), x + w - pad, cy + 12);

    float resto = 1 - (ahora - inicioEstado) / (float) DURACION_ABIERTA_MS;
    noStroke();
    fill(255, 40);
    rect(x + pad, fy + fh - 3, w - pad * 2, 3);
    fill(C_BRONCE);
    rect(x + pad, fy + fh - 3, (w - pad * 2) * constrain(resto, 0, 1), 3);
  }
}

void dibujarPanel(int s, int i, int p) {
  noStroke();
  fill(0, 210);
  rect(10, 10, 360, 156, 8);
  fill(255);
  textAlign(LEFT, TOP);
  textSize(14);
  text("Arduino: " + (arduinoConectado ? PUERTO_ARDUINO : "no conectado (teclado)"), 20, 18);
  text("Sonido: " + s + "   (bajo " + UMBRAL_BAJO + " / alto " + UMBRAL_ALTO + ")", 20, 40);
  text("Inclinación: " + i + "   reposo: " + inclinacionReposo, 20, 62);
  text("IR: " + p + (estabaCerca ? "   cerca" : "   lejos"), 20, 84);
  text("Estado: " + nombreEstado() + "   voz: " + (estacion + 1), 20, 106);
  text("Fijados: " + totalGestos + " de " + LARGO_PATRON, 20, 128);
}

// ---------------- utilidades de dibujo ----------------

void dibujarAjustado(PImage medio, float x, float y, float w, float h) {
  if (medio == null || medio.width <= 0 || medio.height <= 0) return;
  float escala = min(w / medio.width, h / medio.height);
  float ancho = medio.width * escala, alto = medio.height * escala;
  image(medio, x + (w - ancho) / 2, y + (h - alto) / 2, ancho, alto);
}

// Llena el rectangulo recortando lo que sobra.
void dibujarCubriendo(PImage medio, float x, float y, float w, float h) {
  if (medio == null || medio.width <= 0 || medio.height <= 0) return;
  float escala = max(w / medio.width, h / medio.height);
  float ancho = medio.width * escala, alto = medio.height * escala;
  clip(x, y, w, h);
  image(medio, x + (w - ancho) / 2, y + (h - alto) / 2, ancho, alto);
  noClip();
}

void estatica(float x, float y, float w, float h, int n, float alfaMax) {
  noStroke();
  for (int i = 0; i < n; i++) {
    fill(255, random(alfaMax));
    rect(x + random(w), y + random(h), 2, 2);
  }
}

void dibujarLuz(char g, float x, float y, float d) {
  noStroke();
  fill(colorGesto(g));
  ellipse(x, y, d, d);
  fill(20);
  textAlign(CENTER, CENTER);
  textSize(d * 0.45);
  text(g, x, y - d * 0.04);
}

void dibujarRitmo(char r, float x, float y) {
  noStroke();
  fill(230, 207, 156);
  if (r == 'r') ellipse(x, y, 7, 7);
  else rect(x - 6, y - 2, 12, 4);
}

void etiqueta(String s, float x, float y) {
  textSize(13);
  float w = textWidth(s) + 20;
  noStroke();
  fill(0, 165);
  rect(x, y, w, 24, 12);
  fill(255, 230);
  textAlign(LEFT, CENTER);
  text(s, x + 10, y + 12);
}

// ---------------- auxiliares ----------------

float suavizar(float a) {
  return a < 0.5 ? 4 * a * a * a : 1 - pow(-2 * a + 2, 3) / 2;
}

// La carpeta medios/ puede estar junto al sketch o un nivel arriba (como en el repositorio).
String buscarCarpetaMedios() {
  File arriba = new File(sketchPath("../medios"));
  if (arriba.isDirectory()) return arriba.getAbsolutePath();
  return sketchPath("medios");
}

File[] listarArchivos(String carpeta, String[] extensiones) {
  File dir = new File(carpeta);
  File[] todos = dir.listFiles();
  if (todos == null) return new File[0];
  ArrayList<File> validos = new ArrayList<File>();
  for (File f : todos) {
    String n = f.getName().toLowerCase();
    if (f.isDirectory() || n.startsWith(".")) continue;
    for (String e : extensiones) if (n.endsWith(e)) { validos.add(f); break; }
  }
  File[] r = validos.toArray(new File[0]);
  Arrays.sort(r, new Comparator<File>() {
    public int compare(File a, File b) { return a.getName().compareToIgnoreCase(b.getName()); }
  });
  return r;
}

StringDict leerCreditos(String ruta) {
  StringDict d = new StringDict();
  if (!new File(ruta).exists()) return d;
  Table t = loadTable(ruta, "header, csv");
  if (t == null) return d;
  for (TableRow fila : t.rows()) {
    String archivo = fila.getString(0), credito = fila.getString(1);
    if (archivo == null || credito == null) continue;
    d.set(archivo.trim(), credito.trim());
    String solo = new File(archivo.trim()).getName();
    if (!d.hasKey(solo)) d.set(solo, credito.trim());
  }
  return d;
}

// Credito del CSV o, si no hay, uno armado con el nombre del archivo.
String creditoDe(StringDict creditos, String rel) {
  if (creditos.hasKey(rel)) return creditos.get(rel);
  String nombre = new File(rel).getName();
  if (creditos.hasKey(nombre)) return creditos.get(nombre);
  int punto = nombre.lastIndexOf('.');
  String base = punto > 0 ? nombre.substring(0, punto) : nombre;
  base = base.replaceAll("[-_]+", " ").trim();
  return base.length() > 0 ? base.substring(0, 1).toUpperCase() + base.substring(1) : nombre;
}

String credito(String[] lista, int i) {
  if (lista == null || i < 0 || i >= lista.length) return "";
  return lista[i];
}

String nombreCategoria(int c) {
  if (c == 0) return "movimiento";
  if (c == 1) return "cercanía";
  return "voz";
}

color colorGesto(char g) {
  if (g == 'I') return C_I;
  if (g == 'P') return C_P;
  if (g == 'S') return C_S;
  return C_F;
}

String nombreGesto(char g) {
  if (g == 'I') return "inclinacion";
  if (g == 'P') return "proximidad";
  if (g == 'S') return "sonido medio";
  return "sonido fuerte";
}

String nombreEstado() {
  if (estado == ESPERA) return "espera";
  if (estado == GRABANDO) return "fijando";
  if (estado == ABRIENDO) return "abriendo";
  return "abierta";
}

void mostrarMensaje(String m) {
  mensaje = m;
  mensajeHasta = millis() + 3000;
}

// =====================================================
//  TECLADO (pruebas sin sensores)
// =====================================================

void keyPressed() {
  char k = Character.toLowerCase(key);
  if (k == 'i') registrarGesto('I', 0);
  else if (k == 'p') registrarGesto('P', 0);
  else if (k == 's') registrarGesto('S', 65);
  else if (k == 'f') registrarGesto('F', 160);
  else if (k == 'r') { cerrarMaleta(); mostrarMensaje("Maleta reiniciada."); }
  else if (k == 'd') mostrarPanel = !mostrarPanel;
}

// =====================================================
//  SERIAL Y VIDEO
// =====================================================

// Recibe: nivelSonido,inclinacion,proximidad
void serialEvent(Serial origen) {
  String linea = origen.readStringUntil('\n');
  if (linea == null) return;
  String[] datos = split(trim(linea), ',');
  if (datos.length != 3) return;
  try {
    nivelSonido = int(datos[0]);
    estadoInclinacion = int(datos[1]);
    estadoProximidad = int(datos[2]);
  } catch (Exception error) {
    println("Dato serial no valido: " + linea);
  }
}

void movieEvent(Movie pelicula) {
  pelicula.read();
}
