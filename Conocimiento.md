# Documentación Técnica: Proyecto GreenBox

Este archivo documenta el aprendizaje técnico y arquitectónico del proyecto.

## 1. Arquitectura de Datos (Supabase)

La base de datos está diseñada para gestionar hardware, usuarios y lecturas optimizando el rendimiento mediante relaciones de integridad claras y un filtrado inteligente.

### Esquema de Base de Datos (Tablas Principales)

* **Tabla `plants`**
  - Función: Catálogo general y centralizado de los tipos de cultivos.
  - Atributos y Relaciones: Contiene metadatos como el nombre común, nombre científico, ruta de la imagen, días totales estimados de crecimiento y las distintas etapas de desarrollo parametrizadas en una estructura JSONB. También incluye las columnas de recomendación de humedad mínima y máxima para su sincronización interactiva.

* **Tabla `devices`**
  - Función: Entidad central que mapea de forma unívoca el hardware físico (ESP32).
  - Atributos y Relaciones: Mantiene una relación obligatoria de clave foránea vinculada a un dueño de usuario (identificador de autenticación) y a un cultivo específico del catálogo de plantas.

* **Tabla `thresholds`**
  - Función: Configuración de rangos óptimos operativos específicos por hardware.
  - Atributos y Relaciones: Mantiene una relación estricta de uno a uno (1:1) con la tabla de dispositivos. Almacena las variables críticas del entorno: límites de pH del agua (idealmente entre 5.5 y 6.5), límites de porcentaje de humedad ambiente (idealmente entre 60% y 80%), y límites de electroconductividad o EC para concentración de nutrientes (idealmente entre 1.2 y 2.0).

* **Tabla `sensor_data`**
  - Función: Histórico de series temporales para las métricas recolectadas.
  - Atributos y Relaciones: Utiliza un identificador único de tipo UUID como clave primaria para ofrecer soporte nativo a los flujos de transmisión en tiempo real de Supabase. Guarda los valores recolectados de los sensores y cuenta con una bandera lógica de excepción para reportes analíticos críticos.

### Conceptos Clave de Datos

* **Edge Filtering (Filtrado en el Borde):** Procesamiento de datos ejecutado directamente en el microcontrolador ESP32 para enviar hacia la nube únicamente los promedios temporales calculados o las lecturas que caigan en excepciones de rango, evitando saturar el tráfico de red.
* **MVP Strategy (Estrategia de Producto Mínimo Viable):** Modelo donde el hardware ejecuta lecturas analógicas locales de alta frecuencia (cada 1 segundo), pero implementa una persistencia en la nube de forma resumida, agregada o netamente reactiva ante situaciones de alerta.
* **Supabase Realtime:** Mecanismo de comunicación basado en WebSockets encargado de actualizar la interfaz de usuario de la aplicación móvil de manera instantánea cada vez que se detectan inserciones de nuevas filas de telemetría.

---

## 2. Integración de Hardware (ESP32)

### Sensores y Calibración
* **Sensor de Humedad Capacitivo:** Se seleccionó este componente debido a que, a diferencia de los sensores resistivos tradicionales, los capacitivos miden la humedad por propiedades dieléctricas sin exponer electrodos metálicos directos al sustrato, impidiendo la corrosión química prematura.
* **Funcionamiento:** Evalúa la capacitancia del suelo, la cual varía de forma proporcional de acuerdo con la constante dieléctrica del agua contenida en la tierra.
* **Calibración:** Requiere establecer de manera empírica los valores analógicos límites medidos en condiciones extremas denominadas "Aire" (completamente seco) y "Agua" (saturación total del medio) para poder mapear matemáticamente la lectura cruda a un porcentaje legible de cero a cien por ciento.

