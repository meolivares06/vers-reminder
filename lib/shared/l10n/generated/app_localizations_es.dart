// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'package:vers_reminder/shared/l10n/generated/app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Vers Reminder';

  @override
  String get verseListTitle => 'Versículos';

  @override
  String get addVerse => 'Agregar versículo';

  @override
  String get editVerse => 'Editar versículo';

  @override
  String get newVerse => 'Nuevo versículo';

  @override
  String get save => 'Guardar';

  @override
  String get cancel => 'Cancelar';

  @override
  String get delete => 'Eliminar';

  @override
  String get confirmDelete => '¿Eliminar versículo?';

  @override
  String get confirmDeleteBody =>
      '¿Estás seguro de que deseas eliminar este versículo?';

  @override
  String get confirm => 'Sí, eliminar';

  @override
  String confirmDeleteCitation(String citation) {
    return '¿Eliminar \"$citation\"?';
  }

  @override
  String get citation => 'Cita';

  @override
  String get text => 'Texto';

  @override
  String get textEs => 'Texto (Español)';

  @override
  String get textPt => 'Texto (Portugués)';

  @override
  String get categoriesLabel => 'Categorías';

  @override
  String get categoryNameLabel => 'Nombre de la categoría';

  @override
  String get citationHint => 'Ej: Juan 3:16';

  @override
  String get selectCategory => 'Seleccionar categoría';

  @override
  String get addCategory => 'Agregar categoría';

  @override
  String get newCategoryName => 'Nombre de la nueva categoría';

  @override
  String get selectAtLeastOneCategory => 'Selecciona al menos una categoría';

  @override
  String get noVerses => 'No hay versículos aún';

  @override
  String get settings => 'Configuración';

  @override
  String get language => 'Idioma';

  @override
  String get spanish => 'Español';

  @override
  String get portuguese => 'Portugués';

  @override
  String get autoChange => 'Auto-rotación';

  @override
  String get freq15min => '15 min';

  @override
  String get freq30min => '30 min';

  @override
  String get freq1h => '1 hora';

  @override
  String get freq3h => '3 horas';

  @override
  String get freq6h => '6 horas';

  @override
  String get freq12h => '12 horas';

  @override
  String get freq24h => '24 horas';

  @override
  String get topAlign => 'Arriba';

  @override
  String get centerAlign => 'Centro';

  @override
  String get bottomAlign => 'Abajo';

  @override
  String get leftOffset => 'Izq';

  @override
  String get rightOffset => 'Der';

  @override
  String get fontSize => 'Tamaño de letra';

  @override
  String get changeNow => 'Cambiar ahora';

  @override
  String get calibrateButton => 'Calibrar centrado del texto';

  @override
  String get permissionTitle => 'Permiso para cambiar el wallpaper';

  @override
  String get permissionMessage =>
      'Vers Reminder necesita cambiar tu wallpaper para mostrarte versículos bíblicos en la pantalla de inicio.\n\nSolo se usará cuando actives \"Cambiar ahora\" o la actualización automática.';

  @override
  String get generating => 'Generando...';

  @override
  String wallpaperUpdated(String citation) {
    return 'Wallpaper actualizado: $citation';
  }

  @override
  String get generatingError => 'Error al generar el wallpaper';

  @override
  String get selectCategoryStatus => 'Selecciona al menos una categoría';

  @override
  String get calibrationTitle => 'Calibrar wallpaper';

  @override
  String get calibrationInstructions =>
      'Ajustá el slider para recortar los bordes de la imagen, luego aplicá y verificá en tu pantalla de inicio.';

  @override
  String get cropInsetLabel => 'Crop inset';

  @override
  String get cropInsetDesc =>
      'Ajustá el recorte hasta que el texto quede centrado.';

  @override
  String get applyVerify => 'Aplicar y verificar';

  @override
  String get saveCalibration => 'Guardar calibración';

  @override
  String get reset => 'Resetear a 0';

  @override
  String get create => 'Crear';

  @override
  String get categoryCreateTitle => 'Nueva categoría';

  @override
  String get nameRequired => 'El nombre no puede estar vacío';

  @override
  String get citationRequired => 'La cita es requerida';

  @override
  String get textRequired => 'El texto es requerido';

  @override
  String get sectionScheduling => 'Rotación';

  @override
  String get sectionAppearance => 'Apariencia';

  @override
  String get sectionActions => 'Acciones';

  @override
  String get selectAll => 'Todas';

  @override
  String get clearAll => 'Ninguna';

  @override
  String get sectionAbout => 'Acerca de';

  @override
  String get aboutDescription =>
      'Vers Reminder te ayuda a memorizar versículos bíblicos mostrándolos como wallpaper en tu pantalla de inicio.';

  @override
  String get aboutContact => 'Contacto';

  @override
  String get aboutShare => 'Compartir app';

  @override
  String get checkForUpdates => 'Buscar actualizaciones';

  @override
  String updateAvailable(String version) {
    return 'Actualización disponible: $version';
  }

  @override
  String downloadUpdateConfirm(String version, String size) {
    return 'Hay una versión nueva ($version). ¿Descargar (aprox. $size)? Preserva tus wallpapers y ajustes.';
  }

  @override
  String get downloadUpdate => 'Descargar';

  @override
  String get installNow => 'Instalar';

  @override
  String get upToDate => 'Estás al día';

  @override
  String get updateCheckFailed => 'No se pudo buscar actualizaciones';

  @override
  String get updateDownloadFailed => 'No se pudo descargar la actualización';

  @override
  String get updateInstallFailed => 'No se pudo instalar la actualización';

  @override
  String get retry => 'Reintentar';

  @override
  String get downloadingUpdate => 'Descargando actualización...';

  @override
  String updateDownloadProgress(String percentage) {
    return 'Descargando actualización... $percentage%';
  }

  @override
  String get downloadComplete =>
      'Descarga completa. ¿Instalás la actualización ahora?';

  @override
  String get homeTab => 'Inicio';

  @override
  String get noWallpaper => 'Tocá para crear tu primer wallpaper';

  @override
  String get restoreOriginalWallpaper => 'Restaurar wallpaper original';

  @override
  String get restoreOriginalWallpaperSubtitle =>
      'Restaurá el wallpaper que estaba activo antes de usar Vers Reminder';

  @override
  String get restoreConfirmTitle => '¿Restaurar wallpaper?';

  @override
  String get restoreConfirmMessage =>
      'Esto va a reemplazar tu wallpaper actual por el original.';

  @override
  String get restoreConfirmOk => 'Restaurar';

  @override
  String get restoreConfirmCancel => 'Cancelar';

  @override
  String get restoreSuccess => 'Wallpaper original restaurado';

  @override
  String get restoreError => 'No se pudo restaurar el wallpaper';

  @override
  String get noBackupAvailable => 'No hay copia de seguridad disponible';

  @override
  String get backgroundSourceLabel => 'Fondo';

  @override
  String get backgroundSourceApp => 'App';

  @override
  String get backgroundSourceMine => 'Mío';

  @override
  String get pickBackgroundImage => 'Elegí imagen de fondo';

  @override
  String get replaceBackgroundImage => 'Reemplazar imagen';

  @override
  String get backgroundSelected => 'Imagen de fondo seleccionada';

  @override
  String get backgroundPickFailed => 'No se pudo abrir el selector';

  @override
  String get currentWallpaperLabel => 'Tu wallpaper';

  @override
  String updatedAtLabel(String time) {
    return 'Hace $time';
  }

  @override
  String shareApp(String url) {
    return 'Descargá Vers Reminder: $url';
  }

  @override
  String get emailCopied => 'Email copiado al portapapeles';

  @override
  String timeMinutes(int n) {
    return '$n min';
  }

  @override
  String timeHours(int n) {
    return '$n h';
  }

  @override
  String get previewLabel => 'Vista previa';

  @override
  String offsetLabel(String direction, String value) {
    return 'Desplazamiento: $direction $value';
  }

  @override
  String get disabledLabel => 'Desactivado';
}
