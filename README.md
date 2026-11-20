# Verificador de Dígito de Legajo — Técnicas Digitales 1 (R3051) - Matteucci Nicolás - **Legajo:** 204710-0
---
link al repo: https://github.com/NicoMatteucci/TP_TD1_Matteucci/tree/main
---

## 1. Descripción del Proyecto y Algoritmo

Este repositorio contiene el diseño RTL (*Register-Transfer Level*) sintetizable y el entorno de verificación en **Verilog** de un circuito secuencial que calcula el dígito verificador de un legajo de 6 dígitos decimales.

Los dígitos ingresan de forma serializada de a uno por ciclo válido (`valid = 1`), comenzando por el más significativo ($a$) hasta el menos significativo ($f$). El circuito calcula la suma ponderada:

$$S = 7a + 6b + 5c + 4d + 3e + 2f$$

Posteriormente, obtiene de forma secuencial el resto de dividir $S$ por $11$ mediante **restas sucesivas** (un máximo de una resta por ciclo de reloj, sin utilizar operadores `/` ni `%`). Finalmente, asigna el dígito verificador según la regla:

$$\text{Verificador} = \begin{cases} S \bmod 11 & \text{si } 0 \le (S \bmod 11) \le 9 \\ 0 & \text{si } (S \bmod 11) = 10 \end{cases}$$

---

## 2. Estructura del Repositorio

El proyecto sigue un **diseño jerárquico** que separa los bloques genéricos reutilizables, el camino de datos (*Datapath*), la unidad de control (*FSM*) y el entorno de simulación:

```text
TP_TD1_Matteucci/
├── .gitignore                  # Exclusión de archivos temporales de simulación (*.vvp, *.vcd, work/)
├── README.md                   # Documentación técnica, diagramas y análisis del diseño
├── docs/                       # Capturas de simulación en GTKWave y consola
├── src/                        # Código fuente Verilog sintetizable (sin retardos # ni bloques initial)
│   ├── reg_arst.v              # Registro parametrizable con reset asincrónico (arst) y enable
│   ├── contador_arst.v         # Contador ascendente parametrizable con arst, clear sincrónico y enable
│   ├── mux2to1.v               # Multiplexor 2 a 1 parametrizable
│   ├── calc_peso_prod.v        # Lógica combinacional de selección de peso (7..2) y producto parcial
│   ├── datapath_legajo.v       # Camino de datos completo y generación de banderas de estado
│   ├── control_legajo.v        # Unidad de control implementada como FSM de 3 bloques
│   └── verificador_legajo.v    # Módulo Top-Level (interfaz externa especificada)
└── simulaciones/               # Entorno de verificación
    ├── Makefile                # Automatización de compilación (iverilog), simulación (vvp) y ondas
    └── tb_verificador_legajo.v # Testbench autoverificable con reloj de período 20 ns
```

---

## 3. Cómo Compilar y Simular

El proyecto utiliza **Icarus Verilog** (`iverilog` / `vvp`) y **GTKWave** automatizados mediante `Makefile`.

Desde una terminal ubicada en la carpeta `simulaciones/`:

```bash
cd simulaciones

# Compilar y ejecutar la simulación en consola (muestra resultados [OK] / [ERROR])
make run

# Compilar, simular y abrir las formas de onda en GTKWave
make view

# Limpiar archivos generados (work/ y *.vcd)
make clean
```

---

## 4. Arquitectura del Sistema (FSMD)

### 4.1. Diagrama Top Level (`verificador_legajo`)

El sistema implementa una arquitectura **FSMD** (*Finite State Machine with Datapath*), desacoplando el gobierno temporal (`control_legajo`) del procesamiento aritmético (`datapath_legajo`):
<img width="1603" height="1200" alt="top_level" src="https://github.com/user-attachments/assets/a1c9b215-0397-4002-96f3-6fd653d7bcd4" />

---

### 4.2. Descripción de la Unidad de Control (`control_legajo`)

La unidad de control está codificada siguiendo el estándar de **3 bloques `always`** (registro de estado secuencial, lógica combinacional de estado futuro y lógica combinacional de salidas con valores por defecto para evitar *latches*):