### Identificación Única Determinista (UUID por Hardware)
* **Problema de Base de Datos:** Supabase exige que la columna de identidad de los dispositivos corresponda estrictamente a un tipo de dato UUID estándar de PostgreSQL. Forzar identificadores arbitrarios de texto simple desencadena un error de sintaxis del sistema de base de datos bajo el código de diagnóstico 22p02 (entrada inválida para tipo UUID).
* **Solución Determinista:** En lugar de obligar al usuario a generar manualmente un token aleatorio, el microcontrolador ESP32 construye su propio identificador UUID sintácticamente válido aprovechando la dirección MAC física de seis bytes grabada en el chip desde fábrica.
* **Algoritmo de Generación:** El sistema lee la dirección MAC del chip por hardware y la concatena de forma hexadecimal al final de un prefijo de espacio de nombres preestablecido y exclusivo del proyecto.
* **Ventajas del Enfoque:**
  1. Unicidad Global: Al derivarse de la MAC física del fabricante, no existirán dos dispositivos con el mismo identificador a nivel mundial.
  2. Consistencia y Determinismo: El dispositivo siempre calculará exactamente el mismo UUID en cada ciclo de encendido sin depender de almacenamiento local persistente.
  3. Experiencia de Usuario Transparente: Al arrancar, el ESP32 inicializa su firmware e imprime el UUID formateado de manera visible en el monitor serial configurado a 115200 baudios, permitiendo que el usuario lo copie y lo use en la aplicación móvil de inmediato.

---

## 3. Estrategia de Telemetría Híbrida (Optimización Free-Tier)

Para operar la plataforma de manera fluida manteniéndose dentro de los límites del plan gratuito de Supabase (restringido a 500 MB de almacenamiento total y cuotas máximas de operaciones de escritura), se diseñó e implementó un modelo de transmisión de dos niveles diferenciados.

### Nivel 1: Telemetría Instantánea (Tiempo Real Sin Persistencia)
* **Tecnología Utilizada:** Canales de transmisión rápidos de Supabase Realtime (Broadcast vía WebSockets).
* **Mecanismo:** El hardware ESP32 toma lecturas analógicas cada un segundo. En lugar de ejecutar peticiones HTTP pesadas de inserción en tablas, encapsula el JSON de telemetría y lo transmite directamente como un evento de difusión instantánea hacia un canal de WebSockets dedicado por dispositivo.
* **Impacto de Almacenamiento:** Cero bytes. Debido a que la información viaja y se distribuye exclusivamente a través de la memoria RAM del servidor de WebSockets de Supabase sin tocar las tablas de disco de PostgreSQL, es posible procesar millones de lecturas diarias de manera gratuita y sin consumir espacio de almacenamiento. En el lado cliente (Flutter), se abre una escucha continua sobre este canal mediante un StreamController que transforma la carga útil en objetos utilizables por la interfaz con una latencia inferior a los 100ms.

### Nivel 2: Telemetría Histórica (Persistencia Inteligente)
* **Tecnología Utilizada:** Filtrado en el borde coordinado con peticiones HTTP tradicionales de persistencia.
* **Mecanismo:** El guardado físico de filas en la base de datos se reserva únicamente para dos escenarios de negocio: el almacenamiento de promedios consolidados a lo largo de un día completo o el reporte reactivo inmediato ante anomalías. Si en cualquier lectura de segundo el hardware detecta que variables como el pH, la humedad o la electroconductividad violan los límites de su configuración de umbrales, el ciclo ordinario se interrumpe y realiza una inserción de emergencia marcando una bandera de excepción activada.
* **Impacto de Almacenamiento:** Este enfoque disminuye drásticamente el volumen de transacciones de base de datos de un estimado de 86,400 registros diarios por dispositivo a únicamente una fila estándar diaria (acompañada de sus eventuales excepciones de salud), garantizando la viabilidad del servidor gratuito por años.

---

## 4. Diseño de App y Experiencia de Usuario (UI/UX)

### Arquitectura de Pantallas y Navegación
* **Panel Principal (Dashboard Screen):** Diseñado como la interfaz central de la aplicación, incorporando un carrusel dinámico de cultivos activos, indicadores visuales de métricas en tiempo real y componentes de gráficos históricos.
* **Gestión de Perfil (Profile Screen):** Administra la información del usuario autenticado (nombre, correo electrónico y avatar). Se encuentra integrada junto al panel principal dentro de un componente de navegación persistente indexado para asegurar transiciones instantáneas en memoria sin recargas.
* **Configuraciones del Sistema:** La aplicación móvil bloquea por completo la orientación de la pantalla a modo exclusivamente vertical para preservar el orden y consistencia del diseño visual, y configura el entorno de la aplicación para enmascarar las barras nativas de navegación del sistema operativo móvil.

