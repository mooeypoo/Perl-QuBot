# Perl QuBot #

Perl IRC Bot with Quotes Database by Moriel Schottlender.
mooeypoo@gmail.com

INSTALLATION




# FAQ #
These are potential problems and frequently asked questions. If you ran into a bug or an issue that is not addressed in this list, please open a new issue or email mooeypo@gmail.com

## I forgot my password / lost access to admin! ##
=======
If you lose access to the bot, add this into the users.yml file:
'''
---
admin:
  access_level: '9999'
  pass: $1$nlUjcBiL$2laUQnoTTXutoDtnPCt5e1
  username: admin
'''
The above record will allow you access with username "admin" and password "admin" as a temporary measure. You can then add, remove and edit users. Don't forget to delete this user from the bot after you create your new administrator!

