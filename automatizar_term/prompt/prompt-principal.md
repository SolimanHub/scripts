tengo este script llamado `haz`
```bash
#!/bin/bash

# Función para generar nombre de archivo con timestamp
generar_nombre_archivo_md() {
    fecha_hora=$(date +"%Y-%m-%d_%H-%M-%S")
    echo "haz_command_${fecha_hora}.md"
}

# Función para validar comandos peligrosos
es_comando_seguro() {
    local cmd="$1"
    # Lista de patrones peligrosos
    local peligrosos=(
        "rm -rf /"
        "rm -rf ~"
        "dd if="
        "mkfs"
        "fdisk"
        "parted"
        ":(){ :|:& };:"
        "shutdown -h now"
        "reboot"
        "mv / /dev/null"
        "chmod -R 777 /"
        "chown -R root:root /"
        "> /dev/sda"
        "dd of=/dev/sda"
    )
    
    for peligro in "${peligrosos[@]}"; do
        if [[ "$cmd" == *"$peligro"* ]]; then
            return 1
        fi
    done
    return 0
}

# Verificar dependencias
if ! command -v curl >/dev/null || ! command -v jq >/dev/null; then
    echo -e "\033[31mError: Necesitas tener instalados curl y jq\033[0m"
    exit 1
fi

if [ "$#" -lt 1 ]; then
    echo -e "\033[31mUso: haz <consulta>\033[0m"
    exit 1
fi

# Construir el prompt ultra-seguro
query="$*"
my_system=$(hostnamectl | grep -E "Operating System|Kernel|Architecture" | head -n 3)

prompt="Eres un asistente técnico especializado en Arch Linux. Tu tarea es generar **exactamente un solo comando de terminal válido y seguro** que cumpla con la solicitud del usuario.

REGLAS ABSOLUTAS:
1. **NUNCA** añadas explicaciones, comentarios, notas ni texto adicional.
2. **SOLO** devuelve el comando puro, en una sola línea.
3. **PROHIBIDO** usar:
   - \$(...) o acentos graves (backticks)
   - variables como \$HOME, \$USER, etc.
   - comillas dobles que contengan \$ o comandos
   - texto explicativo dentro del comando
4. Si necesitas mostrar información del sistema (fecha, hora, etc.), usa directamente el comando que la genera (ej: 'date', 'ls', 'pwd').
5. Para escribir contenido estático en un archivo, usa: echo 'contenido' > archivo  (con comillas simples)
   - Si hay saltos de línea, usa: echo -e 'línea1\\nlínea2' > archivo
   - Escapa comillas simples como '\''
6. Usa rutas relativas (como xxx) si el archivo está en el directorio actual.
7. Usa **sudo solo si es estrictamente necesario**.
8. Si la solicitud es ambigua o peligrosa, responde: ERROR: solicitud no segura

Contexto del sistema:
$my_system

Ejemplos CORRECTOS:
- Usuario: 'dime la fecha' → date
- Usuario: 'muestra la hora' → date +%H:%M
- Usuario: 'fecha de ayer' → date -d \"yesterday\"
- Usuario: 'crea saludo.txt con Hola' → echo 'Hola' > saludo.txt
- Usuario: 'crea index.html con HTML básico' → echo -e '<!DOCTYPE html>\\n<html lang=\"es\">\\n<head>\\n<meta charset=\"UTF-8\">\\n<title>Página</title>\\n</head>\\n<body>\\n<h1>Hola</h1>\\n</body>\\n</html>' > index.html

Ahora, responde **solo con el comando exacto** para esta solicitud en Arch Linux:
haz $query"

# Función para usar Ollama local
usar_ollama() {
    archivo_md=$(generar_nombre_archivo_md)
    modelo="mistral:7b-instruct-v0.3-q4_K_M"
    url="http://localhost:11434/api/generate"
    
    # Obtener comando de Ollama
    payload=$(jq -n \
        --arg model "$modelo" \
        --arg prompt "$prompt" \
        '{model: $model, prompt: $prompt, stream: false}')
    
    local respuesta=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -d "$payload" "$url")
    
    [ $? -ne 0 ] && return 1
    
    local comando=$(echo "$respuesta" | jq -r '.response')
    [ -z "$comando" ] || [ "$comando" = "null" ] && return 1

    # Limpiar la respuesta: quitar saltos de línea innecesarios al inicio/final, comillas sueltas
    comando=$(echo "$comando" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

    # Manejar errores del modelo
    if [[ "$comando" == ERROR:* ]]; then
        echo -e "\033[31m✖ $comando\033[0m"
        echo -e "# Registro de comando - $(date +"%Y-%m-%d_%H-%M-%S")\n" > "$archivo_md"
        echo -e "**Prompt del usuario:**\n\`\`\`\n${query}\n\`\`\`\n" >> "$archivo_md"
        echo -e "**Error del modelo:** $comando" >> "$archivo_md"
        return 1
    fi

    # 🔒 Validación extra: bloquear expansión de subcomandos
    if [[ "$comando" == *'$('* ]] || [[ "$comando" == *'`'* ]]; then
        echo -e "\033[31m✖ Comando rechazado: contiene expansión de subcomandos (\$() o backticks)\033[0m"
        echo -e "# Registro de comando - $(date +"%Y-%m-%d_%H-%M-%S")\n" > "$archivo_md"
        echo -e "**Prompt del usuario:**\n\`\`\`\n${query}\n\`\`\`\n" >> "$archivo_md"
        echo -e "**Comando rechazado:** $comando" >> "$archivo_md"
        return 1
    fi

    # Validar seguridad (comandos destructivos)
    if ! es_comando_seguro "$comando"; then
        echo -e "\033[31m✖ Comando bloqueado por seguridad: contiene operaciones peligrosas\033[0m"
        echo -e "# Registro de comando - $(date +"%Y-%m-%d_%H-%M-%S")\n" > "$archivo_md"
        echo -e "**Prompt del usuario:**\n\`\`\`\n${query}\n\`\`\`\n" >> "$archivo_md"
        echo -e "**Comando rechazado por seguridad:** $comando" >> "$archivo_md"
        return 1
    fi

    # Crear archivo markdown
    echo -e "# Registro de comando - $(date +"%Y-%m-%d_%H-%M-%S")\n" > "$archivo_md"
    echo -e "**Prompt del usuario:**\n\`\`\`\n${query}\n\`\`\`\n" >> "$archivo_md"
    echo -e "## Comando generado\n\`\`\`bash\n${comando}\n\`\`\`\n" >> "$archivo_md"
    echo -e "## Salida del comando\n\`\`\`text\n" >> "$archivo_md"

    # Función para ejecutar con verificación de permisos
    ejecutar_comando() {
        local cmd="$1"
        local necesita_sudo=0
        local initial_size=$(stat -c %s "$archivo_md")
        
        echo -e "\033[36m== Iniciando ejecución =="
        eval "$cmd" 2>&1 | tee -a "$archivo_md"
        local exit_code=${PIPESTATUS[0]}
        
        if [ $exit_code -ne 0 ]; then
            if grep -qi \
                -e "error: you cannot perform this operation unless you are root" \
                -e "permission denied" \
                -e "operation not permitted" \
                -e "EACCES" \
                -e "EPERM" \
                "$archivo_md"; then
                necesita_sudo=1
            fi
        fi

        if [ $necesita_sudo -eq 1 ]; then
            echo -en "\033[33m\n⚠ El comando requiere permisos de administrador. ¿Ejecutar con sudo? [s/N] \033[0m"
            read -r respuesta
            if [[ "$respuesta" =~ ^[Ss](i)?$ ]]; then
                echo -e "\n\033[34mIngresa tu contraseña de sudo:\033[0m"
                if ! sudo -v; then
                    echo -e "\033[31m✖ Autenticación fallida\033[0m"
                    return 1
                fi
                echo -e "\033[36m== Reejecutando con privilegios elevados =="
                eval "sudo $cmd" 2>&1 | sudo tee -a "$archivo_md" >/dev/null
                exit_code=${PIPESTATUS[0]}
            else
                echo -e "\033[33m✖ Comando cancelado\033[0m"
                return 1
            fi
        fi

        local new_size=$(stat -c %s "$archivo_md")
        [ "$new_size" -gt "$initial_size" ] && return 2
        return $exit_code
    }

    echo -e "\033[32mComando generado: $comando\033[0m"
    ejecutar_comando "$comando"
    local resultado_ejecucion=$?
    
    echo -e "\n\`\`\`" >> "$archivo_md"

    if [ $resultado_ejecucion -eq 0 ]; then
        echo -e "\033[32m✔ Comando ejecutado exitosamente\033[0m"
    elif [ $resultado_ejecucion -eq 2 ]; then
        echo -e "\033[32m✔ Comando ejecutado con salida\033[0m"
    else
        echo -e "\033[31m✖ Error al ejecutar el comando (Código: $resultado_ejecucion)\033[0m"
    fi

    if [ $resultado_ejecucion -eq 2 ] || [ $resultado_ejecucion -ne 0 ]; then
        echo -en "\033[36m¿Deseas analizar los resultados? [s/N] \033[0m"
        read -r analizar
        if [[ "$analizar" =~ ^[SsYy](i|es)?$ ]]; then
            echo -e "\033[36mAnalizando resultados..."
            contenido_salida=$(awk '/^```text$/,/^```$/{if (!/^```/ && !/^##/ && !/^#/) print}' "$archivo_md" | head -n -1)
            
            prompt_explicacion="Explica brevemente EN ESPAÑOL (3 líneas máximo) qué ocurrió al ejecutar el comando '$comando' en Arch Linux. Salida del comando: \"\"\"$contenido_salida\"\"\""
            
            payload_explicacion=$(jq -n \
                --arg model "$modelo" \
                --arg prompt "$prompt_explicacion" \
                '{model: $model, prompt: $prompt, stream: false}')
            
            local explicacion=$(curl -s -X POST \
                -H "Content-Type: application/json" \
                -d "$payload_explicacion" "$url" | jq -r '.response')
            
            echo -e "\n## Análisis de resultados\n${explicacion}" >> "$archivo_md"
            echo -e "\033[37mExplicación:\n$explicacion\033[0m"
        else
            echo -e "\033[33mAnálisis cancelado por el usuario\033[0m"
        fi
    else
        echo -e "\033[33mEl comando no generó salida para analizar\033[0m"
    fi

    return 0
}

