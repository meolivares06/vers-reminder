Aquí tienes el PRD (Documento de Requisitos del Producto) Completo y Definitivo. He unificado toda la estructura, integrando el backoffice interno, público y simplificado, junto con la lógica de las 10 imágenes de naturaleza, el directorio local y el automatizador de Android.

\------------------------------

\## Documento de Requisitos del Producto (PRD)## 1. Descripción del Proyecto

Aplicación Android de código abierto y uso libre desarrollada en Flutter. El objetivo es ayudar a la memorización de textos bíblicos mediante un sistema automatizado que combina versículos con imágenes de naturaleza en alta resolución y los establece de forma dinámica como fondo de pantalla (inicio y bloqueo). La aplicación incluye un panel interno simplificado y accesible para que cualquier usuario pueda gestionar, añadir o modificar los versículos y categorías directamente desde el teléfono sin restricciones técnicos ni contraseñas.

\------------------------------

\## 2. Arquitectura del Sistema (Módulos Principales)



&#x20;                      ┌───────────────────────────┐

&#x20;                      │    PANTALLA PRINCIPAL     │

&#x20;                      └─────────────┬─────────────┘

&#x20;                                    │

&#x20;           ┌────────────────────────┴────────────────────────┐

&#x20;           ▼                                                 ▼

┌───────────────────────┐                         ┌───────────────────────┐

│ BACKOFFICE INTERNO    │                         │  CONFIGURACIÓN FONDO  │

│ (Gestión de Textos)   │                         │  (Tiempos y Filtros)  │

└───────────┬───────────┘                         └───────────┬───────────┘

&#x20;           │                                                 │

&#x20;           ▼                                                 ▼

┌───────────────────────┐                         ┌───────────────────────┐

│ BASE DE DATOS LOCAL   │◄────────────────────────┤ MOTOR EN SEGUNDO PLANO│

│ (Isar / Hive DB)      │                         │ (WorkManager Android) │

└───────────────────────┘                         └───────────┬───────────┘

&#x20;                                                             │

&#x20;           ┌─────────────────────────────────────────────────┘

&#x20;           ▼

┌─────────────────────────────────────────────────────────────────────────┐

│               DIRECTORIO LOCAL DE IMÁGENES (CACHÉ 10 FOTOS)             │

│  - Revisa stock local  - Descarga vía API si faltan  - Aplica a Pantalla │

└─────────────────────────────────────────────────────────────────────────┘



\------------------------------

\## 3. Especificaciones Funcionales (Scope)## Módulo A: Backoffice Interno y Público (Gestión de Versículos)

Diseñado bajo el principio de simplicidad total. Cualquier persona que instale la app puede editar el contenido.



\* Acceso Directo: Accesible desde la pantalla principal mediante un botón visible (ej. Icono de engranaje o de "Editar Textos"). Sin contraseñas ni sistemas de autenticación.

\* Formulario de Registro Rápido:

\* Texto: Campo grande para escribir o pegar el versículo.

&#x20;  \* Cita: Campo corto para el libro, capítulo y versículo (Ej: Josué 1:9).

&#x20;  \* Categoría: Menú desplegable con categorías existentes (Salvación, Fe, Paz, Fortaleza) y un botón de "+" para crear una nueva categoría de texto al instante.

\* Lista General Interactiva (CRUD):

\* Muestra todos los versículos guardados organizados por su categoría.

&#x20;  \* Permite pulsar cualquier versículo para editarlo inmediatamente.

&#x20;  \* Botón de eliminación directa (icono de basurero) para borrar versículos de la lista de rotación.

\* Precarga Automática (Seeding): Al abrir la app por primera vez, el sistema autogenera una base de datos local con al menos 20 versículos clave de distintas categorías para que la app sea funcional desde el primer segundo.



\## Módulo B: Almacenamiento y Directorio Local de Imágenes



\* Consumo Inteligente: La app se conectará a una API libre (como Unsplash o Pexels) filtrando por el parámetro "nature".

\* Caché de 10 Imágenes: La aplicación descargará exactamente 10 fotografías en alta definición y las guardará en una carpeta privada del almacenamiento interno (/storage/emulated/0/Android/data/com.ejemplo.bibleapp/files/nature\_cache/).

