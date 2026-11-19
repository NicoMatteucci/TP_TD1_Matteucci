#!/usr/bin/env bash

# Verifica que se haya pasado al menos el mensaje de commit
if [ -z "$1" ]; then
    echo "Error: Falta el mensaje del commit."
    echo "Uso: ./update_git \"mensaje del commit\" [rama]"
    exit 1
fi

MENSAJE="$1"
# Si no pasás la rama ($2), usa la rama activa actual por defecto
RAMA="${2:-$(git branch --show-current)}"

echo "Agregando archivos..."
git add .

echo "Creando commit con mensaje: '$MENSAJE'..."
if git commit -m "$MENSAJE"; then
    echo "Subiendo cambios a origin/$RAMA..."
    git push origin "$RAMA"
else
    echo "No se pudo realizar el commit (quizás no hay cambios nuevos para guardar)."
    exit 1
fi
