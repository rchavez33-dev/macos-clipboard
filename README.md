# SwiftClipboard

> Un gestor de portapapeles nativo, moderno y ligero para macOS, basado en la experiencia de usuario y arquitectura de **Paste.app**.

Construido puramente en **Swift (SwiftUI + AppKit)** sin dependencias externas pesadas. Diseñado para ejecutarse como una aplicación de barra de menú no intrusiva con un panel flotante inferior accesible mediante atajo global. Gratis y de codigo abierto.

---

## ✨ Características

* **Panel flotante interactivo**: Se desliza suavemente desde la parte inferior de la pantalla sin robar el foco principal de tu aplicación de trabajo actual.
* **Atajo global `⇧⌘V`**: Abre o cierra el historial desde cualquier parte del sistema operativo.
* **Tarjetas inteligentes según el contenido**:
  * **Texto**: Previsualización formateada con conteo de caracteres.
  * **Enlaces**: Detección automática de URLs con icono y host de dominio.
  * **Colores**: Reconocimiento de códigos de color (`#HEX`, `rgb()`, `rgba()`) con muestra visual a pantalla completa del color.
  * **Imágenes**: Miniaturas renderizadas directamente desde el portapapeles.
  * **Archivos**: Identificación de rutas y archivos copiados con sus iconos nativos de macOS.
* **Tinte dinámico de app de origen**: Detecta la aplicación desde donde copiaste el elemento y tiñe el encabezado de la tarjeta con el color e icono de dicha app.
* **Privacidad y seguridad**: Respeta los tipos de portapapeles confidenciales (`org.nspasteboard.ConcealedType`, `TransientType`, 1Password, etc.) para **no almacenar contraseñas ni datos sensibles**.
* **Navegación 100% por teclado**:
  * `←` / `→`: Navegar entre tarjetas.
  * `Enter` o doble clic: Copia y **pega automáticamente** en la app que estabas usando.
  * `⌘1` al `⌘9`: Pega directamente cualquiera de los primeros 9 elementos.
  * `Esc`: Oculta el panel.
* **Fijado y organización (Pinboards)**: Fija elementos importantes para que no se pierdan al limpiar el historial.
* **Búsqueda instantánea**: Filtra en tiempo real por contenido, enlace, tipo o aplicación de origen.
* **Temas visuales intercambiables**:
  * **Paste**: La estética clásica inspirada en la paleta de Paste.app.
  * **Midnight**: Modo oscuro profundo con contrastes neón.
  * **Sunset**: Tonos cálidos con acentos naranja y rosa.
  * **Personalizado**: Totalmente editable en código.

---

## 📋 Requisitos

* **macOS 14.0 (Sonoma)** o superior.
* **Swift 6.0** o herramientas de línea de comandos de Xcode (`xcode-select --install`).

---

## 🚀 Instalación y Ejecución

No es necesario abrir el entorno gráfico de Xcode; el proyecto utiliza **Swift Package Manager (SwiftPM)** nativo.

### Opción 1: Empaquetar como Aplicación `.app` (Recomendado)

El script incluido compila en modo release, genera la estructura del bundle macOS y aplica una firma local ad-hoc:

```bash
# 1. Clonar el repositorio
git clone https://github.com/rchavez33-dev/swift-clipboard.git
cd swift-clipboard

# 2. Compilar y generar la aplicación
./scripts/make-app.sh

# 3. Mover a tu carpeta de Aplicaciones (opcional)
cp -R build/SwiftClipboard.app ~/Applications/

# 4. Abrir la app
open ~/Applications/SwiftClipboard.app
```

### Opción 2: Modo Desarrollo (Terminal)

Si deseas probar cambios rápidamente en código:

```bash
swift run
```

---

## 🔒 Permisos de Accesibilidad

Para que SwiftClipboard pueda **pegar automáticamente (`⌘V`)** el elemento seleccionado en la ventana activa:

1. Al abrir la app por primera vez, macOS solicitará permiso de **Accesibilidad**.
2. Ve a **Ajustes del Sistema > Privacidad y seguridad > Accesibilidad**.
3. Asegúrate de activar **SwiftClipboard**.

*(Si no deseas otorgar permisos de accesibilidad, la app seguirá funcionando copiando el elemento al portapapeles para que lo pegues manualmente).*

---

## 🎨 Personalización de Colores y Estilos

Todo el sistema de colores, esquinas redondeadas, materiales translúcidos (`NSVisualEffectView`) y acentos visuales está centralizado en:

👉 [`Sources/SwiftClipboard/Theme/Theme.swift`](file:///Users/rchavez/Developer/tutorials/swift-clipboard/Sources/SwiftClipboard/Theme/Theme.swift)

Puedes cambiar los valores de `Theme.custom` o agregar nuevos temas ajustando propiedades como:

```swift
var t = Theme.paste
t.selectionBorder = Color(hex: 0x10B981)         // Borde de selección
t.tabSelectedBackground = Color(hex: 0x10B981)  // Fondo de pestañas
t.headerColors[.text] = Color(hex: 0x059669)     // Color de cabecera para texto
```

---

## 🛠️ Estructura del Proyecto

```text
swift-clipboard/
├── Package.swift                    # Manifiesto de Swift Package Manager
├── scripts/
│   └── make-app.sh                  # Script de empaquetado del bundle .app
└── Sources/SwiftClipboard/
    ├── App/
    │   ├── App.swift                # Punto de entrada (@main) y NSStatusItem
    │   └── PanelController.swift    # Controlador del NSPanel flotante y atajos
    ├── Model/
    │   └── ClipItem.swift           # Modelo de datos, parsers y clasificación
    ├── Services/
    │   ├── ClipboardMonitor.swift   # Observador de NSPasteboard.changeCount
    │   ├── ClipboardStore.swift     # Persistencia local y lógica de fijados
    │   └── PasteService.swift       # Emulación de eventos de pegado y hotkey
    ├── Theme/
    │   └── Theme.swift              # Definición de temas, tokens y paletas
    └── Views/
        ├── ItemCard.swift           # Renderizado de tarjetas individuales
        ├── MainView.swift           # Interfaz principal, barra de búsqueda y pestañas
        └── PanelState.swift         # Estado reactivo del panel y filtros
```

---

## 📄 Licencia

Distribuido bajo la licencia MIT. Consulta el archivo para más detalles.