### Resiliencia y Flujos Dinámicos
* **Catálogo Dinámico Local:** Para proteger el funcionamiento del sistema en escenarios con cortes de red o bases de datos nuevas, se integró un mecanismo de respuesta de emergencia en los repositorios de datos que provee configuraciones locales por defecto para cultivos predeterminados de Espinaca y Lechuga.
* **Interactividad en Registro:** Al interactuar con la pantalla de creación de plantas, la selección de un tipo de cultivo actualiza de forma automática e interactiva los deslizadores de límites de la interfaz a los rangos óptimos aconsejados, permitiendo que el usuario los refine manualmente antes de guardarlos.
* **Administración de Hardware en Caliente:** El componente de tarjeta de detalle reemplaza iconos estáticos por menús de acciones emergentes con opciones para editar y eliminar dispositivos. El flujo de edición activa un modo flexible que bloquea el campo de texto del identificador único UUID del dispositivo para resguardar la consistencia lógica con el hardware de Supabase, mientras que la acción de eliminación ejecuta un borrado secuencial seguro para limpiar umbrales y series analíticas previas, evitando romper restricciones de claves foráneas.

### Gestión de Modos Inmersivos y Respuestas de Estado
* **Persistencia Inmersiva en Android:** El sistema operativo Android acostumbra restaurar e imponer las barras de navegación nativas debido a interacciones de accesibilidad (como la apertura y cierre del teclado en campos de texto, la destrucción de rutas con navegación hacia atrás o el despliegue de cuadros de diálogo flotantes). Para subsanar esta reaparición sin degradar el rendimiento con ejecuciones redundantes dentro de los ciclos ordinarios de dibujo de la interfaz, se configuró un observador global del ciclo de vida de la aplicación que detecta cambios en las métricas de la ventana para reaplicar el ocultamiento del sistema de forma puramente reactiva.
* **Máquina de Estados de Mensajes de Salud:** Debajo del saludo personalizado del usuario en el panel principal se evalúa una lógica determinista en tiempo real para proyectar tres estados de salud visuales:
  1. Estado sin telemetría: Alerta al usuario en color rojo crítico indicando que existe un problema de obtención de datos.
  2. Estado de infracción: Advierte en color rojo crítico que un cultivo específico requiere atención inmediata debido a lecturas fuera de rango.
  3. Estado óptimo: Al recibir datos estables dentro de los umbrales ideales, el panel se actualiza automáticamente con un mensaje afirmativo en color verde saludable, proporcionando retroalimentación de tranquilidad inmediata al cultivador.

---

## 5. Seguridad (RLS), Autenticación y Semillado de Datos

### Flujo de Autenticación e Integración OAuth
* **Control de Acceso:** La pantalla de autenticación provee soporte nativo para inicios de sesión tradicionales a través de combinaciones de correo electrónico y contraseña, así como validación externa mediante Google Auth.
* **Persistencia de Sesión:** El punto de entrada principal de la aplicación verifica la existencia de sesiones previas al arrancar y se suscribe de manera asíncrona a los cambios de estado de autenticación globales para procesar de forma automatizada las redirecciones requeridas por los flujos OAuth.
* **Configuración de Proveedores (Google):** Requiere habilitar el proveedor en la consola de Supabase, vincular las credenciales de ID de cliente y clave secreta generadas en la sección de aplicaciones web de Google Cloud Console, y registrar los esquemas de redirección profunda e intercambio de enlaces en el archivo de manifiesto de Android para procesar los retornos de sesión hacia la aplicación de manera segura.

