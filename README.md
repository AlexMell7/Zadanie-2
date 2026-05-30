# Zadanie 2 - Potok CI/CD i bezpieczeństwo obrazów

**Autor:** Oleksandr Melnyk (Nr albumu: 101743)
**Uczelnia:** Politechnika Lubelska

## Opis realizacji

W ramach repozytorium skonfigurowano łańcuch GitHub Actions, który automatyzuje proces budowy wieloarchitekturowego obrazu Dockera (`linux/amd64`, `linux/arm64`) na bazie aplikacji z Zadania 1. Proces ten kończy się wypchnięciem gotowego obrazu do rejestru `ghcr.io`, jednak warunkiem koniecznym jest przejście audytu bezpieczeństwa.

## Wykonane etapy

1. **Konfiguracja środowiska:** Użyto akcji `setup-qemu` oraz `setup-buildx` do obsługi kompilacji dla architektury ARM na runnerach bazujących na AMD64.
2. **Logowanie:** Zaimplementowano logowanie do dwóch różnych rejestrów – DockerHub (obsługa danych cache) oraz GHCR (rejestr docelowy obrazu).
3. **Skanowanie CVE (Trivy):** Obraz jest początkowo budowany wyłącznie do lokalnego środowiska w runnerze. Wykorzystano darmowe narzędzie **Trivy** wbudowane w łańcuch CI. Trivy jest szybsze i lżejsze do wdrożenia w CI niż Docker Scout, nie wymaga kont premium i natywnie przerywa działanie pipeline'u (`exit-code: '1'`) po znalezieniu podatności sklasyfikowanych jako `HIGH` lub `CRITICAL`. Dopiero pozytywny wynik tego testu pozwala na ostateczną budowę docelową.
4. **Wieloplatformowy Build & Push:** Zbudowanie obrazu dla obu architektur i wysłanie do GitHub Container Registry.

## Strategia tagowania i użycie cache (Uzasadnienie)

### 1. Tagowanie obrazów w GHCR

W potoku wykorzystano narzędzie `docker/metadata-action`, które generuje tag `latest` dla gałęzi domyślnej oraz **tag z krótkim skrótem commita (SHA)**.

* **Uzasadnienie (Immutability/Niezmienność):** Tagowanie obrazów poprzez skrót SHA z Git (np. `sha-4a9b2c7`) jest krytyczną praktyką w metodyce GitOps. Pozwala to na absolutną pewność, z jakiej dokładnie wersji kodu źródłowego został zbudowany dany kontener działający na produkcji. Zabezpiecza to przed nadpisywaniem obrazów (co dzieje się przy używaniu tylko tagu `latest`) i pozwala na natychmiastowy, pewny "rollback" w przypadku awarii środowiska produkcyjnego.

### 2. Zarządzanie warstwami cache w DockerHub

Dane pamięci podręcznej są przesyłane do zewnętrznego, publicznego repozytorium na DockerHub z tagiem `buildcache` (wskazanym w zmiennej `<dockerhub_username>/zadanie2-cache:buildcache`).

* **Uzasadnienie oddzielenia cache:** Oddzielenie warstw cache do zewnętrznego rejestru (DockerHub) pozwala utrzymać główny rejestr aplikacji (GHCR) w porządku – trafiają tam tylko gotowe do wdrożenia obrazy.
* **Uzasadnienie `mode=max`:** Wykorzystanie eksportera cache w trybie `max` wymusza zapisywanie warstw ze wszystkich etapów budowania (w tym obrazów typu "builder" używanych przy kompilacji skrośnej Go). Przy emulacji architektury ARM64 przez QEMU kompilacja kodu potrafi trwać długo. Cache w trybie `max` pozwala przywrócić skompilowane binarne pliki pośrednie, oszczędzając zasoby i drastycznie skracając czas działania łańcucha w kolejnych commitach
