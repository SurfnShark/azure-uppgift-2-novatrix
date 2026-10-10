# Microsoft Azure - Uppgift 2

**Student:** Kardo Jabari  
**Kurs:** Microsoft Azure  
**Vecka:** 35 - IAM och identitet

Det här repot innehåller lösningen för Novatrix AB:s andra Azure-uppgift. Den bygger vidare på resursgruppen och webbservern från [uppgift 1](https://github.com/SurfnShark/azure-uppgift-1-novatrix). Två labbanvändare får olika behörigheter genom säkerhetsgrupper. En hanterad identitet för appen är också skapad, utan lagringsbehörigheter ännu.

Entra ID håller reda på användare och grupper. Azure RBAC bestämmer vad de får göra och vilka resurser behörigheten gäller för.

## Lösningens delar

- [`v35/config.example.sh`](v35/config.example.sh) - exempel på den konfiguration som skripten behöver.
- [`v35/scripts/setup.sh`](v35/scripts/setup.sh) - förbereder användare, grupper, roller och appidentitet om de saknas.
- [`v35/scripts/apply-rbac.sh`](v35/scripts/apply-rbac.sh) - tillämpar och verifierar de tre rolltilldelningarna med Azure CLI för VG-delen.
- [`v35/scripts/verify-admin.sh`](v35/scripts/verify-admin.sh) - kontrollerar gruppmedlemskap, roller och appidentitet som administratör.
- [`v35/scripts/verify-reader.sh`](v35/scripts/verify-reader.sh) - ett separat CLI-test för utvecklarkontots läsning och nekade skrivning.
- [`v35/scripts/common.sh`](v35/scripts/common.sh) - gemensamma inställningar och kontroller av konto och prenumeration.

PDF-rapporten med diagram och bildbevis lämnas separat och ingår inte i repot.

## Användare och behörigheter

| Användare eller identitet | Grupp | Roll | Gäller för |
| --- | --- | --- | --- |
| Novatrix Drift | `grp-novatrix-drift` | Reader | Resursgruppen `rg-novatrix` |
| Novatrix Drift | `grp-novatrix-drift` | Virtual Machine Contributor | Endast webbservern `vm-novatrix-web` |
| Novatrix Utveckling | `grp-novatrix-utveckling` | Reader | Resursgruppen `rg-novatrix` |
| Appidentiteten `id-novatrix-app` | Ingen användargrupp | Ingen roll ännu | Lagringsåtkomst förbereds i ett senare moment |

Drift behöver läsa miljön och administrera webbservern. Utveckling behöver bara granska miljön i detta moment. Därför får utveckling Reader, medan drift även får en VM-roll på just webbservern. Ingen av labbgrupperna får Owner eller generell Contributor.

## Förutsättningar

Kör skripten i Azure Cloud Shell med Bash. Azure CLI finns redan där. Du behöver en aktiv Azure-prenumeration, den befintliga resursgruppen `rg-novatrix` och webbservern `vm-novatrix-web`.

För att skapa användare och grupper krävs rätt behörighet i Entra ID. För att skapa appidentiteten och tilldela Azure-roller krävs också rätt behörighet i Azure. Det är två olika typer av behörighet.

## Förberedelse och körning

1. Klona repot och gå in i katalogen:

   ```bash
   git clone https://github.com/SurfnShark/azure-uppgift-2-novatrix.git
   cd azure-uppgift-2-novatrix
   ```

2. Kontrollera inloggningen och kopiera exempelkonfigurationen:

   ```bash
   az account show --output table
   cp v35/config.example.sh v35/config.local.sh
   ```

   Fyll i rätt prenumeration, tenant och tenantdomän i `v35/config.local.sh`. Den lokala filen ignoreras av Git. Skriv inga lösenord i den.

3. Om labbens användare, grupper och appidentitet saknas, kör förberedelsen:

   ```bash
   bash v35/scripts/setup.sh
   ```

   Skriptet frågar efter tillfälliga lösenord med dold inmatning när nya användare behöver skapas. Befintliga användares lösenord återställs inte. Nya användare behöver byta lösenord vid första inloggningen.

4. Tillämpa rollerna med kod och kontrollera konfigurationen:

   ```bash
   bash v35/scripts/apply-rbac.sh
   bash v35/scripts/verify-admin.sh
   ```

   RBAC-skriptet kontrollerar labbgrupperna och deras förväntade medlemmar. Befintliga rolltilldelningar återanvänds och varje tilldelning verifieras efteråt.

## Genomförande och verifierat resultat

Användare, grupper, roller och appidentitet skapades i Azure-portalen. Båda labbkontona testades genom separata inloggningar med MFA.

| Kontroll | Resultat |
| --- | --- |
| Gruppmedlemskap | Varje labbanvändare finns i sin avsedda säkerhetsgrupp. |
| Utveckling: läsning | Kontot kunde läsa resursgruppen och se dess sju resurser. |
| Utveckling: skrivning | Ett försök att spara en testtagg nekades med `AuthorizationFailed` för `Microsoft.Resources/tags/write`. Ingen tagg skapades. |
| Drift: VM-åtkomst | Kontots egen åtkomstvy på webbservern visade Reader ärvt från resursgruppen och Virtual Machine Contributor på själva VM:n. Administrationssidan var tillgänglig. |
| Appidentitet | `id-novatrix-app` finns och dess rollista i prenumerationen var tom. |
| VG: roller via kod | `apply-rbac.sh` kördes i Azure Cloud Shell. Alla tre rolltilldelningar tillämpades och verifierades via Azure CLI. |
| Webbserver | VM:n var stoppad och frigjord. Ingen VM-operation utfördes under kontrollerna. |

`setup.sh`, `verify-admin.sh` och `verify-reader.sh` ingår för att kunna återskapa eller kontrollera lösningen, men kördes inte under detta genomförande. Användarnas åtkomst testades i portalen. Den genomförda kodkörningen för VG gjordes med `apply-rbac.sh`.

### Separat CLI-test för utveckling

Detta test ska köras i en separat session som utvecklarkontot, inte som administratör:

```bash
az login --tenant YOUR_TENANT_ID
bash v35/scripts/verify-reader.sh
```

Skriptet läser resursgruppen och försöker skriva tillbaka oförändrade taggar. Det förväntar sig ett behörighetsfel för `resourceGroups/write`. Detta CLI-test skiljer sig från det genomförda portaltestet, som nekades för `tags/write`.

## VG: en modell som kan växa

Behörigheter tilldelas grupper i stället för enskilda personer. Fler personer kan därför få samma behörigheter genom att läggas i rätt teamgrupp. Nya team får egna grupper och roller som motsvarar deras arbetsuppgifter.

Separata resursgrupper kan ge tydliga gränser mellan team. Varje app kan få en egen identitet och bara den dataåtkomst den behöver. Skriptets kontroll av förväntade gruppmedlemmar behöver uppdateras medvetet när gruppen utökas.

## Namngivning

- Resursgrupp: `rg-novatrix`
- Webbserver: `vm-novatrix-web`
- Driftgrupp: `grp-novatrix-drift`
- Utvecklingsgrupp: `grp-novatrix-utveckling`
- Hanterad appidentitet: `id-novatrix-app`

## Säkerhet och kostnad

Virtual Machine Contributor är en kraftfull roll som bland annat kan köra kod på VM:n. Den är därför begränsad till webbservern. Om servern senare får en appidentitet med dataåtkomst behöver även driftens möjlighet att använda den åtkomsten tas med i bedömningen.

Lösenord, privat kontokonfiguration och råa skärmbilder ingår inte i repot. Kör inte lösenordsinmatning med felsökningsloggning som kan visa hemligheter.

VM:n behöver inte startas för uppgiftens identitets- och rollkontroller. Befintliga diskar och publika IP-adresser kan fortfarande kosta pengar. En Azure-budget kan varna, men stoppar inte kostnader automatiskt.

Om resursgruppen tas bort och återskapas behöver rollerna på resurserna tilldelas igen. Entra-användare och grupper ligger i tenanten och tas inte bort automatiskt när resursgruppen raderas.
