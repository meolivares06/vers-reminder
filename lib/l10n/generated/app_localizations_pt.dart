// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get appTitle => 'Vers Reminder';

  @override
  String get verseListTitle => 'Versículos';

  @override
  String get addVerse => 'Adicionar versículo';

  @override
  String get editVerse => 'Editar versículo';

  @override
  String get newVerse => 'Novo versículo';

  @override
  String get save => 'Salvar';

  @override
  String get cancel => 'Cancelar';

  @override
  String get delete => 'Excluir';

  @override
  String get confirmDelete => 'Excluir versículo?';

  @override
  String get confirmDeleteBody =>
      'Tem certeza de que deseja excluir este versículo?';

  @override
  String get confirm => 'Sim, excluir';

  @override
  String confirmDeleteCitation(String citation) {
    return 'Excluir \"$citation\"?';
  }

  @override
  String get citation => 'Citação';

  @override
  String get text => 'Texto';

  @override
  String get textEs => 'Texto (Espanhol)';

  @override
  String get textPt => 'Texto (Português)';

  @override
  String get categoriesLabel => 'Categorias';

  @override
  String get categoryNameLabel => 'Nome da categoria';

  @override
  String get citationHint => 'Ex: João 3:16';

  @override
  String get selectCategory => 'Selecionar categoria';

  @override
  String get addCategory => 'Adicionar categoria';

  @override
  String get newCategoryName => 'Nome da nova categoria';

  @override
  String get selectAtLeastOneCategory => 'Selecione pelo menos uma categoria';

  @override
  String get noVerses => 'Nenhum versículo ainda';

  @override
  String get settings => 'Configurações';

  @override
  String get language => 'Idioma';

  @override
  String get spanish => 'Espanhol';

  @override
  String get portuguese => 'Português';

  @override
  String get autoChange => 'Troca automática de wallpaper';

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
  String get topAlign => 'Topo';

  @override
  String get centerAlign => 'Centro';

  @override
  String get bottomAlign => 'Fundo';

  @override
  String get leftOffset => 'Esq';

  @override
  String get rightOffset => 'Dir';

  @override
  String get fontSize => 'Tamanho da fonte';

  @override
  String get changeNow => 'Trocar agora';

  @override
  String get calibrateButton => 'Calibrar centralização do texto';

  @override
  String get permissionTitle => 'Permissão para alterar o wallpaper';

  @override
  String get permissionMessage =>
      'O Vers Reminder precisa alterar seu wallpaper para mostrar versículos bíblicos na tela inicial.\n\nSó será usado quando você ativar \"Trocar agora\" ou a atualização automática.';

  @override
  String get generating => 'Gerando...';

  @override
  String wallpaperUpdated(String citation) {
    return 'Wallpaper atualizado: $citation';
  }

  @override
  String get generatingError => 'Erro ao gerar o wallpaper';

  @override
  String get selectCategoryStatus => 'Selecione pelo menos uma categoria';

  @override
  String get calibrationTitle => 'Calibrar wallpaper';

  @override
  String get calibrationInstructions =>
      'Ajuste o slider para cortar as bordas da imagem, depois aplique e verifique na tela inicial.';

  @override
  String get cropInsetLabel => 'Crop inset';

  @override
  String get cropInsetDesc =>
      'Ajuste o corte até que o texto fique centralizado.';

  @override
  String get applyVerify => 'Aplicar e verificar';

  @override
  String get saveCalibration => 'Salvar calibração';

  @override
  String get reset => 'Resetar para 0';

  @override
  String get create => 'Criar';

  @override
  String get categoryCreateTitle => 'Nova categoria';

  @override
  String get nameRequired => 'O nome não pode estar vazio';

  @override
  String get citationRequired => 'A citação é obrigatória';

  @override
  String get textRequired => 'O texto é obrigatório';

  @override
  String get sectionScheduling => 'Agendamento';

  @override
  String get sectionSchedulingSub =>
      'Configure com que frequência o wallpaper é atualizado automaticamente';

  @override
  String get sectionAppearance => 'Aparência';

  @override
  String get sectionAppearanceSub => 'Ajuste a posição do texto no wallpaper';

  @override
  String get sectionCategoriesSub => 'Escolha quais versículos exibir';

  @override
  String get sectionActions => 'Ações';

  @override
  String get sectionActionsSub =>
      'Troque o wallpaper ou calibre o centralização';

  @override
  String get selectAll => 'Selecionar tudo';

  @override
  String get clearAll => 'Limpar';

  @override
  String get sectionAbout => 'Sobre';

  @override
  String get aboutDescription =>
      'O Vers Reminder ajuda você a memorizar versículos bíblicos exibindo-os como wallpaper na tela inicial.';

  @override
  String get aboutContact => 'Contato';

  @override
  String get aboutVersion => 'Versão 1.0.0';

  @override
  String get homeTab => 'Início';

  @override
  String get noWallpaper => 'Sem wallpaper ainda. Toque para gerar o primeiro.';
}
