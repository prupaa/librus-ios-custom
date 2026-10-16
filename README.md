# Librus+ dla iOS 18.3

Nowoczesna aplikacja szkolna na iOS w SwiftUI zaprojektowana jako alternatywa dla Librusa, z pełnym wsparciem dla powiadomień, dostosowywania wyglądu, analizy frekwencji i planu lekcji.

---

## 🚀 Jak wygenerować plik `.ipa` przez darmowy GitHub Actions (Krok po kroku)

Nie potrzebujesz komputera Mac! Kod skompiluje się w chmurze na serwerach Apple w ciągu 2 minut.

### Krok 1: Załóż repozytorium na GitHubie
1. Wejdź na [github.com](https://github.com) i zaloguj się (lub utwórz darmowe konto).
2. Kliknij **New** (nowe repozytorium), nazwij je np. `librus-ios`.
3. Wybierz opcję **Public** lub **Private** i kliknij **Create repository**.

### Krok 2: Wgraj pliki do repozytorium
Możesz to zrobić bez instalacji Gita:
1. Na stronie nowego repozytorium kliknij **uploading an existing file** (lub przeciągnij zawartość tego folderu).
2. Upewnij się, że wgrałeś folder `.github/workflows/build-ipa.yml`, plik `project.yml` oraz folder `Sources`.
3. Kliknij zielony przycisk **Commit changes**.

### Krok 3: Automatyczna kompilacja .IPA
1. Wejdź w zakładkę **Actions** w swoim repozytorium na GitHubie.
2. Zobaczysz uruchomiony proces **Zbuduj aplikację iOS (.ipa)** na maszynie `macos-14`.
3. Poczekaj około 1-2 minuty, aż proces zakończy się zielonym ptaszkiem (`Success`).
4. Kliknij w ten zakończony workflow, zjedź na sam dół do sekcji **Artifacts** i kliknij **LibrusPlus-iOS-18-Sideload**.
5. Pobieże się plik ZIP, w którym znajduje się gotowy plik **`LibrusPlus.ipa`**!

---

## 📲 Jak zainstalować (sideloadować) plik `.ipa` na iOS 18.3 (Windows)

Najprostszym narzędziem na Windowsa jest **Sideloadly**:

1. Pobierz i zainstaluj darmowe narzędzie [Sideloadly](https://sideloadly.io/) na Windowsie.
2. Zainstaluj iTunes i iCloud ze strony Apple (nie ze sklepu Microsoft Store – linki są na stronie Sideloadly).
3. Podłącz swojego iPhone'a kablem do komputera i kliknij **Zaufaj temu komputerowi** na telefonie.
4. Otwórz program Sideloadly:
   - W polu **Apple ID** wpisz swój e-mail Apple ID.
   - Przeciągnij pobrany plik `LibrusPlus.ipa` w pole z ikonką IPA.
   - Kliknij **Start**. Sideloadly automatycznie podpisze aplikację Twoim darmowym certyfikatem deweloperskim i zainstaluje ją na telefonie.
5. Na iPhone (wymagane w iOS 16/17/18):
   - Wejdź w **Ustawienia** -> **Prywatność i ochrona** -> zjedź na sam dół do **Tryb dewelopera** i włącz go (telefon poprosi o restart).
   - Po restarcie wejdź w **Ustawienia** -> **Ogólne** -> **VPN i zarządzanie urządzeniami**, kliknij swój Apple ID i wybierz **Zaufaj**.
6. Gotowe! Otwórz aplikację **Librus+** na swoim telefonie.

---

## ✨ Funkcje zaimplementowane w aplikacji

- **Plan lekcji**:
  - Podział na dni tygodnia (Pn-Pt), godziny rozpoczęcia i zakończenia, sala, nauczyciel.
  - Wyświetlanie czasu trwania przerw między lekcjami (np. *Przerwa: 10 min*).
  - Możliwość dodawania własnych wydarzeń (*Sprawdzian, Kartkówka, Zadanie domowe*) przypisanych do konkretnej lekcji i dnia.
- **Oceny**:
  - Kolorowe plakietki ocen z wagami (system wagowy).
  - Średnia ważona z każdego przedmiotu tuż pod ocenami.
  - Duża karta ze **Średnią ze wszystkich przedmiotów** na samej górze.
  - Opcja ukrywania wybranych przedmiotów (np. Religia, WDŻ) bezpośrednio z menu oceny.
- **Frekwencja**:
  - Karta z całkowitą aktualną frekwencją w %.
  - **Wykres liniowy Swift Charts** na każdy miesiąc roku szkolnego (Wrzesień - Czerwiec) z możliwością sprawdzania poszczególnych miesięcy.
  - Liczniki spóźnień, nieobecności, zwolnień oraz usprawiedliwień.
  - Lista przedmiotów w stylu ocen z procentową frekwencją – po dotknięciu otwiera się szczegółowa historia godzin.
- **Wiadomości**:
  - Skrzynka *Odebrane* i *Wysłane* w stylu Librusa z wyszukiwarką.
  - Podgląd treści, odpowiedź na wiadomość z prefiksem `Re:`, wysyłanie nowych wiadomości do nauczycieli.
  - Przycisk symulacji nadejścia wiadomości do natychmiastowego testowania powiadomień.
- **Customizacja i Ustawienia**:
  - Wybór własnego zdjęcia jako tło z galerii (PhotosPicker) + regulacja przezroczystości i rozmycia.
  - Wybór koloru przewodniego (Niebieski, Fioletowy, Szmaragdowy, Indygo, Miodowy, Karmazynowy).
  - Włączanie i wyłączanie konkretnych kategorii powiadomień (Oceny, Wiadomości, Sprawdziany, Przerwy).
  - Przycisk testu powiadomień push (lokalne notyfikacje iOS).
  - Zarządzanie widocznością przedmiotów (ukrywanie przedmiotów, na które uczeń nie chodzi).
