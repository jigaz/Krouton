import Foundation

extension KroutonL10n {
    /// Extended multilingual dictionary covering newly added Multi-Disc Spanning, Disc Size,
    /// Audio/Video Authoring, and Accessibility controls across all 9 foreign languages.
    static let extendedCatalog: [String: [String: String]] = [
        "Disc Size:": [
            "ja": "ディスク容量:", "de": "Disk-Größe:", "fr": "Taille du disque :", "es": "Tamaño de disco:",
            "it": "Dimensione disco:", "pt": "Tamanho do disco:", "nl": "Schijfgrootte:", "zh-Hans": "光盘容量:", "ko": "디스크 크기:"
        ],
        "Write CD-TEXT": [
            "ja": "CD-TEXTを書き込む", "de": "CD-TEXT schreiben", "fr": "Écrire CD-TEXT", "es": "Escribir CD-TEXT",
            "it": "Scrivi CD-TEXT", "pt": "Gravar CD-TEXT", "nl": "CD-TEXT schrijven", "zh-Hans": "写入 CD-TEXT", "ko": "CD-TEXT 쓰기"
        ],
        "Remove Item": [
            "ja": "項目を削除", "de": "Objekt entfernen", "fr": "Supprimer l’élément", "es": "Eliminar elemento",
            "it": "Rimuovi elemento", "pt": "Remover item", "nl": "Item verwijderen", "zh-Hans": "移除项目", "ko": "항목 제거"
        ],
        "Remove Track": [
            "ja": "トラックを削除", "de": "Titel entfernen", "fr": "Supprimer la piste", "es": "Eliminar pista",
            "it": "Rimuovi traccia", "pt": "Remover faixa", "nl": "Track verwijderen", "zh-Hans": "移除音轨", "ko": "트랙 제거"
        ],
        "Select All Tracks": [
            "ja": "すべてのトラックを選択", "de": "Alle Titel auswählen", "fr": "Tout sélectionner", "es": "Seleccionar todas las pistas",
            "it": "Seleziona tutte le tracce", "pt": "Selecionar todas as faixas", "nl": "Selecteer alle tracks", "zh-Hans": "全选音轨", "ko": "모든 트랙 선택"
        ],
        "Deselect All Tracks": [
            "ja": "すべての選択を解除", "de": "Auswahl aufheben", "fr": "Tout désélectionner", "es": "Deseleccionar todo",
            "it": "Deseleziona tutto", "pt": "Desmarcar tudo", "nl": "Deselecteer alles", "zh-Hans": "取消全选", "ko": "모든 선택 해제"
        ],
        "Audition Track Transition": [
            "ja": "トランジションを試聴", "de": "Übergang vorhören", "fr": "Écouter la transition", "es": "Escuchar transición",
            "it": "Ascolta transizione", "pt": "Ouvir transição", "nl": "Overgang beluisteren", "zh-Hans": "试听音轨过渡", "ko": "트랙 전환 미리 듣기"
        ],
        "Stop Audition": [
            "ja": "試聴を停止", "de": "Vorhören stoppen", "fr": "Arrêter l’écoute", "es": "Detener escucha",
            "it": "Ferma ascolto", "pt": "Parar audição", "nl": "Stop beluisteren", "zh-Hans": "停止试听", "ko": "미리 듣기 중지"
        ],
        "Verify SHA-256 Digest Before Write": [
            "ja": "書き込み前にSHA-256を検証", "de": "SHA-256 vor dem Brennen prüfen", "fr": "Vérifier SHA-256 avant gravure", "es": "Verificar SHA-256 antes de grabar",
            "it": "Verifica SHA-256 prima di scrivere", "pt": "Verificar SHA-256 antes de gravar", "nl": "SHA-256 controleren voor branden", "zh-Hans": "写入前校验 SHA-256", "ko": "기록 전 SHA-256 검증"
        ],
        "Compute SHA-256": [
            "ja": "SHA-256を計算", "de": "SHA-256 berechnen", "fr": "Calculer SHA-256", "es": "Calcular SHA-256",
            "it": "Calcola SHA-256", "pt": "Calcular SHA-256", "nl": "SHA-256 berekenen", "zh-Hans": "计算 SHA-256", "ko": "SHA-256 계산"
        ],
        "Mount": [
            "ja": "マウント", "de": "Aktivieren", "fr": "Monter", "es": "Montar",
            "it": "attiva", "pt": "Montar", "nl": "Activeer", "zh-Hans": "挂载", "ko": "마운트"
        ],
        "Save As...": [
            "ja": "別名で保存...", "de": "Sichern unter…", "fr": "Enregistrer sous…", "es": "Guardar como…",
            "it": "Salva col nome…", "pt": "Salvar como…", "nl": "Bewaar als…", "zh-Hans": "另存为...", "ko": "별도 저장..."
        ],
        "Gapless (0s)": [
            "ja": "ギャップレス (0秒)", "de": "Unterbrechungsfrei (0s)", "fr": "Sans blanc (0s)", "es": "Sin pausas (0s)",
            "it": "Senza pause (0s)", "pt": "Sem intervalos (0s)", "nl": "Gapless (0s)", "zh-Hans": "无缝衔接 (0秒)", "ko": "갭리스 (0초)"
        ],
        "2s Pause": [
            "ja": "2秒ポーズ", "de": "2s Pause", "fr": "Pause 2s", "es": "Pausa de 2s",
            "it": "Pausa 2s", "pt": "Pausa de 2s", "nl": "2s pauze", "zh-Hans": "2秒间隔", "ko": "2초 휴지"
        ],
        "2.5s X-Fade": [
            "ja": "2.5秒クロスフェード", "de": "2,5s Überblenden", "fr": "Fondu 2,5s", "es": "Fundido 2,5s",
            "it": "Dissolvenza 2,5s", "pt": "Crossfade 2,5s", "nl": "2,5s crossfade", "zh-Hans": "2.5秒交叉淡化", "ko": "2.5초 크로스페이드"
        ],
        "Zoom Out Canvas": [
            "ja": "キャンバスを縮小", "de": "Arbeitsfläche verkleinern", "fr": "Dézoomer le canevas", "es": "Alejar lienzo",
            "it": "Riduci zoom tela", "pt": "Reduzir zoom da tela", "nl": "Zoom uit op canvas", "zh-Hans": "缩小画布", "ko": "캔버스 축소"
        ],
        "Zoom In Canvas": [
            "ja": "キャンバスを拡大", "de": "Arbeitsfläche vergrößern", "fr": "Zoomer le canevas", "es": "Acercar lienzo",
            "it": "Ingrandisci zoom tela", "pt": "Ampliar zoom da tela", "nl": "Zoom in op canvas", "zh-Hans": "放大画布", "ko": "캔버스 확대"
        ]
    ]
}