1. **`S_IDLE` (`2'b00`):** Estado de reposo tras el reset asincrónico (`arst = 1`) o luego de finalizar una operación. Mantiene `busy = 0` y `done = 0`, conservando el último dígito verificador calculado. Ante `start = 1`, activa `clr_acum` y `clr_cnt` para limpiar el acumulador y el índice de posición, pasando a `S_LOAD`.
2. **`S_LOAD` (`2'b01`):** Estado de recepción y acumulación ponderada (`busy = 1`, `sel_op = 0`). Ignora pulsos adicionales en `start`. Si `valid = 0`, mantiene deshabilitados los registros conservando la suma parcial y el peso actual. Por cada flanco ascendente con `valid = 1`, habilita `en_acum` y `en_cnt` para incorporar `dato * peso`. Al validarse el sexto dígito (`ultimo_digito == 1`), transiciona a `S_MOD`.
3. **`S_MOD` (`2'b10`):** Estado de cálculo secuencial del resto (`busy = 1`, `sel_op = 1`). Ignora la entrada `valid`. Mientras el acumulador sea mayor o igual a $11$ (`menor_11 == 0`), habilita `en_acum` para restar $11$ una vez por ciclo de reloj. Cuando detecta `menor_11 == 1`, habilita `en_verif` para registrar el dígito verificador (convirtiendo `10` en `0`) y salta a `S_DONE`.
4. **`S_DONE` (`2'b11`):** Estado de entrega de resultado. Desactiva `busy` (`0`) y activa `done` (`1`) durante **exactamente un ciclo de reloj**. Retorna a `S_IDLE` (o inicia directamente una nueva carga si `start = 1`).

#### Diagrama de Estados (FSM)

<img width="1131" height="1600" alt="fsm_control" src="https://github.com/user-attachments/assets/92a42445-e141-4b69-9cfd-9f6560989d46" />

---

### 4.3. Descripción del Datapath (`datapath_legajo`)

El camino de datos ejecuta las operaciones aritméticas y almacena el estado interno del cálculo bajo el gobierno de las señales de control emitidas por la UC `control_legajo`. Su estructura se organiza en cuatro bloques funcionales:

1. **Registros de almacenamiento (Secuenciales con `arst`):**
   * **`cnt_pos` (`3 bits`):** Contador ascendente que mantiene el índice del dígito actual (`idx_digito`, de `0` a `5`). Se reinicia sincrónicamente mediante `clr_cnt` y avanza solo cuando `en_cnt = 1`.
   * **`reg_acumulador` (`8 bits`):** Registro central (`acum_q`) que almacena tanto las sumas ponderadas parciales durante `S_LOAD` como los restos sucesivos durante `S_MOD`. Se actualiza cuando `en_acum` o `clr_acum` están activos.
   * **`reg_verificador` (`4 bits`):** Registro de salida (`verificador`) que captura el dígito verificador final al activarse `en_verif` y lo retiene estable entre operaciones sucesivas.

2. **Unidades funcionales (Combinacionales):**
   * **`u_peso_prod` (`calc_peso_prod`):** Decodifica `idx_digito` (`0..5`) para asignar el peso correspondiente ($7, 6, 5, 4, 3, 2$) y calcula el producto parcial `dato * peso` en un bus de `6 bits` (máximo $9 \times 7 = 63$).
   * **Sumador y Restador (`8 bits`):** Calculan en paralelo las dos posibles actualizaciones del acumulador: la suma ponderada (`acum_q + producto`) y la resta modular (`acum_q - 11`).
   * **Conversor Módulo 11 a BCD:** Mapea combinacionalmente el resto final para que, si `acum_q == 10`, la entrada del registro de salida sea `4'd0`, y en cualquier otro caso (`0..9`) pase `acum_q[3:0]`.

3. **Lógica de enrutamiento (Multiplexores):**
   * **`mux_operacion` (`sel_op`):** Selecciona entre la rama de acumulación (`sel_op = 0`) y la rama de resta de 11 (`sel_op = 1`), permitiendo reutilizar el mismo registro `reg_acumulador` en ambas fases del algoritmo.
   * **`mux_clear_acum` (`clr_acum`):** Ante un nuevo inicio (`clr_acum = 1`), enruta `8'd0` hacia la entrada del acumulador para limpiarlo sincrónicamente antes de cargar el primer dígito.

