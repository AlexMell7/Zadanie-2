# Zadanie 2 - Potok CI/CD i bezpieczeństwo obrazów

**Autor:** Oleksandr Melnyk (Nr albumu: 101743)
**Uczelnia:** Politechnika Lubelska

---

## Linki do repozytoriów obrazów i cache

* **Gotowy obraz aplikacji (GHCR):** [https://github.com/[TWÓJ_LOGIN_GITHUB]/[NAZWA_REPOZYTORIUM]/packages](https://github.com/[TWÓJ_LOGIN_GITHUB]/[NAZWA_REPOZYTORIUM]/packages)
* **Dane Cache (DockerHub):** [https://hub.docker.com/r/[TWÓJ_LOGIN_DOCKERHUB]/zadanie2-cache/tags](https://hub.docker.com/r/[TWÓJ_LOGIN_DOCKERHUB]/zadanie2-cache/tags)

---

## Konfiguracja środowiska (GitHub Actions)

Aby łańcuch CI/CD działał poprawnie, w ustawieniach repozytorium na GitHubie (zakładka *Settings -> Secrets and variables -> Actions*) dodano następujące zmienne środowiskowe (Secrets):

* `DOCKERHUB_USERNAME` – nazwa użytkownika w serwisie DockerHub.
* `DOCKERHUB_TOKEN` – Personal Access Token (PAT) wygenerowany w DockerHub z uprawnieniami do odczytu i zapisu (Read & Write).

Zmienna `GITHUB_TOKEN` wykorzystywana do logowania i pushowania do GHCR jest generowana automatycznie przez GitHub Actions w trakcie trwania zadania. Zadbano również o odpowiednie uprawnienia dla joba w pliku YAML (`permissions: contents: read, packages: write`), aby token miał prawa zapisu do GitHub Packages.

---

## Opis realizacji i wykonane etapy

W ramach repozytorium skonfigurowano łańcuch GitHub Actions, który automatyzuje proces budowy wieloarchitekturowego obrazu Dockera (`linux/amd64`, `linux/arm64`) na bazie aplikacji z Zadania 1. Proces ten kończy się wypchnięciem gotowego obrazu do rejestru `ghcr.io`, pod warunkiem pomyślnego przejścia audytu bezpieczeństwa.

1. **Konfiguracja środowiska:** Użyto akcji `setup-qemu` oraz `setup-buildx` do natywnej i emulowanej kompilacji kodu dla różnych architektur na runnerach bazujących na maszynach wirtualnych Ubuntu.
2. **Logowanie:** Zaimplementowano logowanie do dwóch różnych rejestrów – DockerHub (gdzie przechowywane i aktualizowane są dane cache) oraz GHCR (rejestr docelowy gotowego obrazu kontenera).
3. **Skanowanie CVE (Trivy):** Obraz jest początkowo budowany w trybie izolowanym, wyłącznie do lokalnego środowiska w runnerze.
4. **Wieloplatformowy Build & Push:** Dopiero po pozytywnym przejściu skanowania podatności obraz jest budowany docelowo dla architektur `linux/amd64` oraz `linux/arm64`, a następnie wypychany do GHCR wraz z zastosowaniem odpowiednich tagów.

---

## Strategia tagowania i użycie cache (Uzasadnienie)

### 1. Tagowanie obrazów w GHCR
W potoku wykorzystano narzędzie `docker/metadata-action`, które automatycznie generuje tagi dla budowanego obrazu. Wypychany obraz otrzymuje tag `latest` (dla gałęzi domyślnej) oraz **tag z krótkim skrótem commita (SHA)** (np. `sha-4a9b2c7`).

* **Uzasadnienie (Immutability):** Tagowanie obrazów za pomocą skrótu SHA z Git jest fundamentalną praktyką w metodykach GitOps i Continuous Deployment. Tag `latest` jest tzw. tagiem mutowalnym (nadpisywanym przy każdym wdrożeniu), co utrudnia śledzenie, która wersja kodu rzeczywiście działa na produkcji. Użycie unikalnego identyfikatora commitu gwarantuje absolutną pewność co do pochodzenia obrazu i umożliwia natychmiastowy, bezbłędny "rollback" w przypadku awarii.
* **Źródło:** *[Docker Docs - Dockerfile Best Practices: Tags](https://docs.docker.com/build/building/best-practices/)* oraz *[GitOps Principles (Weaveworks)](https://www.weave.works/technologies/gitops/)*.

### 2. Zarządzanie warstwami cache w DockerHub
Dane pamięci podręcznej są eksportowane do zewnętrznego repozytorium na DockerHub ze specjalnym tagiem `buildcache` (rejestr `[TWÓJ_LOGIN_DOCKERHUB]/zadanie2-cache:buildcache`).

* **Uzasadnienie oddzielenia cache:** Wydzielenie warstw pamięci podręcznej do osobnego rejestru zapobiega "zaśmiecaniu" głównego rejestru produkcyjnego (GHCR). Dzięki temu użytkownicy pobierający obraz widzą tylko gotowe, wydane wersje aplikacji.
* **Uzasadnienie `mode=max`:** Zastosowano eksporter z opcją `mode=max`. W przeciwieństwie do trybu `min`, tryb `max` zapisuje w cache nie tylko warstwy ostatecznego obrazu, ale również wszystkie warstwy pośrednie ze wszystkich etapów budowania (tzw. obrazy typu "builder"). Biorąc pod uwagę emulację architektury ARM64 przez QEMU na maszynach AMD64, co jest procesem niezwykle obciążającym procesor, przywrócenie binarnych plików pośrednich drastycznie skraca czas wykonania kolejnych potoków CI.
* **Źródło:** *[Docker Docs - Cache storage backends (Registry)](https://docs.docker.com/build/cache/backends/registry/)*.

### 3. Wybór skanera: Trivy vs Docker Scout
Do weryfikacji bezpieczeństwa obrazu pod kątem luk CVE wybrano narzędzie **Trivy** od Aqua Security.

* **Uzasadnienie wyboru:** Z perspektywy automatyzacji CI/CD w GitHub Actions, Trivy jest rozwiązaniem prostszym w implementacji (standalone binary/GitHub Action), które nie wymaga dodatkowej konfiguracji usług w chmurze ani logowania do środowisk Docker Scout w celu integracji polityk bezpieczeństwa. Działa w pełni lokalnie w runnerze, jest niezwykle szybkie i natywnie obsługuje przerywanie działania pipeline'u (`exit-code: '1'`) po znalezieniu podatności z określonego poziomu (w tym zadaniu `HIGH` lub `CRITICAL`).
* **Źródło:** *[Trivy Documentation - CI/CD Integration](https://aquasecurity.github.io/trivy/)*.