### Resolución de Conflictos de Integridad Referencial (SQL Seeding)
* **El Problema de Clave Foránea:** Si la base de datos en la nube no contiene registros cargados en el catálogo de plantas y un usuario intenta añadir un dispositivo móvil sirviéndose del catálogo local de emergencia de la aplicación, el motor de PostgreSQL frena e invalida la transacción devolviendo un error con código de violación de restricción 23503. Esto pasa porque la columna de relación de la tabla de dispositivos busca un identificador de planta idéntico en el servidor y, al no encontrarlo, bloquea la acción para defender la integridad de los datos.
* **Solución y Seguridad a Nivel de Filas:** Para garantizar el correcto funcionamiento del ecosistema se requiere ejecutar una inicialización en el editor SQL de Supabase encargada de:
  1. Forzar la obligatoriedad de los dueños de dispositivos en las tablas.
  2. Habilitar las políticas de seguridad a nivel de filas (Row Level Security o RLS) en todas las tablas operativas (plantas, dispositivos, umbrales y telemetría).
  3. Definir directrices de aislamiento donde las lecturas de plantas son públicas para usuarios autenticados, pero las tablas de hardware, umbrales y mediciones filtran estrictamente los accesos validando que el identificador del usuario firmado coincida exactamente con el propietario del registro o su dispositivo vinculado.
  4. Ejecutar una inyección de datos (Data Seeding) para poblar el catálogo del servidor con los registros de Espinaca y Lechuga empleando los mismos UUIDs fijos definidos en las plantillas de la aplicación Flutter, neutralizando de forma definitiva los errores de integridad de claves foráneas.

---

## 6. Solución a Errores de Compilación por Dependencias

### Ajustes en la API de Notificaciones Locales
* **Migración a Parámetros Nombrados:** A partir del lanzamiento de las versiones iguales o superiores a la versión 21.0.0 del ecosistema de notificaciones locales de Flutter (`flutter_local_notifications`), la interfaz de programación de la biblioteca eliminó por completo los argumentos posicionales antiguos en sus métodos de inicio y despliegue.
* **Impacto en el Código:** Todos los flujos internos de inicialización de configuraciones y llamadas para mostrar alertas visuales en el dispositivo móvil tuvieron que rediseñarse para invocar explícitamente las claves obligatorias correspondientes a configuraciones, identificadores, títulos, cuerpos y especificaciones de plataforma.

### Soporte para Java Moderno (Core Library Desugaring)
* **Origen del Fallo de Compilación:** Las versiones recientes del complemento de notificaciones emplean metodologías y APIs nativas de Java modernas (como las nuevas interfaces de tiempo y calendarios) que no están incorporadas de forma nativa en los entornos de ejecución tradicionales de terminales Android antiguos. Al compilar el proyecto en limpio, el sistema de empaquetado Gradle interrumpía la tarea arrojando un error de dependencia indicando que el módulo requería la habilitación del proceso de desconfiguración o desugaring de bibliotecas base.
* **Solución en la Configuración de Compilación:** El problema se solucionó modificando el archivo de automatización de compilación de la aplicación en Android escrito bajo la sintaxis del lenguaje de Kotlin DSL (`build.gradle.kts`). Las correcciones aplicadas fueron:
  1. Configurar las opciones de compilación nativas para asegurar la compatibilidad de origen y destino alineadas estrictamente al estándar de Java 17.
  2. Modificar las directivas lógicas activando explícitamente la bandera de habilitación de desconfiguración de bibliotecas base.
  3. Declarar e inyectar de forma explícita la dependencia externa de herramientas de desconfiguración de Java de Android dentro del bloque de dependencias del script de construcción.

---

## 7. Gestión de Repositorios Independientes Anidados (Git)

En proyectos con estructuras multi-módulo o hardware/software integrados, es común querer aislar un subdirectorio como un repositorio Git independiente del proyecto raíz sin recurrir a submódulos Git complejos.

### Mecanismo de Aislamiento
* **Ignorado en el Padre**: El repositorio principal (`GreenBox`) contiene la regla `/ESP32GreenBox` en su archivo `.gitignore`. Esto le dice al Git de la raíz que ignore por completo el directorio y todo su contenido, incluyendo su base de datos local de control de versiones `.git`.
* **Inicialización Autónoma**: Al ejecutar `git init` directamente dentro de la subcarpeta `ESP32GreenBox`, se crea un entorno de Git local completamente aislado. El repositorio padre no rastreará sus cambios ni su historial, permitiendo que esta carpeta sea empujada a un repositorio de GitHub diferente.

