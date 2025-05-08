# Ejecutar cadenas como comandos en Linux

Usando eval:
```bash
eval $(echo "sudo pacman -Sy")
```
O directamente:
```bash
eval "sudo pacman -Sy"
```

Usando command substitution:
```bash
$(echo "sudo pacman -Sy")
```

Usando bash -c:
```bash
bash -c "$(echo "sudo pacman -Sy")"
```

Con xargs (aunque no es exactamente lo que buscas con la tubería):
```bash
echo "sudo pacman -Sy" | xargs -I {} bash -c "{}"
```

```bash
echo "sudo pacman -Sy" | bash
```
