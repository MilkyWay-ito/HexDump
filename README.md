# HexDump

Outil de dump hexadécimal écrit entièrement en assembleur x86-64 (NASM), pour Linux, sans libc.
Inspiré de `xxd` et `hexdump -C` : il lit un fichier et affiche son contenu brut octet par octet, avec des fonctionnalités pensées pour l'analyse de binaires.

## Compilation

```bash
nasm -f elf64 hexdump.s -o hexdump.o
ld hexdump.o -o hexdump
```

## Utilisation

```bash
./hexdump <fichier>
```

Exemple :

```
$ ./hexdump /etc/passwd
Format : inconnu
00000000: 72 6F 6F 74 3A 78 3A 30 3A 30 3A 72 6F 6F 74 3A  root:x:0:0:root:
00000010: 2F 72 6F 6F 74 3A 2F 62 69 6E 2F 62 61 73 68 0A  /root:/bin/bash.
```

Chaque ligne contient trois colonnes :

- **l'offset** du premier octet de la ligne, en hexadécimal sur 8 chiffres
- **16 octets** en hexadécimal
- **la représentation ASCII** de ces octets, avec un `.` pour les caractères non imprimables

## Fonctionnalités

### Coloration par type d'octet

| Couleur | Octets | Utilité |
|---|---|---|
| Gris | `00` | repérer le padding et les zones vides |
| Vert | `20` à `7E` | repérer le texte imprimable |
| Jaune | `09`, `0A`, `0D` | tabulations et retours à la ligne |
| Bleu | `FF` | valeurs « pleines », marqueurs |
| Rouge | le reste | données binaires, code machine |

Les couleurs s'appliquent à la colonne hexadécimale et à la colonne ASCII. Elles sont **activées uniquement si la sortie est un terminal** : en cas de redirection vers un fichier ou un pipe, la sortie reste propre, sans codes d'échappement.

### Détection du format

Les premiers octets du fichier sont comparés à des signatures connues (magic bytes), comme le fait la commande `file` :

| Signature | Format |
|---|---|
| `7F 45 4C 46` | ELF (32 ou 64 bits, selon le 5e octet) |
| `89 50 4E 47` | PNG |
| `25 50 44 46` | PDF |
| `50 4B 03 04` | ZIP (et donc .docx, .jar, .apk) |
| `47 49 46 38` | GIF |

### Compression des lignes identiques

Comme `hexdump -C`, une suite de lignes identiques est remplacée par une seule ligne `*`. Sur un exécutable, les grandes zones de zéros dues à l'alignement des segments sur des pages de 4096 octets sont ainsi résumées en une ligne, et l'affichage reprend à l'offset exact suivant.

### Messages d'erreur précis

```
$ ./hexdump
usage: ./hexdump <fichier>
$ ./hexdump inexistant
./hexdump: inexistant: fichier introuvable
$ ./hexdump /etc/shadow
./hexdump: /etc/shadow: permission refusée
$ ./hexdump /etc
./hexdump: /etc: c'est un dossier
```

Les messages sont écrits sur la sortie d'erreur et le programme quitte avec le code 1. Le message est choisi selon le code `errno` renvoyé par le noyau.

## Fonctionnement

1. **Ouverture** du fichier avec le syscall `open`, qui renvoie un descripteur de fichier, ou `-errno` en cas d'échec.
2. **Détection du terminal** avec le syscall `ioctl` (requête `TCGETS`) sur la sortie standard, l'équivalent de `isatty()` en C.
3. **Lecture** par blocs de 64 Ko avec `read`, en boucle jusqu'à la fin du fichier.
4. **Accumulation** des octets dans un buffer de 16 octets. Une ligne complète est comparée à la précédente avec deux comparaisons de 8 octets, pour décider si elle doit être affichée ou résumée par `*`.
5. **Conversion hexadécimale** : chaque octet est séparé en deux quartets avec `shr` (quartet haut) et `and 0x0F` (quartet bas). Chaque quartet sert d'indice dans une table `0123456789ABCDEF`, sans test conditionnel.
6. **Offset** : le compteur global d'octets est converti en 8 chiffres hexadécimaux, en remplissant un buffer de droite à gauche.
7. **Classification** de chaque octet pour choisir sa couleur, elle aussi indexée dans une table de codes ANSI.
8. **Colonne ASCII** : les octets entre `0x20` et `0x7E` sont affichés tels quels, les autres remplacés par un point. La dernière ligne incomplète est complétée par des espaces pour garder l'alignement.
9. **Fermeture** du fichier avec `close`, puis `exit`.

## Choix de format

L'affichage se fait octet par octet, comme `hexdump -C`, et non par paires comme `xxd`.
Le groupement par paires ressemble à des valeurs de 16 bits alors que les octets sont simplement dans l'ordre du fichier. Sur x86, qui est little-endian, ça peut induire en erreur lors de la lecture d'un entier ou d'une adresse. L'affichage octet par octet montre exactement ce qui est stocké et facilite le comptage des offsets.

## Exemple sur un binaire

```bash
./hexdump hexdump
```

On y retrouve l'anatomie d'un exécutable ELF :

- `0x0000` : l'en-tête ELF, qui commence par `7F 45 4C 46` (`.ELF`)
- `0x1000` : le code machine, dont la première instruction `48 83 3C 24 02` correspond à `cmp qword [rsp], 2`
- `0x2000` : la section `.data`, avec la table `0123456789ABCDEF` et les messages du programme
- à la fin : la table des symboles, qui contient les noms des labels du code source