4. **Generación de banderas de estado (hacia la FSM):**
   * **`ultimo_digito`:** Se activa en `1` cuando `idx_digito == 3'd5`, indicando a la unidad de control que se está procesando el sexto y último dígito.
   * **`menor_11`:** Comparador sin signo (`acum_q < 8'd11`) que informa a la unidad de control que el acumulador ya contiene el resto definitivo.

#### Diagrama RTL del Datapath

<img width="1131" height="1600" alt="datapath_rtl" src="https://github.com/user-attachments/assets/3f484629-a432-4743-a4ae-adae338a74cf" />

#### Tabla de Operaciones RTL (Palabras de Control)

| Fase / Estado FSM | Condición | Señales Activas de Control | Transferencia entre Registros (RTL) |
| :--- | :--- | :--- | :--- |
| **Inicio (`S_IDLE` / `S_DONE`)** | `start = 1` | `clr_acum = 1`, `clr_cnt = 1` | `acum_q <= 0`, `idx_digito <= 0` *(conserva `verificador`)* |
| **Carga (`S_LOAD`)** | `valid = 0` | Ninguna (`en_acum = 0`, `en_cnt = 0`) | `acum_q <= acum_q`, `idx_digito <= idx_digito` *(pausa)* |
| **Carga (`S_LOAD`)** | `valid = 1` | `sel_op = 0`, `en_acum = 1`, `en_cnt = 1` | `acum_q <= acum_q + dato * peso(idx)`, `idx_digito <= idx_digito + 1` |
| **Resta (`S_MOD`)** | `menor_11 = 0` | `sel_op = 1`, `en_acum = 1` | `acum_q <= acum_q - 11` |
| **Captura (`S_MOD`)** | `menor_11 = 1` | `en_verif = 1` | `verificador <= (acum_q == 10) ? 0 : acum_q[3:0]` |

---

## 5. Análisis del Diseño (Sección 9)

### a. ¿Cuál es la máxima suma ponderada y cuántos bits requiere el acumulador?
Dado que cada dígito ingresado está en el rango decimal $[0, 9]$, la máxima suma ponderada se produce con la entrada `999999`:

$$S_{\max} = 9 \cdot (7 + 6 + 5 + 4 + 3 + 2) = 9 \cdot 27 = 243$$

Para representar valores enteros sin signo en el rango $[0, 243]$ sin riesgo de desbordamiento (*overflow*), se requieren:

$$N_{\text{acum}} = \lceil \log_2(243 + 1) \rceil = \lceil \log_2(244) \rceil = 8\text{ bits} \quad (\texttt{[7:0]})$$

*(Con 8 bits se representan valores de $0$ a $255$, cubriendo el peor caso $243$. Asimismo, las señales intermedias están dimensionadas para evitar truncamientos: los pesos ocupan 3 bits y el producto parcial máximo $9 \times 7 = 63$ ocupa 6 bits).*

### b. ¿Cuál es la máxima cantidad de restas necesarias para obtener el resto?
Partiendo de la suma máxima posible ($S_{\max} = 243$) y restando $11$ una vez por ciclo de reloj mientras $\text{acum} \ge 11$:

$$243 = 22 \times 11 + 1$$

Por lo tanto, se requieren como máximo **22 restas** ($243 \rightarrow 232 \rightarrow \dots \rightarrow 12 \rightarrow 1$). En el ciclo siguiente (23º ciclo en `S_MOD`), el comparador detecta que $1 < 11$ y finaliza la operación.

### c. ¿Cómo garantiza que el sexto dígito quede incluido en el cálculo?
Durante el estado `S_LOAD`, el contador `cnt_pos` indexa los dígitos recibidos desde `0` (1.º dígito, peso 7) hasta `5` (6.º dígito, peso 2). Cuando `idx_digito == 3'd5`, se activa la bandera combinacional `ultimo_digito = 1`. Al presentarse `valid = 1` en ese ciclo, la unidad de control activa simultáneamente `en_acum = 1` y selecciona el estado futuro `S_MOD`. De este modo, en el **mismo flanco ascendente de `clk`** en que la FSM pasa a `S_MOD`, el registro `reg_acumulador` almacena la suma definitiva incluyendo el producto parcial del sexto dígito (`dato * 2`).

