#       Annoteret netværksdiagnoseprogram til automatisk fejlfinding af eventuelle netværksproblemer.
#       Skrevet i PowerShell som et lille projekt, der samler teorier og opgaver, jeg har lært i løbet af G2 som datatekniker.
#       Trækker især på OSI-modellen.

#       Det vigtigste, jeg har lært i forhold til PowerShell:
#       1) PowerShell returnerer objekter, ikke tekst. Med Out-Null og Quiet kan jeg kassere dem og arbejde med boolean. 
#       2) Da jeg har kodet en del i Python skulle jeg omstille mig til at bruge pipelines, der gør filtrering af objekter mere læsbar.
#       3) Nogle cmdlets kaster exceptions, der kræver try/catch, andre returnerer boolean, hvor if/else er oplagt. 

Clear-Host
#       Rydder konsollen, men ikke sessionens data. 

$log = [Environment]::GetFolderPath("Desktop") + "\netdiag_log.txt"
#       Her laver jeg en variabel, der gemmer stien til logfilen.
#       Jeg bruger [Environment]::GetFolderPath("Desktop") for at finde den rigtige Desktop-mappe for brugeren.
#       Det gør jeg, fordi OneDrive eksempelvis kan ændre ved skrivebordet.

Start-Transcript $log -Force
#       Logger alt i PowerShell-sessionen og gemmer det i den variabel, der indeholder stien til logfilen.
#       Med -Force sikrer jeg, at scriptet kører og overskriver en tidligere logfil ved samme navn.
function Section($sektion) {
    Write-Host ""
    Write-Host "==============================="
    Write-Host $sektion
    Write-Host "==============================="
}
#       Her laver jeg en funktion, der kører et stykke kode, når den senere hen kaldes.
#       Jeg vil bruge den til visuel inddeling/struktur af min kodes output på en informativ måde.

Section "NETVAERKSDIAGNOSE STARTER"
#       Her kalder jeg funktionen og giver den tekstinput, som den printer i variablen.

Section "Aktiv(e) netvaerksadapter(e)"
#       Her gør jeg det samme igen.

Get-NetAdapter |
#       Jeg beder Windows give mig alle netværksadapter-objekter, og med "|" sender jeg dem videre i pipelinen.

Where-Object Status -eq "Up" |
#       Af de objekter, der er sendt videre, tjekker jeg nu efter dem med en property, der er "Up", altså de aktive adaptere.
#       De aktive adaptere sender jeg videre i pipelinen.

Select-Object Name, InterfaceDescription, LinkSpeed |
#       Nu filtrerer jeg efter relevante properties. Navn, beskrivelse og linkhastighed.

Format-Table -AutoSize
#       Jeg laver objekterne om til tekst i en tabel i konsollen.
#       Og får kolonnerne til automatisk at tilpasse sig. 

Section "IP-konfiguration"
#       Jeg kalder førnævnte funktion.

$ip = Get-NetIPAddress -AddressFamily IPv4 |
      Where-Object {
        $_.IPAddress -notlike "169.254*" -and
        $_.PrefixOrigin -ne "WellKnown"
      }
#       Variablen kommer til at indholde de objekter, der kommer ud af pipelinen til højre for (hvis betingelserne mødes).
#       Først henter jeg alle IP-adresser på maskinen og sikrer derefter, at det kun er IPv4-adresser, der sendes videre i pipelinen.
#       $_ er det aktuelle objekt i pipelinen
#       Af de videresendte objekter vil jeg have dem, der IKKE starter med "169.254" eller har "WellKnown" som prefix.

if (-not $ip) {
    Write-Host "FEJL: Ingen gyldig IPv4-adresse fundet (DHCP problem?)" -ForegroundColor Red
    Read-Host "Tryk Enter for at afslutte"
    exit
}
#       Hvis variablen er tom, så køres denne kode.

Write-Host "OK: IPv4 fundet: $($ip.IPAddress)" -ForegroundColor Green
#       Hvis variablen indeholdt én eller flere, kører koden videre og printer dem her.

Section "Default gateway"
#       Jeg kalder førnævnte funktion.

$gateway = (Get-NetRoute -DestinationPrefix "0.0.0.0/0" |
            Sort-Object RouteMetric |
            Select-Object -First 1).NextHop
#       Variablen indeholder maskinens primære default gateway (IP-adressen), hvis en sådan findes.
#       Først hentes alle routing-tabeller for destination 0.0.0.0/0 (standard gateway).
#       Ruterne sorteres efter RouteMetric (laveste værdi = højeste prioritet).
#       Derefter vælges kun den første rute i den sorterede liste.
#       Med .NextHop tager vi kun IP-adressen på gatewayen, som gemmes i $gateway.

if (-not $gateway) {
    Write-Host "FEJL: Ingen gateway fundet" -ForegroundColor Red
    Read-Host "Tryk på Enter for at afslutte"
    exit
}
#       Hvis variablen er tom, kører ovenstående kode. 

Write-Host "OK: Gateway: $gateway" -ForegroundColor Green
#       Koden kører videre og printer gatewayen.

Section "Ping gateway"
#       Jeg kalder funktionen, jeg definerede i toppen af scriptet.