# Lógica principal
if usar_ollama; then
    exit 0
else
    echo -e "\033[31mError: No se pudo conectar al servicio local de Ollama\033[0m"
    exit 1
fi
```
que al ejecutar el comando haz seguido de un prompt, le doy la orden a la pc de ejecutar ciertas tareas usando ia.
por ejemplo:
- haz un directorio llamado prueba
- haz un fichero dentro de prueba
- haz dime el contenido de este fichero

por otro lado, tambien tengo este script llamado `command_not_found_handler`
el cual lo utilizo para que en lugar de que la terminal me arroje un error al meter mal un comando, se ejecute este script que tambien usa IA para ayudar sugiriendo cual es el comando correcto.
```bash
#!/bin/bash

# Para que este script funcione en zshrc su nombre debe ser: command_not_found_handler
# Para que este script funcione en bashrc su nombre debe ser: command_not_found_handle
#
# Editar zshrc
# command_not_found_handler() {
#    "$HOME/Cocina/scripts/funciones_bashrc/command_not_found_handler" "$@"
# }
# source ~/.zshrc
#
# Códigos de color heredados
COLOR_ERROR="\033[31m"
COLOR_EXITO="\033[32m"
COLOR_INFO="\033[33m"
COLOR_RESET="\033[0m"

funcion() {
    # Verificar dependencias
    if ! command -v curl >/dev/null 2>&1; then
        echo -e "${COLOR_ERROR}Error: curl no está instalado. Por favor instálalo para continuar.${COLOR_RESET}"
        return 127
    fi
    if ! command -v jq >/dev/null 2>&1; then
        echo -e "${COLOR_ERROR}Error: jq no está instalado. Por favor instálalo para continuar.${COLOR_RESET}"
        return 127
    fi

    # Capturar el comando ingresado
    local full_command="$*"
    local modelo_ollama="mistral:7b-instruct-v0.3-q4_K_M"
    local modelo_mistral="mistral-small-latest"
    
    echo -e "\n${COLOR_ERROR}Error: El comando \"$full_command\" no se ha encontrado.${COLOR_RESET}"

    # Preguntar al usuario si desea usar IA
    echo -en "${COLOR_INFO}¿Desea usar IA para buscar la solución? (S/n): ${COLOR_RESET}"
read -ei "S" use_ai
    if [[ "${use_ai^^}" != "S" ]]; then
        return 127
    fi

    # Solicitar detalles adicionales
    echo -en "${COLOR_INFO}Agregue detalles de qué deseaba hacer con su comando: ${COLOR_RESET}"
read -r details

    # Construir el prompt
    local prompt="Analiza el siguiente comando de la terminal de Linux ‘$full_command‘ y teniendo en cuenta que el usuario deseaba: '$details'. Responde estrictamente de la siguiente manera: "
    prompt+="Si el comando contiene errores de ortografía o sintaxis, corrígelo y responde únicamente con la versión corregida. "
    prompt+="Si el comando está escrito correctamente, respóndelo exactamente igual. "
    prompt+="Si el comando es correcto pero no existe, responde únicamente con: no_suggestions. "
    prompt+="La respuesta debe ser lo más breve posible, sin detalles ni palabrería, solo el comando resultante. "
    prompt+="No incluyas explicaciones, detalles, comentarios ni ningún otro texto adicional."

    consultar_mistral() {
        [ -z "$MISTRAL_API_KEY" ] && return 1
        
        local payload=$(jq -n \
            --arg prompt "$prompt" \
            '{
                "model": "mistral-small-latest",
                "messages": [
                    {"role": "user", "content": $prompt}
                ],
                "temperature": 0.3
            }')

        local respuesta=$(curl -s -X POST "https://api.mistral.ai/v1/chat/completions " \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer $MISTRAL_API_KEY" \
            -d "$payload")

        if [ $? -ne 0 ]; then
            return 1
        fi

        local analisis=$(echo "$respuesta" | jq -r '.choices[0].message.content')
        [ -z "$analisis" ] || [ "$analisis" = "null" ] && return 1

        echo "$analisis"
    }

    consultar_ollama() {
        local payload=$(jq -n \
            --arg model "$modelo_ollama" \
            --arg prompt "$prompt" \
            '{model: $model, prompt: $prompt, stream: false}')

        local respuesta=$(curl -s -X POST "http://localhost:11434/api/generate" \
            -H "Content-Type: application/json" \
            -d "$payload")

        if [ $? -ne 0 ]; then
            return 1
        fi

        local analisis=$(echo "$respuesta" | jq -r '.response')
        [ -z "$analisis" ] || [ "$analisis" = "null" ] && return 1

        echo "$analisis"
    }

    # Intentar primero con Mistral
    echo -e "${COLOR_INFO}Consultando a Mistral API...${COLOR_RESET}"
    local response=$(consultar_mistral)
    local status=$?

    if [ $status -ne 0 ]; then
        echo -e "${COLOR_INFO}Fallando a Ollama local...${COLOR_RESET}"
        response=$(consultar_ollama)
        status=$?
    fi

    # Manejar respuesta
    if [ $status -ne 0 ] || [ -z "$response" ]; then
        echo -e "${COLOR_ERROR}Error: No se pudo obtener respuesta de los servicios de IA${COLOR_RESET}"
        return 127
    fi

    if [[ "$response" == *"no_suggestions"* ]]; then
        echo -e "${COLOR_ERROR}No se encontraron sugerencias.${COLOR_RESET}"
        return 127
    fi

    # Mostrar resultado
    echo -e "\n${COLOR_EXITO}Sugerencia:${COLOR_RESET} $response"
}

funcion "$@"
```

los dos script me gustan mucho y me son de gran utilidad, pero me gustaria fucionar su funcionalidad.
y para ello, no quiero que el resultado sea un solo script gigante.
sino un conjunto de peque;os script que hagan una sola tarea, pero que funcionen en conjunto de la siguiente manera:

- el usuario ingresa una cadena de letras y/o simbolos en la terminal (dicha cadena no es un comando reconocido por el sistema)
- se debe ejecutar el script `command_not_found_handler` pero ahora este script analizara con IA la cadena ingresada por el usuario y determinara si dicha cadena es un prompt o un comando mal escrito.
por ejemplo:
si el usuario ingresa:
+ dime como modificar los permisos de tal directorio (el sistema determinara que esto es un prompt)
+ lss ( el sistema determinara que esto es un comando mal escrito)
+ haz un directorio llamado prueba (el sistema determinara que esto es un prompt)
+ chmot (comando mal escrito)

- si el sistema determina que es un comando o un prompt, la saldida debe ser especificamente la cadena `comando` o `prompt` respectivamente, sin explicaciones, sin adornos, sin ningun tipo de parafernalia extra, solo la palabra `comando` o la palabra `prompt` segun sea el caso.

- luego de determinar de que se trata la cadena que el usuario ingreso, se deben ejecutar otro script
para ello `command_not_found_handler` tendra un if al final del proceso en el cual si la salida de la ia es prompt, se ejecutara el script llamado `analisis_prompt` y si la salida es la palabra `comando` se ejecutara el script llamado `correccion_de_comando`

-el script llamado `correccion_de_comando` analizara la cadena ingresada por el usuario, determinara cual es el error en dicho comando y le mostrara la correccion al usuario junto con la pregunta si desea ejecutar el comando, para que en caso de que muestre el comando correcto que el usuario deseaba no lo tenga que copiar/pegar ni reescribir. el comando se ejecutara automaticamente luego de que el usuario diga que si lo quiere ejecutar.

- el script llamado `analisis_prompt` analizara el prompt ingresada por el usuario, determinara el tipo de peticion realizada por el usuario, si el usuario esta pidiendo informacion puntual o si el usuario esta pidiendo que realice alguna tarea, en caso que el usuario solicite informacion la salida de la ia debe ser la palabra `info` si lo que el usuario solicita es una tarea la salida debe ser la palabra `tarea`.
ejemplo:
si el usuario ingresa:
+ dime como como ver solo los directorios usando ls (la respuesta de la ia debe ser la cadena `info`)
+ cual es el comando para buscar solo ficheros (info)
+ que dia fue el 20 de enero del 2020 (info)
+ haz un directorio llamado expo (la respuesta de la ia debe ser la cadena `tarea`)
+ inserta en el fichero index.html la estructura basica de una pagina web (tarea)
+ elimina este archivo (tarea)

- en este punto al igual que en el primer script habra un if que ejecute dos tareas diferentes, si la salida es la cadena info, se debe ejecutar el script llamado `info` caso contrario se debe ejecutar el script llamado `cadena`

tengo este otro script para solicitar informacion directamente desde terminal que puedes usar como referencia cuando el usuario solicite un comando.

```bash
#!/bin/bash
# ~/.local/bin/dime

# Verificar dependencias
if ! command -v curl >/dev/null || ! command -v jq >/dev/null; then
    echo -e "\033[31mError: Necesitas tener instalados curl y jq\033[0m"
    exit 1
fi

if [ "$#" -lt 1 ]; then
    echo -e "\033[31mUso: dime <consulta>\033[0m"
    exit 1
fi

# Construir el prompt
query="$*"
prompt="Responde solo con el comando exacto en archlinux, sin texto adicional, explicaciones ni formato extra. Si agregas algo más, la respuesta será inválida. Ejemplo correcto: ls Ejemplo incorrecto: 'El comando es: ls' ❌ Ahora, dame solo el comando para: $query"

# Función para probar Mistral
usar_mistral() {
    [ -z "$MISTRAL_API_KEY" ] && return 1
    
    local respuesta=$(curl --silent --show-error --max-time 10 -X POST "https://api.mistral.ai/v1/chat/completions" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $MISTRAL_API_KEY" \
        -d '{
            "model": "mistral-small-latest",
            "messages": [{"role": "user", "content": "'"$prompt"'"}],
            "temperature": 0.3
        }')
    
    if [ $? -ne 0 ]; then
        return 1
    fi
    
    local comando=$(echo "$respuesta" | jq -r '.choices[0].message.content')
    [ -z "$comando" ] || [ "$comando" = "null" ] && return 1
    
    echo -e "\033[32m$comando"
    return 0
}

# Función para usar Ollama local
usar_ollama() {
    query="$*"
    #modelo="qwen2.5:14b"
    url="http://localhost:11434/api/generate"
    
    payload=$(jq -n \
        --arg model "$modelo" \
        --arg prompt "$prompt" \
        '{model: $model, prompt: $prompt, stream: false}')

    local respuesta=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -d "$payload" "$url")
    
    if [ $? -ne 0 ]; then
        return 1
    fi
    
    local comando=$(echo "$respuesta" | jq -r '.response')
    [ -z "$comando" ] || [ "$comando" = "null" ] && return 1
    
    echo -e "\033[32m$comando"
    return 0
}

