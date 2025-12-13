Diseña un sistema modular en Bash compuesto por pequeños scripts especializados que trabajen en conjunto para manejar entradas no reconocidas en la terminal de Linux. El flujo debe ser el siguiente:

1. **Entrada del usuario**: El usuario escribe cualquier cadena en la terminal que no es un comando válido (ej: "dime como ver solo directorios", "lss", "haz un directorio prueba", "chmot").

2. **Clasificación inicial**:
   - Un script llamado `command_not_found_handler` (compatible con Bash y Zsh) captura la entrada.
   - Usa IA (preferentemente Ollama local, con fallback a Mistral API si está disponible) para analizar la cadena y clasificarla **exclusivamente** como:
     - `"prompt"` → si la entrada es una solicitud en lenguaje natural (como una instrucción o pregunta).
     - `"comando"` → si la entrada parece un comando mal escrito o con errores tipográficos.
   - **Reglas estrictas**:
     - La IA **solo debe devolver una de las dos palabras**: `prompt` o `comando`.
     - Nada más: sin explicaciones, sin puntuación, sin espacios extra.

3. **Ruta de ejecución**:
   - Si la salida es `"comando"` → ejecuta el script `correccion_de_comando`.
   - Si la salida es `"prompt"` → ejecuta el script `analisis_prompt`.

4. **Script `correccion_de_comando`**:
   - Recibe la cadena original.
   - Usa IA para corregir el comando (ej: "lss" → "ls", "chmot" → "chmod").
   - Muestra la corrección al usuario y pregunta: "¿Ejecutar? [s/N]".
   - Si el usuario confirma, **ejecuta directamente el comando corregido** (sin intermediarios ni copia manual).
   - Si no hay sugerencia válida, muestra "No se encontró corrección" y termina.

5. **Script `analisis_prompt`**:
   - Recibe el prompt en lenguaje natural.
   - Usa IA para clasificarlo **exclusivamente** como:
     - `"info"` → si el usuario busca información (ej: "¿cómo listar solo directorios?").
     - `"tarea"` → si el usuario pide realizar una acción (ej: "crea un archivo con Hola").
   - **Reglas estrictas**:
     - Solo devuelve `info` o `tarea`, sin nada más.

6. **Segunda bifurcación**:
   - Si la salida es `"info"` → ejecuta el script `info`.
   - Si la salida es `"tarea"` → ejecuta el script `cadena`.

7. **Script `info`**:
   - Usa IA para generar **solo el comando exacto** que responde a la consulta (como tu script `dime`).
   - Muestra el comando en verde y **no lo ejecuta**.
   - Ejemplo: entrada → "cómo ver solo directorios", salida → `ls -d */`

8. **Script `cadena`**:
   - Analiza el prompt para determinar si es una **tarea simple** o **compleja**.
   - **Tarea simple**: una única acción atómica (ej: crear archivo, listar, cambiar permisos).
   - **Tarea compleja**: múltiples pasos secuenciales o dependientes (ej: crear estructura de proyecto web).
   - Clasificación: IA debe devolver **solo** `simple` o `complejo`.

9. **Ejecución final**:
   - Si es `simple` → ejecuta `tarea_simple`:
     - Genera un único comando seguro (siguiendo las mismas reglas de seguridad que el script `haz` original).
     - Valida contra comandos peligrosos.
     - Ejecuta con confirmación si requiere `sudo`.
     - Registra todo en un archivo `.md` con salida y resultado.
   - Si es `complejo` → ejecuta `tarea_compleja`:
     - Genera un archivo Markdown con:
       - Petición original.
       - Interpretación de la IA.
       - Preguntas de aclaración (si aplica).
       - Lista numerada de pasos propuestos.
     - Abre el archivo con `nvim` para que el usuario lo revise, responda preguntas y modifique los pasos.
     - Tras cerrar `nvim`, el script **relee el archivo**, extrae los pasos finales y los ejecuta **uno por uno**, con validación de seguridad en cada paso.
     - Cada paso se registra en el mismo archivo con su salida y estado.

**Requisitos de seguridad y diseño**:
- Todos los scripts deben verificar dependencias (`curl`, `jq`).
- Nunca ejecutar comandos con `$(...)`, backticks, variables de entorno (`$HOME`), ni redirecciones peligrosas.
- Bloquear patrones destructivos (como en `haz`: `rm -rf /`, `dd`, etc.).
- Usar rutas relativas cuando sea posible.
- Preferir Ollama local (`http://localhost:11434`) como backend principal; Mistral API como fallback opcional (solo si `MISTRAL_API_KEY` está definida).
- Todos los prompts a la IA deben ser ultra-estrictos: **solo la palabra o comando solicitado, nada más**.
- Los scripts deben ser idempotentes, legibles y fáciles de auditar.

**Entrega esperada**:
- Una descripción clara de cada script (`command_not_found_handler`, `correccion_de_comando`, `analisis_prompt`, `info`, `cadena`, `tarea_simple`, `tarea_compleja`).
- El contenido exacto de cada script en Bash, listo para usar.
- Instrucciones de instalación (dónde colocarlos, cómo integrar con `.bashrc`/`.zshrc`).
- Ejemplos de flujo completo para: "lss", "dime cómo listar directorios", "haz un dir prueba", "crea un proyecto web con html/css/js".

**Importante**: No generes un solo script gigante. Prioriza la modularidad, la seguridad y la claridad.