if (Test-Connection $gateway -Count 2 -Quiet) {
    Write-Host "OK: Gateway svarer" -ForegroundColor Green
}
else {
    Write-Host "FEJL: Gateway svarer ikke (lokalt netproblem)" -ForegroundColor Red
    Read-Host "Tryk på Enter for at afslutte"
    exit
}
#       Klassisk hvis/ellers. Jeg tjekker først, om jeg kan pinge gatewayen, og hvis jeg kan, så kører min if-kode.
#       I min if-kode fortæller jeg Windows, at jeg vil pinge den IP på gatewayen, jeg før gemte i variablen.
#       Det gør jeg med 2 ICMP-pakker, for hurtigere test.
#       Jeg gør det også med -Quiet, for ikke at få detaljer, men boolean, altså True/False, som fungerer godt med if/else.
#       Hvis ikke jeg kan pinge gatewayen, så kører jeg min else-kode.

Section "DNS-servere"
#       Kalder min funktion igen.

(Get-DnsClientServerAddress -AddressFamily IPv4).ServerAddresses
#       Først henter jeg de DNS-servere, der er konfigureret på netværkskortet.
#       Så sikrer jeg, at kun IPv4-adresser returneres. 
#       Af de objekter, der nu returneres, får jeg med .ServerAdresses kun selve IP-adresserne som tekst (ikke objekter)
#       Resultatet bliver et array af DNS-IP'er, der vises i konsollen.

Section "Internettest (8.8.8.8)"
#       Kalder min funktion igen. 

$internetOK = Test-Connection 8.8.8.8 -Count 2 -Quiet
#       Gemmer resultatet som boolean.
#       -Quiet ændrer Test-Connection fra at returnere objekter til kun True/False.
#       True = Begge ping lykkes.
#       False = Ingen svar (ingen internetforbindelse eller ICMP blokeret)

if ($internetOK) {
    Write-Host "OK: Internet-ping virker" -ForegroundColor Green
}
else {
    Write-Host "FEJL: Ingen adgang til internet" -ForegroundColor Red
}
#       Hvis variablen er True, så kører koden derunder.
#       Hvis variablen er False, så kører koden derunder, og så kører jeg en traceroute senere.

Section "DNS-opslag"
#       Jeg kalder funktionen.

try {
    Resolve-DnsName google.com -ErrorAction Stop | Out-Null
    Write-Host "OK: DNS virker" -ForegroundColor Green
}
catch {
    Write-Host "FEJL: DNS virker ikke" -ForegroundColor Red
    Read-Host "Tryk Enter for at afslutte"
    exit
}
#       Her laver jeg et DNS-opslag på google.com via de DNS-servere, som er på maskinens netværkskort.
#       -ErrorAction Stop gør fejl terminerende, så catch-blokken aktiveres.
#       Out-Null skjuler output, da jeg kun er interesseret i succes/fejl.

Section "Web-adgang"
#       Kalder min funktion.

try {
    Invoke-WebRequest "http://example.com" -UseBasicParsing -TimeoutSec 5 | Out-Null
    Write-Host "OK: HTTP virker (80)" -ForegroundColor Green
}
catch {
    Write-Host "FEJL: HTTP blokeret" -ForegroundColor Red
}

if (Test-NetConnection example.com -Port 443 -InformationLevel Quiet) {
    Write-Host "OK: HTTPS virker (443)" -ForegroundColor Green
}
else {
    Write-Host "FEJL: HTTPS blokeret (firewall/proxy?)" -ForegroundColor Red
}

if (-not $internetOK) {
    Section "Traceroute (fejlsoegning)"
    Test-NetConnection 8.8.8.8 -TraceRoute
}
#       Med Invoke-WebRequest laver jeg en rigtig HTTP-request med DNS-opslag, TCP og HTTP. Jeg tester altså flere ting end bare porten.
#       Jeg bruger try/catch, fordi kommandoen fejler via exceptions, som jeg skal fange med catch, ikke if/else.
#       Så bruger jeg -UseBasicParsing, fordi jeg ikke er interesseret i HTML-parsing og for at undgå warnings.
#       Jeg stopper efter 5 sekunder, hvis en firewall dropper pakker, serveren ikke svarer eller forbindelsen er dårlig.
#       Også, fordi scriptet ellers kan komme til at vente i lang tid på at komme videre.
#       Igen dropper jeg output, fordi jeg kun er interesseret i succes/fejl.
#       I if/else-delen tester jeg kun, om TCP kan åbne socket på port 443.
#       Med -InformationLevel Quiet sørger jeg for, at jeg kun får True/False returneret, fremfor et stort objekt.

Section "RESULTAT"
#       Kalder funktionen igen.

Write-Host "Log gemt her:" -ForegroundColor Cyan
Write-Host $log
#       Slutter af med at fortælle brugeren, hvor logfilen er gemt.

Stop-Transcript
#       Her stopper scriptet med at logge. Hvis jeg ikke stoppede logningen, så ville scriptet fortsætte med at logge resten af sessionen.

Write-Host ""
Read-Host "Tryk Enter for at afslutte"