# Lógica principal
if usar_mistral; then
    exit 0
elif usar_ollama; then
    exit 0
else
    echo -e "\033[31mError: No se pudo conectar a ningún servicio de IA\033[0m"
    exit 1
fi
```

- el script tarea es mas complejo, este script debe analizar nuevamente el prompt ingresado por el usuario y determinar si es una tarea compleja o una tarea simple.
si la tarea es compleja se debe ejecutar un script llamado `tarea_compleja` en caso contraro se debe ejecutar un script llamado `tarea_simple`
ejemplos de tareas complejas y simples:
|peticion del usuario | salida del modelo |
|sustituye la palabra gato por perro en este fichero | simple |
|haz un directorio llamado datos | simple |
|haz un directorio llamado datos, en dicho directorio haz un archivo llamado mascotas y agrega 3 razas de perros y 3 razas de gatos en ese fichero | complejo |
|haz un directorio llamado proyecto web, en dicho directorio haz la estructura completa de un proyecto web con html, css, js y php | complejo |

como puedes ver las peticiones simples, son aquellas donde la ia solo debe hacer una tarea en el equipo, mientras que las complejas son una serie de acciones concatenadas que deben seguir un orden especifico para ser funcional.

- el script `tarea_compleja` debe buscar la mejor manera de resolver la peticion, este script debe generar un fichero markdown que contendra la peticion del usuario mas una respuesta textual de lo que el modelo entendio de la peticion, incluyendo preguntas al respecto (si las hay) para ampliar el contexto y que los resultados sean mejores, seguido por la secuencia de pasos que el modelo seguira para cumplir la peticion del usuario.
- una vez listo el documento, el script debe permitir al usuario leer y modificar dicho documento con neovim.
nvim <documento generado>

- el usuario debe leer el documento markdown, responder las preguntas realizadas por la ia y modificar los pasos descritos por la ia en caso de no estar de acuerdo con ellos o preferir una manera diferente.

- cuando el usuario termine de verificar el documento con neovim y cierre el fichero, el script debe leer nuevamente el documento y seguir los pasos tomando en cuenta la nueva informacion agregada por el usuario 

- el script `tarea_simple` debe ejecutar la tarea solicitada por el usuario al igual que el script haz
