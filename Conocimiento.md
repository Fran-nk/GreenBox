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