### Comandos de Configuración
1. Inicializar Git dentro de la subcarpeta:
   ```bash
   cd ESP32GreenBox
   git init
   ```
2. Agregar archivos, realizar el commit inicial y definir la rama por defecto:
   ```bash
   git add .
   git commit -m "Initial commit: Firmware ESP32"
   git branch -M main
   ```
3. Asociar con el nuevo repositorio de GitHub y subir los cambios:
   ```bash
   git remote add origin <URL_DEL_NUEVO_REPOSITORIO_EN_GITHUB>
   git push -u origin main
   ```

### Integración en VS Code
Para gestionar de forma gráfica el repositorio secundario desde la interfaz de VS Code sin que se mezcle visualmente con el repositorio principal:
* **Método 1: Abrir Carpeta Separada (Recomendado)**: Ir a `Archivo > Abrir carpeta...` y seleccionar únicamente la carpeta `/ESP32GreenBox`. VS Code detectará el repositorio `.git` interno automáticamente y aislará la interfaz de control de versiones.
* **Método 2: Espacio de Trabajo Multi-Carpeta**: Ir a `Archivo > Agregar carpeta al espacio de trabajo...` y seleccionar `/ESP32GreenBox`. Esto dividirá el panel de control de código fuente de VS Code en dos ramas gestionables de manera independiente.

---

## 8. Arquitectura Modular de Sensores (Bloques Dinámicos)

Para permitir que cada invernadero (módulo) pueda tener diferentes sensores instalados sin afectar la interfaz visual, se diseñó la siguiente estrategia de modularización de la interfaz y los datos:

### Nivel de Configuración
* **Alcance:** La configuración de qué sensores están activos se gestiona **a nivel de dispositivo (ESP32/Módulo)**. Todos los sensores físicos conectados a un ESP32 aplican a las plantas contenidas en ese módulo en particular.
* **Configuración Explícita:** La activación de sensores (pH, Humedad Ambiental, CE, Luz, Temperatura) se realiza de manera **manual** por el usuario en la app (ej. mediante checkboxes en la configuración del dispositivo). La base de datos guarda esta lista de `active_sensors` de manera explícita (probablemente como un array de strings en la tabla de dispositivos).

### Experiencia en el Dashboard (Home)
* **Visualización:** El Home renderiza un **Grid Dinámico de 3 columnas** respetando el diseño base y usando `wrap` para acomodar los bloques de forma flexible de acuerdo a cuántos sensores estén activos.
* **Falta de Datos (Cold Start):** Si un bloque de sensor es activado en la configuración pero aún no ha llegado ningún dato válido desde el ESP32 por WebSockets o HTTP, el bloque se muestra de todas formas pero exhibe un **estado de "Cargando", "Sin datos" o un ícono de advertencia**, dejando claro que la app está esperando la telemetría correspondiente.
* **Tipos Soportados MVP:** Por ahora se soporta una lista fija predefinida de parámetros (Humedad suelo, Humedad ambiente, Temperatura, pH, CE, Luz). No se requiere por el momento creación de tipos de sensores personalizados por el usuario.

---

## 9. Integración de Sensor de Temperatura y Humedad (AM2302 / DHT22) y Mapeo en App

### Integración en Firmware ESP32
* **Hardware y Bus Digital:** Se migró de una lectura analógica simple a la lectura digital del sensor de temperatura y humedad ambiental **AJ-AM2302 (DHT22)** conectado al pin digital `GPIO 4` del ESP32.
* **Librerías:** Integración de `adafruit/DHT sensor library` y `adafruit/Adafruit Unified Sensor` en `platformio.ini`.
* **Estructura Broadcast Supabase Realtime:** El payload JSON transmitido mediante WebSockets se expandió para incluir de forma simultánea los campos `"humidity"` y `"temperature"`.

