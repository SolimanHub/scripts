#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
RESET='\033[0m'

if [ $# -eq 0 ]; then
    echo -e "${RED}Uso: $0 \"<prompt>\"${RESET}"
    echo -e "${YELLOW}Ejemplo: $0 \"Escribe un poema corto sobre la programación\"${RESET}"
    exit 1
fi

PROMPT="$*"

# Función para usar Mistral API (online)
usar_mistral() {
    local prompt="$1"
    # Verificar API key
    if [ -z "${MISTRAL_API_KEY:-}" ]; then
        echo -e "${RED}Error: No se ha configurado la variable de entorno MISTRAL_API_KEY${RESET}" >&2
        return 1
    fi
    # Modelos disponibles:
    # https://docs.mistral.ai/models/overview
    # devstral-2512
    # mistral-medium-3-5
    # voxtral-mini-transcribe-realtime-2602 (vos a texto)
    # mistral-small-latest

    local payload respuesta respuesta_texto
    payload=$(jq -n \
        --arg model "devstral-2512" \
        --arg content "$prompt" \
        '{model: $model, messages: [{role: "user", content: $content}], temperature: 0.7}')

    respuesta=$(curl -s --max-time 30 \
        -X POST "https://api.mistral.ai/v1/chat/completions" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $MISTRAL_API_KEY" \
        -d "$payload") || return 1

    respuesta_texto=$(echo "$respuesta" | jq -r '.choices[0].message.content')
    if [ -z "$respuesta_texto" ] || [ "$respuesta_texto" = "null" ]; then
        return 1
    fi
    echo "$respuesta_texto"
    return 0
}

# Obtener la lista de modelos de Ollama
echo -e "${CYAN}Obteniendo modelos locales...${RESET}"
mapfile -t models < <(ollama list | tail -n +2 | awk '{print $1}')

# Construir menú (opción 1 = Mistral online, luego los locales)
echo -e "${YELLOW}Seleccione que modelo desea usar:${RESET}"
printf "${GREEN}[1]${RESET} ${CYAN}mixtral online${RESET}\n"
for i in "${!models[@]}"; do
    printf "${GREEN}[%d]${RESET} ${CYAN}%s${RESET}\n" $((i+2)) "${models[$i]}"
done

# Leer selección del usuario
read -p "$(echo -e "${YELLOW}Ingrese el número del modelo: ${RESET}")" selection

# Validar número (máximo = 1 + cantidad de modelos)
max_opciones=$((1 + ${#models[@]}))
if ! [[ "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 1 ] || [ "$selection" -gt "$max_opciones" ]; then
    echo -e "${RED}Selección inválida. Debe ser un número entre 1 y $max_opciones.${RESET}"
    exit 1
fi

# Medición de tiempo (inicio)
start=$(date +%s%N)

# Procesar según selección
if [ "$selection" -eq 1 ]; then
    echo -e "${GREEN}Usando modelo: ${CYAN}mixtral online${RESET}"
    RESPONSE=$(usar_mistral "$PROMPT")
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error al consultar Mistral API. Verifique su clave y conexión.${RESET}"
        exit 1
    fi
else
    # Índice en el array models: selection - 2
    idx=$((selection - 2))
    MODEL=${models[$idx]}
    echo -e "${GREEN}Usando modelo: ${CYAN}$MODEL${RESET}"
    API_URL="http://127.0.0.1:11434/api/generate"
    PAYLOAD=$(jq -n --arg model "$MODEL" --arg prompt "$PROMPT" '{model: $model, prompt: $prompt, stream: false}')
    RESPONSE=$(curl -s -X POST "$API_URL" -d "$PAYLOAD" | jq -r '.response')
fi

# Medición de tiempo (fin)
end=$(date +%s%N)
diff_ns=$((end - start))
diff_ms=$((diff_ns / 1000000))
hours=$((diff_ms / 3600000))
minutes=$(( (diff_ms % 3600000) / 60000 ))
seconds=$(( (diff_ms % 60000) / 1000 ))
milliseconds=$((diff_ms % 1000))

# Mostrar respuesta del modelo
echo -e "${RESET}$RESPONSE${RESET}"
echo ""
printf "${MAGENTA}Tiempo de respuesta: %02d:%02d:%02d:%03d${RESET}\n" "$hours" "$minutes" "$seconds" "$milliseconds"
