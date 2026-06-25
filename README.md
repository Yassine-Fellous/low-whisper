# 🎙️ LowWhisper

**LowWhisper** est une application utilitaire pour la barre de menu macOS qui permet de dicter du texte en local en utilisant le modèle de reconnaissance vocale **Whisper.cpp**. L'application capture votre voix, la transcrit localement, puis injecte directement le texte transcrit à l'emplacement actuel de votre curseur.

> [!IMPORTANT]
> **LowWhisper** fonctionne de manière **100% locale** et respecte votre vie privée. Aucun enregistrement audio ou texte transcrit n'est envoyé à des serveurs tiers.

---

## ✨ Fonctionnalités

- 🌐 **Reconnaissance vocale 100% locale** basée sur le modèle Whisper (`ggml-base.bin` d'environ 140 Mo) pré-configuré pour un excellent ratio vitesse/précision.
- ⌨️ **Raccourci clavier intelligent** :
  - **Push-to-Talk (PTT)** : Maintenez la touche **Globe (Fn)** enfoncée pour enregistrer, relâchez pour transcrire et insérer le texte.
  - **Enregistrement Continu** : Double-cliquez sur la touche **Globe (Fn)** pour démarrer l'enregistrement continu sans maintenir la touche. Appuyez à nouveau une fois sur la touche **Globe (Fn)** pour arrêter.
- 🎯 **Insertion automatique** du texte transcrit directement là où se trouve votre curseur (dans n'importe quel éditeur de texte, navigateur, messagerie, etc.).
- 📊 **Interface Overlay Flottante** : Affiche en temps réel l'amplitude de votre voix, l'état de la transcription ("Transcription..."), ou l'état de téléchargement du modèle.
- 🌐 **Support Multi-langue** : Menu permettant de sélectionner la langue de dictée (Français, Anglais, Espagnol, Allemand ou détection automatique).

---

## 📋 Prérequis

- **Système d'exploitation** : macOS 13.3 ou version ultérieure.
- **Processeur** : Apple Silicon (M1, M2, M3, M4, etc.) uniquement (le framework de transcription inclus cible l'architecture `macos-arm64`).
- **Outil de développement** : Xcode Command Line Tools ou Xcode (nécessaire pour compiler avec Swift).

---

## 🛠️ Installation et Compilation

### 1. Cloner le dépôt
Si ce n'est pas déjà fait :
```bash
git clone https://github.com/Yassine-Fellous/low-whisper.git
cd low-whisper
```

### 2. Compiler l'application
Exécutez le script de compilation fourni pour compiler le projet et créer le bundle d'application macOS (`LowWhisper.app`) :

```bash
chmod +x build_app.sh
./build_app.sh
```

Le script va :
1. Compiler le code Swift en mode Release.
2. Créer la structure de l'application `LowWhisper.app`.
3. Intégrer le framework de liaison `whisper.xcframework`.
4. Effectuer une signature ad-hoc (`codesign`) de l'application.

Une fois terminé, le fichier **`LowWhisper.app`** sera créé à la racine du projet. Vous pouvez le déplacer dans votre dossier `/Applications` ou le lancer directement.

---

## 🔐 Autorisations système requises

Au premier démarrage (ou depuis le menu de l'application), macOS vous demandera deux autorisations cruciales :

1. **Accessibilité (Accessibility)** : Recommandé pour permettre à l'application d'intercepter globalement la touche Globe (Fn) et de simuler la frappe au clavier pour injecter le texte transcrit.
   - *Comment l'activer* : Allez dans `Réglages Système` > `Confidentialité et sécurité` > `Accessibilité` et cochez **LowWhisper**.
2. **Microphone** : Recommandé pour capturer votre voix pour la dictée.
   - *Comment l'activer* : Autorisez l'accès lorsque macOS affiche la boîte de dialogue contextuelle au premier enregistrement.

---

## 🚀 Utilisation

1. **Lancement** : Lancez `LowWhisper.app`. Une icône en forme d'onde (`waveform.circle.fill`) apparaîtra dans votre barre de menu.
2. **Premier démarrage (Téléchargement du modèle)** : L'application téléchargera automatiquement le modèle de transcription (`ggml-base.bin`, 140 Mo) depuis Hugging Face. Une fenêtre overlay affichera la progression du téléchargement.
3. **Dictée rapide (Push-to-Talk)** :
   - Placez votre curseur dans un champ de saisie de texte.
   - Maintenez la touche **Globe (Fn)** enfoncée et parlez.
   - Relâchez la touche pour arrêter l'enregistrement. Le texte apparaîtra après quelques instants à l'emplacement de votre curseur.
4. **Dictée mains libres (Enregistrement Continu)** :
   - Double-cliquez sur la touche **Globe (Fn)**. L'enregistrement démarre.
   - Parlez sans maintenir de touche.
   - Appuyez une nouvelle fois brièvement sur **Globe (Fn)** pour finaliser et insérer le texte.

---

## ⚙️ Configuration

Cliquez sur l'icône de **LowWhisper** dans la barre de menu pour :
- Changer la **langue de dictée** (Français par défaut).
- Vérifier l'état du modèle et l'activation des permissions d'accessibilité.
- Demander manuellement la vérification des permissions.
- Quitter proprement l'application.