### Parseo y Flujo de Datos en Flutter
* **Recepción en `watchSensorReadings`:** Se actualizó la clase `SupabaseGreenBoxRepository` para parsear explícitamente los tokens de `temperature` (`temperatura`/`temp`) y `luz` (`light`/`lux`) provenientes de la transmisión Realtime. Anteriormente solo se mapeaban `humedad`, `ph` y `ce`, lo que causaba que la interfaz ignorara las lecturas de temperatura recibidas por WebSockets.
* **Mapeo de Filtros de Gráficas (`DashboardScreen`):** Se adaptó la lógica de interacción de las pestañas (`SensorFilterTabs`) para que al seleccionar la pestaña `'Temp'` se consulte el nombre de columna de base de datos correcto (`'temperature'`), asegurando la renderización fluida tanto de métricas en vivo como de series temporales.
* **Selección de Dispositivo/Emulador en Flutter (`flutter run -d`):** Cuando existen múltiples destinos disponibles (Windows, Chrome, Emuladores), `-d android` no es un identificador válido si el emulador tiene un ID específico (por ejemplo `emulator-5554`). Se debe usar `flutter run -d emulator-5554` o el nombre completo del dispositivo listado en `flutter devices`.
* **Cierre Inesperado por LowMemoryKiller (LMK) en Emuladores:** Al iniciar el flujo de autenticación OAuth (Supabase con Google), la aplicación pasa a segundo plano para abrir Google Chrome o Custom Tabs. Si el emulador tiene poca memoria RAM configurada o está bajo alta presión de recursos, el kernel de Android (`lowmemorykiller`) mata el proceso de la aplicación (`oom_score_adj`) para liberar memoria para el navegador. Esto provoca en Flutter el mensaje `Lost connection to device`. Solución técnica: Aumentar la memoria RAM del AVD en Android Studio (de 1.5GB a 3GB o 4GB en *Show Advanced Settings -> RAM*) o reiniciar el emulador con *Cold Boot*.

---

## 10. Estudio de Huella Hídrica Azul (Sensor de Presión Hidrostática)

### Concepto
* **Huella hídrica azul:** Volumen de agua dulce consumida por el cultivo dividido por la masa cosechada. Se expresa en L/kg (numéricamente igual a m³/t).
* **Medición del agua:** El agua de riego se almacena en un recipiente rectangular. Un sensor de presión hidrostática sumergido mide la presión de la columna de agua, y la app la convierte a altura y volumen.

### Fórmulas (`lib/domain/services/water_footprint_calculator.dart`)
* Altura: `h = P / (ρ·g)`, con ρ = 1000 kg/m³ y g = 9.81 m/s² → 1 kPa ≈ 10.19 cm de agua.
* Volumen: `V (L) = ancho (cm) · largo (cm) · h (cm) / 1000`.
* Volumen máximo del recipiente: `ancho · largo · altura / 1000`.
* Nivel %: el volumen de la **primera lectura** del estudio se toma como el 100 %.
* Consumo total: suma de los descensos entre recargas: `(V_inicial − V_antes₁) + (V_después₁ − V_antes₂) + … + (V_despuésₙ − V_final)`.
* Huella hídrica azul: `consumo (L) / peso cosechado (kg)`.

### Payload del ESP32
El firmware envía la presión en **kPa** con la llave `pressure` dentro del broadcast Realtime existente (eventos `telemetry` o `sensor_reading` en el canal `device:<uuid>`), ej. `{"pressure": 1.47, "humidity": 65}`. La app también acepta `presion` y `water_pressure`, y la expone como el sensor `presion`.

### Rendimiento
* La presión en vivo llega a la pestaña mediante un `ValueNotifier` del dashboard: solo la parte de la tarjeta que la muestra se reconstruye en cada lectura, no todo el dashboard.
* El dashboard solo llama a `setState` cuando cambia un valor visible (`mapEquals`), y la presión solo entra al mapa de sensores si su tile está activo.
* Las consultas independientes a Supabase se lanzan en paralelo (`Future.wait`), y el recipiente 3D y la gráfica van en `RepaintBoundary`.

