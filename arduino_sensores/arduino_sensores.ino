const int PIN_SONIDO = A0;
const int PIN_INCLINACION = 3;
const int PIN_PROXIMIDAD = 4;

void setup() {
  Serial.begin(115200);
  pinMode(PIN_INCLINACION, INPUT);
  pinMode(PIN_PROXIMIDAD, INPUT);
}

void loop() {
  // Medir variacion del sonido durante 40 ms.
  int minimo = 1023;
  int maximo = 0;

  for (int i = 0; i < 40; i++) {
    int lectura = analogRead(PIN_SONIDO);
    if (lectura < minimo) minimo = lectura;
    if (lectura > maximo) maximo = lectura;
    delay(1);
  }

  int nivelSonido = maximo - minimo;
  int inclinacion = digitalRead(PIN_INCLINACION);
  int proximidad = digitalRead(PIN_PROXIMIDAD);

  // Formato: sonido,inclinacion,proximidad
  Serial.print(nivelSonido);
  Serial.print(",");
  Serial.print(inclinacion);
  Serial.print(",");
  Serial.println(proximidad);
}