### d. ¿Qué registros conservan su valor cuando `valid = 0` durante la recepción?
Cuando la FSM se encuentra en `S_LOAD` y `valid = 0`, las señales de habilitación `en_acum` y `en_cnt` permanecen en `0`. En consecuencia, conservan su valor:
1. **`reg_acumulador` (8 bits):** Mantiene intacta la suma ponderada parcial acumulada hasta ese momento.
2. **`cnt_pos` (3 bits):** Mantiene el índice de posición del próximo dígito esperado (y, por ende, su peso asociado).
3. **`reg_verificador` (4 bits):** También conserva el resultado de la operación anterior hasta que finalice el nuevo cálculo (o se active `arst`).

### e. ¿Por qué los restos 0 y 10 producen el mismo dígito verificador?
Porque el dígito verificador debe representarse mediante un **único carácter decimal** ($0$ a $9$, codificado en 4 bits). Al calcular el resto de dividir por $11$, existen 11 residuos posibles en el conjunto $\{0, 1, 2, \dots, 9, 10\}$. Como el resto $10$ requiere dos cifras decimales y no puede expresarse en un solo dígito, la convención del algoritmo Módulo 11 mapea el resto $10$ al dígito `0` (al igual que el resto $0$), garantizando que la salida `verificador` siempre pertenezca al rango $[0, 9]$.

---

## 6. Resultados de Simulación y Registro de Pruebas

El diseño fue verificado mediante el banco de pruebas `tb_verificador_legajo.v` con un reloj de período $T_{\text{clk}} = 20\text{ ns}$ ($f = 50\text{ MHz}$). Se comprobaron todos los casos de la tabla obligatoria, pausas con `valid = 0`, inmunidad ante pulsos espurios de `start`/`valid` cuando `busy = 1`, retención del resultado previo, duración de 1 ciclo de `done` y aborto por reset asincrónico `arst`.

### 6.1. Tabla de Casos Verificados

| Dígitos Ingresados | Suma Ponderada ($S$) | Resto ($S \bmod 11$) | Verificador Esperado | Verificador Obtenido | Ciclos de Resta (`S_MOD`) | Estado |
| :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| `204710` | `65` | `10` | `0` | `0` | 5 | EXITO |
| `123456` | `77` | `0` | `0` | `0` | 7 | EXITO |
| `654321` | `112` | `2` | `2` | `2` | 10 | EXITO |
| `111111` | `27` | `5` | `5` | `5` | 2 | EXITO |
| `100007` | `21` | `10` | `0` | `0` | 1 | EXITO |
| `000000` | `0` | `0` | `0` | `0` | 0 | EXITO |
| `999999` | `243` | `1` | `1` | `1` | 22 | EXITO |

### 6.2. Salida de Consola (`make run`)

```text
=======================================================================================
 INICIO DE SIMULACION: verificador_legajo (CLK_PERIOD = 20 ns)
=======================================================================================
                       --- Reset asincronico. ---
[OK] Legajo 204710 (rafaga) -> Verif = 0 | Restas:  5 (ciclos S_MOD:  6) | t=311000 ns
[OK] Legajo 123456 ( pausa) -> Verif = 0 | Restas:  7 (ciclos S_MOD:  8) | t=851000 ns
[OK] Legajo 654321 ( pausa) -> Verif = 2 | Restas: 10 (ciclos S_MOD: 11) | t=1451000 ns
[OK] Legajo 111111 (rafaga) -> Verif = 5 | Restas:  2 (ciclos S_MOD:  3) | t=1671000 ns
[OK] Legajo 100007 (rafaga) -> Verif = 0 | Restas:  1 (ciclos S_MOD:  2) | t=1871000 ns
[OK] Legajo 000000 ( pausa) -> Verif = 0 | Restas:  0 (ciclos S_MOD:  1) | t=2271000 ns
[OK] Legajo 999999 (rafaga) -> Verif = 1 | Restas: 22 (ciclos S_MOD: 23) | t=2891000 ns
                       --- Reset asincronico. ---
[OK] Legajo 654321 (rafaga) -> Verif = 2 | Restas: 10 (ciclos S_MOD: 11) | t=3351000 ns
=======================================================================================
 RESULTADO FINAL: EXITO - Todas las pruebas pasaron sin errores.
=======================================================================================
```

### 6.3. Ejemplos de legajos (`WaveTrace`)
<img width="1129" height="1132" alt="legajos_ejemplos" src="https://github.com/user-attachments/assets/26328841-94e0-4308-a52f-00535ddeff74" />