### Flujo en la App (pestaña de la gota en la barra inferior)
La pantalla sigue el diseño: estado del cultivo arriba, pestañas de análisis, título "HUELLA HIDRICA (WFN)" y una tarjeta oscura con el recipiente 3D (tocar para editar medidas), el agua consumida, el confort del invernadero, la fiabilidad del cálculo y los botones Emular / Cosechar (Iniciar si no hay estudio).

1. **Recipiente:** se configuran ancho, largo y altura (cm); se muestra el volumen máximo.
2. **Nivel en vivo:** presión, altura, volumen y porcentaje respecto al nivel inicial.
3. **Tomar primera lectura (100 %):** pide el nivel de agua inicial en cm. Se rellena con el sensor si hay lectura (botón SENSOR), pero se puede escribir a mano, así el estudio funciona sin sensor.
4. **Registrar recarga:** diálogo de dos pasos (capturar antes → rellenar → capturar después). Los litros se pueden capturar del sensor o escribir a mano.
5. **Simulador:** disponible siempre, haya o no estudio en curso o sensor. Todo es editable: nivel inicial y final (cm), agua recargada (L), número de plantas y peso por planta (deslizador o gramos exactos; referencia: lechuga 300 g, espinaca 150 g). Muestra en vivo el volumen, el consumo `V_inicial − V_final + recargado` y la huella. No guarda nada; recuerda los valores para la siguiente apertura y para el cierre.
6. **Finalizar cosecha:** popup de confirmación con cuenta regresiva de 3 s, donde se ingresan el nivel final de agua (del sensor o a mano), el número de plantas y el peso real. Cierra el estudio y guarda el resultado en el historial.

### Migración SQL
Ya aplicada en el proyecto `cflrnbpwcznnimiijluk` como migración `water_footprint_study`. La versión aplicada usa columnas `double precision` (igual que el resto del esquema), índices en las claves foráneas y políticas `to authenticated` con `(select auth.uid())`. El SQL de referencia:
```sql
alter table devices
  add column if not exists tank_width_cm numeric,
  add column if not exists tank_length_cm numeric,
  add column if not exists tank_height_cm numeric;

-- Opcional: peso de referencia por planta para el simulador
alter table plants add column if not exists typical_harvest_weight_kg numeric;
update plants set typical_harvest_weight_kg = 0.15 where id = '11111111-1111-4111-a111-111111111111';
update plants set typical_harvest_weight_kg = 0.30 where id = '22222222-2222-4222-a222-222222222222';

create table if not exists water_footprint_studies (
  id uuid primary key default gen_random_uuid(),
  device_id uuid not null references devices(id) on delete cascade,
  plant_id uuid references plants(id),
  status text not null default 'active' check (status in ('active', 'finished')),
  started_at timestamptz not null default now(),
  finished_at timestamptz,
  initial_pressure_kpa numeric not null,
  initial_volume_l numeric not null,
  final_pressure_kpa numeric,
  final_volume_l numeric,
  total_consumption_l numeric,
  plant_count int,
  harvest_weight_kg numeric,
  water_footprint_l_per_kg numeric
);

create table if not exists water_refills (
  id uuid primary key default gen_random_uuid(),
  study_id uuid not null references water_footprint_studies(id) on delete cascade,
  created_at timestamptz not null default now(),
  volume_before_l numeric not null,
  volume_after_l numeric not null
);

alter table water_footprint_studies enable row level security;
alter table water_refills enable row level security;

create policy "Studies of own devices" on water_footprint_studies
  for all using (
    exists (select 1 from devices d where d.id = device_id and d.owner_id = auth.uid())
  ) with check (
    exists (select 1 from devices d where d.id = device_id and d.owner_id = auth.uid())
  );

create policy "Refills of own studies" on water_refills
  for all using (
    exists (
      select 1 from water_footprint_studies s join devices d on d.id = s.device_id
      where s.id = study_id and d.owner_id = auth.uid()
    )
  ) with check (
    exists (
      select 1 from water_footprint_studies s join devices d on d.id = s.device_id
      where s.id = study_id and d.owner_id = auth.uid()
    )
  );
```