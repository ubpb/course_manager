# Schulungs- und Beratungsportal der UB Paderborn

Rails-Anwendung, mit der die Universitätsbibliothek Paderborn Schulungs- und Beratungsangebote veröffentlicht, Termine plant und Anmeldungen verwaltet – einschließlich Bestätigungs- und Erinnerungsmails, Teilnahmebescheinigungen und Berichten. Teilnehmende melden sich mit ihrem Bibliothekskonto an (Alma) und finden ihre Anmeldungen im Benutzerkonto; das Schulungsteam arbeitet im Admin-Bereich unter `/admin`.

## Entwicklung

### Voraussetzungen

- Ruby in der Version aus `.ruby-version`
- [Bun](https://bun.sh) (baut JavaScript und CSS)
- MariaDB, möglichst in der Version der Server (11.8). Standardmäßig über den Socket `/tmp/mysql.sock`; alternativ `DB_HOST`, `DB_PORT`, `DB_USERNAME`, `DB_PASSWORD` setzen.
- `config/master.key` für die verschlüsselten Credentials (u. a. Alma-API-Schlüssel)

### Einrichten und starten

```bash
bin/setup                # Gems installieren, Datenbank vorbereiten, Server starten
bin/dev                  # Rails-Server starten
bun run build:watch      # JavaScript/CSS bei Änderungen neu bauen – in einem zweiten Terminal
```

`bin/dev` startet nur den Rails-Server; ohne `bun run build:watch` (oder einmalig `bun run build`) werden Änderungen an JavaScript und CSS nicht übernommen.

Mails werden lokal nicht verschickt, sondern abgelegt und sind ohne Anmeldung unter <http://localhost:3000/admin/mail> zu lesen.

### Tests und Linting

```bash
bin/rails test           # alle Tests außer den Systemtests
bin/rails test:system    # Systemtests im Headless-Chrome (braucht gebaute Assets)
bin/rubocop              # Linting (Konfiguration: rubocop-ubpb, siehe .rubocop.yml); -a für sichere Korrekturen
bin/ci                   # Setup, RuboCop, Audit der Gems und JS-Pakete, Brakeman, Tests, Systemtests, Seeds
```

Die Tests laufen gegen eine eigene Test-Datenbank (`course_manager_test`), deren Schema aus `db/schema.rb` aufgebaut wird.

### Datenbank eines Servers lokal einspielen

```bash
cap <stage> app:db:pull      # ersetzt die lokale Entwicklungsdatenbank
bin/rails db:migrate         # falls der lokale Code neuere Migrationen hat
```

## Server und Deployment

Deployt wird mit Capistrano. Es gibt zwei Stages:

| Stage | Branch | Server | Rollen |
|---|---|---|---|
| `testing` | `master` | `stage.ub.upb.de` | app, db, web, jobs |
| `production` | `production` | `app1.ub.upb.de`, `app2.ub.upb.de` | app, web |
| | | `batch.ub.upb.de` | app, db, jobs |

Die Anwendung liegt unter `/ubpb/course_manager` und läuft als User `ubpb`; Ruby kommt aus dessen RVM-Installation, ausgeliefert wird über nginx/Passenger.

### Einmalige Einrichtung je Server

1. **Ruby** in der Version aus `.ruby-version` per RVM für den User `ubpb` installieren, dazu **Bun**.
2. **Verlinkte Dateien** unter `/ubpb/course_manager/shared/config/` anlegen. Sie werden bei jedem Deploy in das Release verlinkt und stehen nicht im Repository:
   - `database.yml` mit einem Abschnitt `production`
   - `master.key`
   - `application.yml` (siehe [Konfiguration](#konfiguration-configapplicationyml))
3. **Nur auf dem Server mit der Rolle `jobs`** (stage bzw. batch), einmalig als root:

   ```bash
   loginctl enable-linger ubpb
   ```

   Damit startet systemd die Dienste des Users `ubpb` beim Booten und lässt sie laufen, auch wenn niemand angemeldet ist. Ohne diesen Schritt endet der Jobs-Dienst mit der SSH-Verbindung des Deploys.
4. **Cronjobs ablösen:** Erinnerungsmails und DSGVO-Bereinigung übernimmt der Jobs-Dienst (siehe unten). Sobald er auf dem Server läuft, die bisherigen Crontab-Einträge für `app:mailer:send_reminder_messages` und `app:dsgvo:cleanup` entfernen.

### Deploy

```bash
git push                     # Capistrano liefert den Stand von GitHub aus, nicht den lokalen
cap testing deploy
cap production deploy
```

Capistrano erledigt dabei automatisch:

- Gems und JavaScript-Pakete installieren, Assets bauen
- Datenbank-Migrationen ausführen (auf dem Server mit der Rolle `db`)
- die Konfiguration der Hintergrundjobs prüfen (`bin/jobs check`) – ist sie fehlerhaft, bricht der Deploy ab, bevor das neue Release live geht
- Passenger neu starten
- den Jobs-Dienst installieren bzw. aktualisieren und neu starten

### Hintergrundjobs (Solid Queue)

Über [Solid Queue](https://github.com/rails/solid_queue) laufen die per `deliver_later` verschickten Mails sowie die wiederkehrenden Aufgaben aus `config/recurring.yml`:

| Aufgabe | Zeitpunkt (Berliner Zeit) | von Hand |
|---|---|---|
| DSGVO-Bereinigung: Anmeldungen 10 Tage nach dem Termin anonymisieren | täglich 05:00 | `bin/rails app:dsgvo:cleanup` |
| Erinnerungsmails für Termine der nächsten drei Tage | täglich 06:00 | `bin/rails app:mailer:send_reminder_messages` |
| Erledigte Jobs aufräumen | stündlich | – |

Die Tabellen von Solid Queue liegen in der Datenbank der Anwendung; eine eigene Datenbank ist nicht nötig.

Die Jobs verarbeitet `bin/jobs`, auf den Servern als **systemd-User-Dienst `course_manager-jobs`** des Users `ubpb` – nur auf dem Server mit der Rolle `jobs`, damit die wiederkehrenden Aufgaben nicht mehrfach laufen. Die Unit-Datei (`~/.config/systemd/user/course_manager-jobs.service`) erzeugt Capistrano bei jedem Deploy aus `lib/capistrano/templates/jobs.service.erb`; Änderungen direkt auf dem Server werden dabei überschrieben. Stürzt der Dienst ab, startet systemd ihn neu.

```bash
# lokal
cap <stage> app:jobs:status
cap <stage> app:jobs:restart     # ebenso: start, stop

# auf dem Server
systemctl --user status course_manager-jobs
journalctl --user -u course_manager-jobs
```

Fehlgeschlagene Jobs bleiben erhalten und lassen sich in der Rails-Konsole ansehen und erneut ausführen:

```ruby
SolidQueue::FailedExecution.count
SolidQueue::FailedExecution.find(id).retry
```

Braucht der Dienst Umgebungsvariablen, die die Anwendung sonst über nginx/Passenger erhält, gehören sie in `~/.config/course_manager/jobs.env` (eine Zeile `NAME=wert` je Variable); die Unit liest die Datei, falls sie existiert.

### Monitoring der Hintergrundjobs

`bin/rails app:jobs:health` gibt den Zustand von Solid Queue als JSON aus, für ein Prüfskript des Monitorings. Der Task stellt nur fest; Schwellen und Bewertung gehören ins Monitoring. Die Daten stehen in der Datenbank, der Task kann also auf jedem Server der Anwendung laufen, etwa als User `ubpb` auf dem mit der Rolle `jobs`:

```bash
cd /ubpb/course_manager/current && RAILS_ENV=production ~/.rvm/bin/rvm <Ruby-Version> do bundle exec bin/rails app:jobs:health
```

Die Standardausgabe enthält nur das JSON, Log-Zeilen gehen auf die Standardfehlerausgabe. Ist die Datenbank nicht erreichbar, endet der Task mit einem Exit-Code ungleich 0. Zeiten stehen in UTC, Alter und Dauern in Sekunden; `null` heißt: gibt es nicht.

| Feld | Inhalt | Hinweis auf ein Problem |
|---|---|---|
| `processes.expected` | wie viele Prozesse je Art laufen sollen (`Supervisor`, `Dispatcher`, `Worker`, `Scheduler`), gelesen aus `config/queue.yml` und `config/recurring.yml` | – |
| `processes.alive_threshold` | Zeit ohne Heartbeat, nach der Solid Queue einen Prozess für tot hält | – |
| `processes.registered` | die angemeldeten Prozesse mit `kind`, `hostname`, `pid`, `last_heartbeat_at` und `heartbeat_age` | weniger Prozesse einer Art mit `heartbeat_age` unter `alive_threshold` als erwartet; mehr als ein `Supervisor` (Jobs auf zwei Servern) |
| `jobs.ready` | wartende Jobs: `count`, `oldest_age` | `oldest_age` wächst: kein Worker arbeitet |
| `jobs.scheduled` | geplante Jobs: `count`, `overdue_age` (wie lange der überfälligste über seiner Zeit ist) | `overdue_age` über einer Minute: der Dispatcher hängt |
| `jobs.claimed` | laufende Jobs: `count`, `oldest_age` | `oldest_age` groß: ein Job hängt |
| `jobs.failed` | fehlgeschlagene Jobs: `count`, `latest_at`, `by_job_class`, `by_exception_class` – ohne Fehlermeldungen, da sie personenbezogene Daten enthalten können | `latest_at` neuer als bei der letzten Prüfung |
| `recurring.<Aufgabe>` | `schedule`, `last_due_at` (letzter planmäßiger Zeitpunkt), `last_enqueued_at`, `last_status` (`finished`, `failed`, `ready`, `claimed`) | `last_enqueued_at` einige Minuten nach `last_due_at` noch älter als dieses oder `null`; `last_status` `failed` |
| `paused_queues` | pausierte Queues | nicht leer |

`processes.expected` gilt für die Umgebung des Aufrufs: Steht `JOB_CONCURRENCY` in `jobs.env`, braucht auch der Aufruf des Tasks diese Variable.

## Konfiguration (`config/application.yml`)

Die Datei hat die Abschnitte `shared`, `development` und `production` und darf ERB enthalten. Auf den Servern ersetzt die verlinkte Datei aus `shared/config/` die aus dem Repository vollständig – sie muss also alles enthalten, was der Server braucht.

Jeder Wert lässt sich außerdem über eine Umgebungsvariable setzen, deren Name sich aus den Schlüsseln ergibt (`mail.host` → `MAIL_HOST`). Die Umgebungsvariable hat Vorrang vor der Datei.

### Mailversand

| Schlüssel | Bedeutung | Standard |
|---|---|---|
| `mail.delivery_method` | Versandweg der Mails | `sendmail` |
| `mail.host` | Host für Links in Mails | `schulungen.ub.uni-paderborn.de` |

Für den Produktivbetrieb ist kein Eintrag nötig. Ein Testsystem verschickt keine Mails und verlinkt auf sich selbst:

```yaml
production:
  mail:
    delivery_method: letter_opener_web
    host: <Adresse des Testsystems>
```

Nach einer Änderung Passenger und den Jobs-Dienst neu starten (`cap <stage> passenger:restart`, `cap <stage> app:jobs:restart`; ein Deploy erledigt beides) und die Einstellung auf dem Server prüfen:

```bash
cd /ubpb/course_manager/current
RAILS_ENV=production ~/.rvm/bin/rvm $(cat .ruby-version) do bundle exec bin/rails runner \
  'p ApplicationMailer.delivery_method, ApplicationMailer.default_url_options'
```

Ein Tippfehler im Schlüssel fällt sonst nicht auf: Die Anwendung verschickt dann wieder per `sendmail`.

## Testsysteme

### Mails lesen statt verschicken

Mit `mail.delivery_method: letter_opener_web` verlässt keine Mail der Anwendung den Server – weder aus der Web-Anwendung noch aus dem Jobs-Dienst, Rake-Tasks oder der Konsole. Die Mails werden unter `tmp/letter_opener` abgelegt (über Deploys hinweg) und sind nach der Anmeldung im Admin-Bereich unter `/admin/mail` zu lesen; die Menüleiste des Admin-Bereichs verlinkt sie dann unter „Mails“.

Das betrifft nur Mails dieser Anwendung. Was andere Software auf dem Server über `sendmail` verschickt, regelt der Mailserver des Servers.

### Anonymisieren

Für Systeme, die keine personenbezogenen Daten enthalten sollen, anonymisiert ein Task alle Anmeldungen – unabhängig vom Termin, einschließlich der internen Notizen – und löscht alle wartenden Jobs:

```bash
cap testing app:jobs:stop
cap testing app:dsgvo:anonymize_all     # verweigert die Stage production
cap testing app:jobs:start
```

Bei gestopptem Jobs-Dienst läuft kein wartender Job, bevor er gelöscht ist. Direkt auf einem System ruft man den Task mit dem Datenbanknamen als Bestätigung auf, da alle Server in der Umgebung `production` laufen und sich darüber nicht unterscheiden lassen:

```bash
bin/rails app:dsgvo:anonymize_all CONFIRM=<Datenbankname>
```
