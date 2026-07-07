# GreenBox Producción

Este documento es la fuente de verdad operativa para el desarrollo del proyecto **GreenBox**. Sirve como memoria técnica y estratégica para el agente IA y el equipo de desarrollo pero tambien tu rol como mi asistente de este proyecto.

## Tu rol como asistente
Mientras desarrollamos este proyecto yo debo de alcanzar a conocer terminos para poder trabajar mejor y hacer mejores promts:
1) Conoce la arquitectura, palabras tecnicas, forma de desarrollo que estas teniendo etc.
2) Cada cierto tiempo debes actualizar un documento llamado  `Conocimiento.md` con todo lo nuevo que aprendi, este archivo debes de crearlo o modificarlo cada vez que sea necesario y avisame cada vez que lo crees o modifiques.

## Estatus Actual (Presente)
*Fase: Desarrollo de MVP*
- **Frontend:** Flutter (Mobile App).
- **Backend:** Supabase (PostgreSQL + Realtime).
- **Microcontrolador:** ESP32
- **Comunicación Hardware -> Backend:** HTTPS REST API (ESP32).
- **Infraestructura de Datos:**
  - Tabla `devices` para gestión de hardware.
  - Tabla `sensor_data` con filtrado en el borde (Edge Filtering).
  - Estrategia: 1 lectura por segundo en ESP32 (WebSockets sin llenar BD) -> Envío de promedios diarios + Reporte inmediato de excepciones (thresholds).

---

## Planes de Escalamiento (Futuro)
*Objetivo: Nivel Internacional / Corporativo*

- **Protocolo IoT:** Migración de HTTPS a **MQTT** para mayor eficiencia y menor consumo.
- **Ingesta Masiva:** Uso de un Broker MQTT (AWS IoT Core o EMQX).
- **Base de Datos de Series Temporales:** Implementación completa de **TimescaleDB** dentro de Supabase o **InfluxDB** para analítica avanzada de años de datos.
- **Automatización:** Implementación de actuadores (riego automático, control de pH automático) basados en reglas de IA.
- **Seguridad:** Certificados SSL individuales por cada dispositivo físico.

---

## Vertientes y Exploración (Backlog Creativo)
*Ideas no definidas pero con potencial*

- **GreenBox Community:** Red social de cultivadores para compartir "recetas de cultivo" (configuraciones de pH/CE para plantas específicas).
- **Marketplace Orgánico:** Conectar excedentes de producción de GreenBoxes locales con consumidores cercanos (economía circular).
- **IA Predictiva:** Modelos que predigan enfermedades en las plantas antes de que los sensores detecten cambios críticos, basándose en patrones históricos.
- **Gamificación:** Sistema de logros por eficiencia energética o calidad de cosecha.

---

## Directivas para la IA (Instrucciones de Agente)
1. **Sincronización:** Cada vez que se modifique este archivo, se debe intentar replicar la lógica en el archivo de configuración del proyecto real (si el acceso está habilitado).
2. **Prioridad:** Siempre validar cualquier cambio contra la meta de mantener el proyecto dentro de los límites del plan gratuito de Supabase durante la fase MVP.
3. **Estilo:** Mantener un lenguaje técnico pero orientado a la acción.

---

## Historial de Cambios
- **2026-05-09:** Creación del documento inicial y definición de la arquitectura Supabase + Flutter.