\* Lógica de Auto-Reparación: Cada vez que el motor en segundo plano vaya a cambiar el fondo, contará los archivos de ese directorio. Si el usuario borró fotos manualmente o el directorio está vacío, la app reactiva la descarga en segundo plano para volver a completar el stock de 10 imágenes. Si las 10 están intactas, no consume datos de internet.



\## Módulo C: Generador Gráfico de Fondos de Pantalla



\* Superposición de Texto (Overlay): El sistema toma la imagen de naturaleza correspondiente del directorio local y dibuja digitalmente encima el bloque de texto con la categoría arriba (en letras pequeñas/mayúsculas) y la cita bíblica abajo.

\* Garantía de Legibilidad: Para evitar que un fondo de naturaleza claro tape las letras blancas, el motor gráfico aplicará una capa superior semitransparente oscura (un filtro negro al 40% de opacidad) o un sombreado pronunciado en las fuentes tipográficas.

\* Ubicación Inteligente: El texto se centrará verticalmente dejando márgenes superior e inferior libres para evitar obstrucciones severas con el reloj del sistema o la barra de navegación de Android.



\## Módulo D: Automatizador en Segundo Plano (Configuración)



\* Frecuencia Ajustable: Un menú simple en la pantalla principal para configurar cada cuánto tiempo rota el fondo. Opciones fijas: 30 minutos, 1 hora, 3 horas, 6 horas, 12 horas, 24 horas.

\* Filtro Temático: El usuario puede marcar/desmarcar qué categorías quiere que entren en la rotación (ej. activar solo "Salvación" y "Paz", ignorando las demás).

\* Servicio Android: Uso del programador nativo del sistema operativo. El cambio de fondo se ejecuta de forma silenciosa incluso si el celular está bloqueado, en el bolsillo o con la aplicación cerrada.



\------------------------------

\## 4. Stack Tecnológico Sugerido para Flutter



| Componente | Paquete Flutter | Justificación Técnica |

|---|---|---|

| Persistencia | isar o hive | Bases de datos NoSQL muy ligeras, ideales para almacenar strings de texto y mapas de configuración de forma local y ultrarrápida. |

| Directorios | path\_provider | Accede de forma segura y estandarizada a las carpetas internas de Android para almacenar las imágenes de naturaleza. |

| Descargas | dio | Cliente HTTP robusto para gestionar la descarga de las 10 imágenes hacia el almacenamiento local. |

| Procesamiento | image (Dart Package) | Permite manipular los píxeles de la imagen descargada, añadir el filtro oscuro y plasmar las fuentes del versículo en memoria. |

| Inyección Nativa | wallpaper\_manager\_flutter | Envía el archivo de imagen ya procesado directamente a la API de Android encargada de actualizar el Wallpaper de inicio y bloqueo. |

| Tareas de Sistema | workmanager | El estándar en Flutter para programar ejecuciones periódicas en segundo plano respetando las políticas de batería de Android. |



\------------------------------

\## 5. Criterios de Aceptación (Definición de Terminado)



&#x20;  1. Al presionar el botón "Guardar" en el formulario del Backoffice, el versículo debe listarse inmediatamente y quedar disponible para la rotación.

&#x20;  2. Al apagar la conexión a internet, el sistema debe seguir cambiando de fondo de forma infinita utilizando las 10 imágenes guardadas en el directorio.

&#x20;  3. Si mediante el administrador de archivos del teléfono se borra la carpeta de imágenes, la app debe reconstruirla descargando 10 fotos nuevas la próxima vez que se inicie o se ejecute el temporizador.

&#x20;  4. El texto en el fondo de pantalla debe verse nítido tanto en pantallas con modo claro como oscuro nativos del sistema.



\------------------------------

Dime cuál de estos pasos de desarrollo prefieres que resolvamos primero en código:



\* Creamos el modelo de datos y la interfaz de usuario para el Backoffice Interno (el formulario para añadir y la lista para borrar versículos).

\* Escribimos la lógica para gestionar el directorio local de las 10 imágenes (detectar cuántas hay y descargarlas desde internet si faltan).

\* Desarrollamos la función matemática y visual para escribir el texto sobre la imagen de naturaleza.







