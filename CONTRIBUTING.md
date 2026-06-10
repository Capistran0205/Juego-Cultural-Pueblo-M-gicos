# Guía de Contribución — Pueblos Mágicos

Juego cultural desarrollado en **Godot 4.5** (GL Compatibility) sobre los Pueblos
Mágicos de México. Esta guía explica cómo clonar el proyecto correctamente
(incluyendo **Git LFS** para las imágenes), abrirlo en Godot y colaborar.

> ⚠️ **Lo más importante:** los mapas de los estados (`Assets/Mapas/*.png`) se
> versionan con **Git LFS**. Si clonas **sin** tener Git LFS instalado, recibirás
> solo punteros de texto en vez de las imágenes y **Godot fallará al importarlas**.
> Sigue los pasos de abajo en orden.

---

## 1. Requisitos previos

- **Godot 4.5** (rama GL Compatibility / renderer "mobile") — [descargar](https://godotengine.org/download)
- **Git** 2.x — [descargar](https://git-scm.com)
- **Git LFS** 3.x — viene incluido en *Git for Windows*; si no, ver paso 2.

Verifica que tienes lo necesario:

```bash
git --version
git lfs version      # debe imprimir git-lfs/3.x.x
```

---

## 2. Clonar el proyecto (✅ forma recomendada)

El orden importa: **instala LFS antes de clonar** para que las imágenes se
descarguen automáticamente.

**2.1. Instalar el binario de Git LFS** (si `git lfs version` falló)

- **Windows:** ya viene con *Git for Windows*. Si no, `winget install GitHub.GitLFS`
  o descárgalo de [git-lfs.com](https://git-lfs.com).
- **macOS:** `brew install git-lfs`
- **Linux (Debian/Ubuntu):** `sudo apt install git-lfs`

**2.2. Activar LFS para tu usuario** (una sola vez por máquina)

```bash
git lfs install
```

**2.3. Clonar normal**

```bash
git clone <URL-del-repositorio>
```

Como LFS ya está activo, durante el checkout se descargan **automáticamente** las
imágenes reales (no los punteros). Al terminar, abre el proyecto en Godot.

---

## 3. ¿Ya clonaste *antes* de instalar LFS?

Si los `.png` pesan ~130 bytes o Godot marca error de textura, **no re-clones**:

```bash
git lfs install        # si aún no lo hiciste
cd <carpeta-del-repo>
git lfs pull           # baja los binarios reales y reemplaza los punteros
```

---

## 4. Verificar que las imágenes están completas

```bash
git lfs ls-files       # debe listar los 32 mapas
git lfs status         # estado de los objetos LFS
```

En **PowerShell**, comprueba que un mapa pesa MB (no bytes):

```powershell
(Get-Item "Assets\Mapas\Aguascalientes.png").Length    # ~5402043 (5.4 MB), no ~130
```

Si diera ~130 bytes, es un puntero sin descargar → faltó `git lfs pull`.

---

## 5. Abrir en Godot

1. Abre **Godot 4.5**.
2. *Import* → selecciona el `project.godot` de la carpeta clonada.
3. La primera vez, Godot reimporta los assets (`.import`); puede tardar un poco.
4. Escena principal: se ejecuta con **F5**.

---

## 6. Trabajar con imágenes y assets pesados

Los mapas ya están cubiertos: cualquier `Assets/Mapas/*.png` o `*.webp` entra a
LFS **automáticamente** (regla en `.gitattributes`). Solo haz `git add` normal.

Si necesitas versionar **otro tipo** de archivo pesado (p. ej. audio, video o
imágenes en otra carpeta), primero regístralo en LFS:

```bash
git lfs track "Assets/Audio/*.ogg"     # ejemplo
git add .gitattributes                 # ¡commitea la regla primero!
git add Assets/Audio/                   # luego los archivos (entran como punteros)
git commit -m "assets: <descripción>"
```

> Regla de oro: el archivo solo se guarda en LFS si su patrón ya está en
> `.gitattributes` **antes** de hacerle `git add`.

---

## 7. Qué NO se versiona

Definido en `.gitignore` — no lo subas:

- `.godot/` — caché del motor (se regenera).
- `/android/` — plantilla de exportación Android.
- `Claves y APIS/`, `*.keystore`, `*.jks` — **llaves de firma y secretos** (¡nunca al repo!).
- `Assets/Mapas/*.zip` — el `Mapas.zip` (~155 MB) es redundante con los PNG; no se sube.

---

## 8. Flujo de trabajo con Git

1. Crea una rama por funcionalidad: `git checkout -b feat/mi-funcionalidad`
2. Commits pequeños y descriptivos, en español. Estilo sugerido:
   - `feat(area): descripción` — nueva funcionalidad
   - `fix(area): descripción` — corrección
   - `chore(area): descripción` — mantenimiento/config
3. Sube tu rama y abre un Pull Request hacia `master`.
4. Al hacer `push`, los objetos LFS se suben solos junto con el commit.

> 💡 **Cuota LFS de GitHub (plan gratis):** 1 GB de almacenamiento + 1 GB/mes de
> ancho de banda. Cada `clone`/`pull` de imágenes consume banda; para un equipo
> chico alcanza de sobra. Evita subir binarios innecesarios.

---

## 9. Solución de problemas

| Síntoma | Causa | Solución |
|---|---|---|
| Godot: error al importar `.png` / textura rota | Clonaste sin LFS (tienes punteros) | `git lfs install` → `git lfs pull` |
| `git lfs version` no existe | Falta el binario de Git LFS | Instálalo (paso 2.1) |
| Las imágenes pesan ~130 bytes | Punteros sin resolver | `git lfs pull` |
| `push` rechazado por tamaño (>100 MB) | Subiste un binario fuera de LFS | Regístralo en LFS (sección 6) o quítalo del commit |
| No descarga LFS detrás de firewall corporativo | Bloqueo de red | Permitir salida a `*.git-lfs.github.com` |

---

## 10. Referencias

- Arquitectura, autoloads, flujo de juego y componentes: ver **`CONTEXTO_PROYECTO.md`**.
- Documentación oficial de Git LFS: <https://git-lfs.com>

¡Gracias por contribuir! 🇲🇽
